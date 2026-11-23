// Blunt Leap: what the hit of a fully charged leap does with the stronger
// leap. No game function is wrapped here: the effector class below is named
// in a data record (BluntLeap.ImpactEffector) and the game calls it for the
// player's strong melee hits, after the crit is decided and before the enemy
// picks its hit reaction.
//
//   - EMP burst on a crit (once per leap).
//   - Send the enemy flying (by chance), with the game's own ragdoll and
//     impulse events: the same two the Gorilla Arms knockout punch uses.
//   - Otherwise raise the hit to a stagger at least.
//   - A short slow-motion beat.

public class BluntLeapImpactEffector extends ModifyAttackEffector {

  protected func RepeatedAction(owner: ref<GameObject>) -> Void {
    let hitEvent: ref<gameHitEvent> = this.GetHitEvent();
    let system: ref<BluntLeapSystem>;
    if !IsDefined(hitEvent) || !IsDefined(owner) {
      return;
    };
    system = BluntLeapSystem.Get(owner.GetGame());
    if IsDefined(system) && system.StrongLeapArmed() {
      BluntLeapImpact.OnHit(system, hitEvent);
    };
  }
}

public abstract class BluntLeapImpact {

  public final static func OnHit(system: ref<BluntLeapSystem>, hitEvent: ref<gameHitEvent>) -> Void {
    let attackData: ref<AttackData> = hitEvent.attackData;
    let settings: ref<BluntLeapSettings> = system.Settings();
    let player: ref<PlayerPuppet>;
    let target: ref<NPCPuppet>;
    let weapon: ref<WeaponObject>;
    let exempt: Bool;
    let chance: Float;
    let label: String;
    let threshold: Float;
    let unalerted: Bool;
    let heavy: Bool;
    let force: Float;

    if !IsDefined(attackData) {
      return;
    };
    player = attackData.GetInstigator() as PlayerPuppet;
    target = hitEvent.target as NPCPuppet;
    weapon = attackData.GetWeapon();
    if !IsDefined(player) || !IsDefined(target) || !IsDefined(weapon) || !WeaponObject.IsBlunt(weapon.GetItemID()) {
      return;
    };
    // For the log: which hit of the leap this is, and on whom.
    if settings.debugLog {
      label = system.NextStrongHitLabel() + ", " + BluntLeapImpact.Describe(target, weapon);
    };
    if attackData.HasFlag(hitFlag.WasBlocked) || attackData.HasFlag(hitFlag.WasDeflected) || attackData.HasFlag(hitFlag.WasDodged) || attackData.HasFlag(hitFlag.WasEvaded) {
      system.Log(label + ": blocked, deflected or dodged");
      return;
    };
    if Equals(GameObject.GetAttitudeTowards(target, player), EAIAttitude.AIA_Friendly) {
      system.Log(label + ": left alone, the target counts as friendly to V");
      return;
    };

    if settings.hitStop > 0.0 && system.TakeHitStop() {
      GameInstance.GetTimeSystem(player.GetGame()).SetTimeDilation(n"BluntLeapHitStop", 0.1, settings.hitStop);
    };

    if settings.emp && attackData.HasFlag(hitFlag.CriticalHit) && system.TakeEmp() {
      BluntLeapImpact.Emp(system, player, target, weapon);
    };

    // A hit that killed needs nothing more: the game throws the body itself.
    if !ScriptedPuppet.IsAlive(target) || attackData.HasFlag(hitFlag.Kill) || attackData.HasFlag(hitFlag.Defeated) {
      system.Log(label + ": killed or defeated, left to the game");
      return;
    };

    // Never thrown: bosses, MaxTac, massive enemies, and every enemy the game
    // says cannot be knocked down by force right now. The game marks those
    // with a knockdown threshold of 0 or less: drones, big drones and mechs
    // (-1), border patrol drones (0), some bosses, and any enemy while
    // Berserk or "Unstoppable" is on (x0). The game handles them as usual.
    threshold = GameInstance.GetStatsSystem(target.GetGame()).GetStatValue(Cast<StatsObjectID>(target.GetEntityID()), gamedataStatType.KnockdownDamageThresholdImpulse);
    exempt = target.IsBoss() || Equals(target.GetNPCRarity(), gamedataNPCRarity.MaxTac) || target.IsMassive() || threshold <= 0.0;
    // An enemy not in combat yet (the first strike on an unaware group) has
    // its own chance and force. It shows no stagger when hit (it switches to
    // combat instead), so a rolled stagger becomes a very small throw.
    unalerted = !NPCPuppet.IsInCombat(target);
    heavy = BluntLeapImpact.IsHeavy(target);
    if unalerted {
      chance = heavy ? settings.unalertedChanceHeavy : settings.unalertedChance;
      force = settings.unalertedForce;
    } else {
      chance = heavy ? settings.launchChanceHeavy : settings.launchChance;
      force = settings.launchForce;
    };
    if system.WallKillTest() {
      // Wall-kill test mode (CET): always a throw, with the test's force.
      chance = 100.0;
      force = system.WallKillTestForce();
    };
    if !exempt && RandRangeF(0.0, 100.0) < chance {
      // One throw per enemy per leap (a second hit on it adds nothing).
      if system.TakeThrow(target.GetEntityID()) {
        BluntLeapImpact.Launch(system, player, target, hitEvent, label, force, unalerted ? "sent flying (unalerted)" : "sent flying");
      } else {
        system.Log(label + ": already sent flying by this leap, not pushed again");
      };
    } else {
      if settings.stagger {
        if unalerted && !exempt && settings.unalertedStaggerForce > 0.0 {
          if system.TakeThrow(target.GetEntityID()) {
            BluntLeapImpact.Launch(system, player, target, hitEvent, label, settings.unalertedStaggerForce, "small push instead of a stagger (unalerted)");
          } else {
            system.Log(label + ": already sent flying by this leap, not pushed again");
          };
        } else {
          // Severity 2 is a stagger. The game still refuses it for enemies
          // that resist staggers, and turns it into a twitch for huge ones.
          if attackData.GetHitReactionSeverityMin() < 2 {
            attackData.SetHitReactionSeverityMin(2);
          };
          if attackData.GetHitReactionSeverityMax() < 2 {
            attackData.SetHitReactionSeverityMax(2);
          };
          system.Log(label + ": stagger" + (exempt ? " (cannot be thrown)" : "") + (unalerted ? " (unalerted)" : ""));
        };
      };
    };
  }

  // For the log: the target's record and a short id (to tell two enemies
  // from one enemy hit twice), its knockdown threshold (-1: the game says it
  // cannot be knocked down by force), whether it is heavy, and the weapon.
  private final static func Describe(target: ref<NPCPuppet>, weapon: ref<WeaponObject>) -> String {
    let threshold: Float = GameInstance.GetStatsSystem(target.GetGame()).GetStatValue(Cast<StatsObjectID>(target.GetEntityID()), gamedataStatType.KnockdownDamageThresholdImpulse);
    let id: String = ToString(EntityID.GetHash(target.GetEntityID()));
    return TDBID.ToStringDEBUG(target.GetRecordID()) + " #" + StrRight(id, 5) + ", threshold " + FloatToStringPrec(threshold, 0) + (BluntLeapImpact.IsHeavy(target) ? ", heavy" : "") + ", " + EnumValueToString("gamedataItemType", Cast<Int64>(EnumInt(WeaponObject.GetWeaponType(weapon.GetItemID()))));
  }

  // Wall-kill test mode: 0.05 s after the throwing hit (before the impact)
  // the enemy is left with one health point (BluntLeapSystem.LeaveOneHealth).
  // The hit's own damage cannot be changed here: the game deals it before
  // this stage of the hit. A hit that kills or knocks out on its own is
  // logged as such.
  private final static func SpareForTest(system: ref<BluntLeapSystem>, target: ref<NPCPuppet>, hitEvent: ref<gameHitEvent>) -> Void {
    let callback: ref<BluntLeapLowHealthCallback>;
    callback = new BluntLeapLowHealthCallback();
    callback.system = system;
    callback.npc = target;
    GameInstance.GetDelaySystem(target.GetGame()).DelayCallback(callback, 0.05, false);
  }

  // The game's heavy enemy types.
  private final static func IsHeavy(target: ref<NPCPuppet>) -> Bool {
    let record: ref<Character_Record> = TweakDBInterface.GetCharacterRecord(target.GetRecordID());
    let archetype: gamedataArchetypeType;
    if !IsDefined(record) || !IsDefined(record.ArchetypeData()) {
      return false;
    };
    archetype = record.ArchetypeData().Type().Type();
    return Equals(archetype, gamedataArchetypeType.HeavyMeleeT2) || Equals(archetype, gamedataArchetypeType.HeavyMeleeT3) || Equals(archetype, gamedataArchetypeType.HeavyRangedT2) || Equals(archetype, gamedataArchetypeType.HeavyRangedT3);
  }

  // The EMP burst, at the enemy's chest. Its Electrical damage is a share of
  // the weapon's own damage per hit: not of this hit, so the crit, the charge
  // and the leap distance do not raise it.
  private final static func Emp(system: ref<BluntLeapSystem>, player: ref<PlayerPuppet>, target: ref<NPCPuppet>, weapon: ref<WeaponObject>) -> Void {
    let game: GameInstance = player.GetGame();
    let settings: ref<BluntLeapSettings> = system.Settings();
    let damage: Float = GameInstance.GetStatsSystem(game).GetStatValue(Cast<StatsObjectID>(weapon.GetEntityID()), gamedataStatType.DamagePerHit) * settings.empDamage / 100.0;
    let flags: array<SHitFlag>;
    let flag: SHitFlag;
    let attack: ref<Attack_GameEffect>;
    let position: Vector4 = target.GetWorldPosition();
    let slot: WorldTransform;

    if IsDefined(target.GetSlotComponent()) && target.GetSlotComponent().GetSlotTransform(n"Chest", slot) {
      position = WorldPosition.ToVector4(WorldTransform.GetWorldPosition(slot));
    };
    TweakDBManager.SetFlat(t"BluntLeap.EMPDamage.value", ToVariant(MaxF(damage, 1.0)));
    TweakDBManager.UpdateRecord(t"BluntLeap.EMPDamage");
    flag.flag = hitFlag.Explosion;
    flag.source = n"Attack";
    ArrayPush(flags, flag);
    attack = RPGManager.PrepareGameEffectAttack(game, player, player, t"BluntLeap.EMP", position, flags);
    if IsDefined(attack) {
      attack.StartAttack();
    };
    system.Log("Hit: EMP on a crit, damage " + FloatToStringPrec(damage, 0));
  }

  // Sends the enemy flying. The force is worked out the way the Gorilla Arms
  // knockout punch does it, from the enemy's own knockdown threshold.
  private final static func Launch(system: ref<BluntLeapSystem>, player: ref<PlayerPuppet>, target: ref<NPCPuppet>, hitEvent: ref<gameHitEvent>, label: String, forcePercent: Float, what: String) -> Void {
    let game: GameInstance = player.GetGame();
    let settings: ref<BluntLeapSettings> = system.Settings();
    let threshold: Float = GameInstance.GetStatsSystem(game).GetStatValue(Cast<StatsObjectID>(target.GetEntityID()), gamedataStatType.KnockdownDamageThresholdImpulse);
    let impulse: Float = (threshold + 10.0) * TweakDBInterface.GetFloat(t"Items.StrongArms.impulseOfOnePunch", 20.0) * forcePercent / 100.0;
    let up: Float = TweakDBInterface.GetFloat(t"Items.StrongArms.upwardsVectorStrength", 0.7);
    let away: Vector4 = target.GetWorldPosition() - player.GetWorldPosition();
    let right: Vector4;
    let push: Vector4;
    let side: Float = 0.0;
    let lift: Float = 1.0;
    let melee: ref<Attack_Melee_Record>;
    let direction: gamedataMeleeAttackDirection;

    away.Z = 0.0;
    away.W = 0.0;
    if Vector4.Length(away) < 0.01 {
      away = player.GetWorldForward();
      away.Z = 0.0;
    };
    away = Vector4.Normalize(away);
    right = new Vector4(away.Y, -away.X, 0.0, 0.0);

    if settings.swingPush {
      melee = hitEvent.attackData.GetAttackDefinition().GetRecord() as Attack_Melee_Record;
      if IsDefined(melee) && IsDefined(melee.AttackDirection()) && IsDefined(melee.AttackDirection().Direction()) {
        direction = melee.AttackDirection().Direction().Type();
        switch direction {
          case gamedataMeleeAttackDirection.LeftToRight:
            side = 1.0;
            break;
          case gamedataMeleeAttackDirection.RightToLeft:
            side = -1.0;
            break;
          case gamedataMeleeAttackDirection.LeftDownToRightUp:
            side = 0.7;
            lift = 1.6;
            break;
          case gamedataMeleeAttackDirection.RightDownToLeftUp:
            side = -0.7;
            lift = 1.6;
            break;
          case gamedataMeleeAttackDirection.LeftUpToRightDown:
            side = 0.7;
            lift = 0.4;
            break;
          case gamedataMeleeAttackDirection.RightUpToLeftDown:
            side = -0.7;
            lift = 0.4;
            break;
          case gamedataMeleeAttackDirection.DownToUp:
            lift = 2.0;
            break;
          case gamedataMeleeAttackDirection.UpToDown:
            lift = 0.3;
            break;
        };
      };
    };

    // The punch uses: hit direction * 0.1 + straight up * strength * 0.05.
    push = Vector4.Normalize(away + right * side) * 0.1 + new Vector4(0.0, 0.0, up * lift, 0.0) * 0.05;
    push = push * impulse;

    // Knockdown is the reaction the game plays; the ragdoll and the impulse
    // make it a flight.
    hitEvent.attackData.AddFlag(hitFlag.ForceKnockdown, n"BluntLeap");
    // V threw it: V is the ragdoll's instigator, as with the game's own
    // ragdolls from V's attacks. The game gives a ragdoll's impacts (a wall,
    // a fall) to its instigator, or to the NPC itself if there is none; an
    // NPC killed by its own impact counts as a kill not credited to V, and
    // its body offers no interaction at all, no loot and no pick-up (seen
    // in game 2026-11-24). The forced ragdoll below names no instigator.
    target.BluntLeapCreditRagdoll(player);
    GameInstance.GetDelaySystem(game).DelayEvent(target, CreateForceRagdollEvent(n"Blunt Leap: sent flying"), 0.01, false);
    GameInstance.GetDelaySystem(game).DelayEvent(target, CreateRagdollApplyImpulseEvent(hitEvent.hitPosition, push, 1.0), 0.1, false);
    // Its body must stay lootable if it dies before getting up
    // (BluntLeapSystem.ClearThrownBody).
    system.NoteThrown(target.GetEntityID());
    if system.WallKillTest() {
      BluntLeapImpact.SpareForTest(system, target, hitEvent);
    };
    system.Log(label + ": " + what + ", force " + FloatToStringPrec(impulse, 0) + ", side " + FloatToStringPrec(side, 1) + ", lift " + FloatToStringPrec(lift, 1));
  }
}

// An NPC dies or is knocked out (the game processes its loot here). If this
// mod sent it flying, the NonInteractable its ragdoll left on it is taken
// off, so its body and loot can be looted (BluntLeapSystem.ClearThrownBody).
@wrapMethod(NPCPuppet)
protected func OnIncapacitated() -> Void {
  let system: ref<BluntLeapSystem>;
  wrappedMethod();
  system = BluntLeapSystem.Get(this.GetGame());
  if IsDefined(system) {
    system.ClearThrownBody(this, "went down");
  };
}

// An NPC dies. If this mod threw it, its body is checked as when it went
// down, including the loot prompt 2.5 s later: the game sets that prompt
// only once, when the NPC first goes down, and an NPC thrown with a little
// health left can go down first and die later (BluntLeapSystem.ClearThrownBody).
//
// Whether the NPC had already gone down before it died is read before the
// game's death handling (for the log). With "Write a log" on, each thrown
// NPC's death is shown on screen and listed by the CET report
// (tools/cet_thrown_deaths.lua), so a body without a loot prompt can be
// matched to it.
@wrapMethod(ScriptedPuppet)
protected func OnDied() -> Void {
  let npc: ref<NPCPuppet> = this as NPCPuppet;
  let system: ref<BluntLeapSystem>;
  let late: Bool = false;
  let knockedOut: Bool = false;
  if IsDefined(npc) {
    late = npc.IsIncapacitated();
    knockedOut = ScriptedPuppet.IsDefeated(npc) || ScriptedPuppet.IsUnconscious(npc);
  };
  wrappedMethod();
  if IsDefined(npc) {
    system = BluntLeapSystem.Get(this.GetGame());
    if IsDefined(system) {
      system.ClearThrownBody(npc, (system.DiedByImpact(npc.GetEntityID()) ? "died from its impact (wall or ground)" : "died") + (late ? (knockedOut ? " after going down (it was knocked out)" : " after going down (it was not knocked out)") : "") + (IsDefined(npc.GetKiller() as PlayerPuppet) ? ", kill credited to V" : ", kill NOT credited to V"), true);
    };
  };
}

// The game's own loot-prompt check, run again (see ClearThrownBody). Returns
// true if the body now has a loot prompt.
@addMethod(ScriptedPuppet)
public func BluntLeapRefreshLoot() -> Bool {
  CachedBoolValue.SetDirty(this.m_isActiveCached);
  this.UpdateLootInteraction();
  return !this.IsActive() && IsDefined(this.m_inventoryComponent) && this.m_inventoryComponent.IsAccessible();
}

// A ragdolling body hit something hard: the game makes it an attack on the
// NPC (its "ragdoll impact"). Noted for thrown NPCs, so a death right after
// it reads "died from its impact".
@wrapMethod(NPCPuppet)
protected cb func OnStartRagdollDamageEvent(inEvent: ref<StartRagdollDamageEvent>) -> Bool {
  let system: ref<BluntLeapSystem> = BluntLeapSystem.Get(this.GetGame());
  if IsDefined(system) {
    system.NoteRagdollImpact(this.GetEntityID());
  };
  return wrappedMethod(inEvent);
}

// The damage of a ragdoll impact (a wall, the ground) is set here. If it
// would kill an NPC this mod threw, it is cancelled and V's kill is dealt a
// moment later instead (BluntLeapSystem.KillInsteadOfImpact): a kill by the
// game's ragdoll impact leaves a body with no loot and no pick-up. The
// "should die" mark the game sets for hard impacts is taken off too.
@wrapMethod(DamageSystem)
private func ProcessRagdollHit(hitEvent: ref<gameHitEvent>) -> Void {
  let npc: ref<NPCPuppet>;
  let system: ref<BluntLeapSystem>;
  let health: Float;
  let damage: Float;
  wrappedMethod(hitEvent);
  if !IsDefined(hitEvent as gameRagdollHitEvent) {
    return;
  };
  npc = hitEvent.target as NPCPuppet;
  if !IsDefined(npc) || npc.IsDead() {
    return;
  };
  system = BluntLeapSystem.Get(npc.GetGame());
  if !IsDefined(system) || !system.IsThrown(npc.GetEntityID()) {
    return;
  };
  health = GameInstance.GetStatPoolsSystem(npc.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health, false);
  damage = hitEvent.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health);
  if damage < health && !npc.IsAboutToDie() {
    return;
  };
  hitEvent.attackComputed.SetAttackValue(0.0);
  npc.BluntLeapCancelDeathMark();
  system.KillInsteadOfImpact(npc, damage, health);
}

@addMethod(NPCPuppet)
public func BluntLeapCancelDeathMark() -> Void {
  this.m_shouldDie = false;
}

// V is the instigator of the ragdoll this mod starts (see Launch). Read by
// the game when the ragdolling body hits something (OnStartRagdollDamageEvent
// through GetRagdollInstigator).
@addMethod(NPCPuppet)
public func BluntLeapCreditRagdoll(instigator: ref<GameObject>) -> Void {
  this.m_ragdollInstigator = instigator;
}

// A ragdoll starts. The game puts NonInteractable on an NPC that is not dead
// at this point, and a knocked-out NPC is not dead. If this mod threw the NPC
// and it is already down (the throwing hit knocked it out, or it was knocked
// out while lying from an earlier throw), the effect is taken off again: no
// ragdoll recovery will come to do it.
@wrapMethod(NPCPuppet)
protected cb func OnRagdollEnabledEvent(evt: ref<RagdollNotifyEnabledEvent>) -> Bool {
  let system: ref<BluntLeapSystem>;
  let result: Bool = wrappedMethod(evt);
  if this.IsIncapacitated() || !ScriptedPuppet.IsActive(this) {
    system = BluntLeapSystem.Get(this.GetGame());
    if IsDefined(system) {
      system.ClearThrownBody(this, "ragdoll started while down");
    };
  };
  return result;
}

// For the log only (no change in play): every hit the game processes, from V
// with a blunt weapon, within 3 s of a stronger leap's start. It runs right
// after the hit-reaction stage callbacks (where the Thunder Breaker effector
// runs), so a "Game hit" line without a "Hit #" line before it is a hit the
// effector did not see; the line says what kind of hit it was.
@wrapMethod(DamageSystem)
private func ProcessHitReaction(hitEvent: ref<gameHitEvent>) -> Void {
  let system: ref<BluntLeapSystem>;
  let player: ref<PlayerPuppet>;
  let target: ref<NPCPuppet>;
  let weapon: ref<WeaponObject>;
  let since: Float;
  wrappedMethod(hitEvent);
  if !IsDefined(hitEvent) || !IsDefined(hitEvent.attackData) {
    return;
  };
  player = hitEvent.attackData.GetInstigator() as PlayerPuppet;
  target = hitEvent.target as NPCPuppet;
  weapon = hitEvent.attackData.GetWeapon();
  if !IsDefined(player) || !IsDefined(target) || !IsDefined(weapon) || !WeaponObject.IsBlunt(weapon.GetItemID()) {
    return;
  };
  system = BluntLeapSystem.Get(player.GetGame());
  if !IsDefined(system) || !system.Settings().debugLog {
    return;
  };
  since = system.SinceStrongStart();
  if since < 0.0 || since > 3.0 {
    return;
  };
  system.Log("Game hit +" + FloatToStringPrec(since, 2) + " s, " + TDBID.ToStringDEBUG(target.GetRecordID()) + ", attack " + EnumValueToString("gamedataAttackType", Cast<Int64>(EnumInt(hitEvent.attackData.GetAttackType()))) + ", attitude " + EnumValueToString("EAIAttitude", Cast<Int64>(EnumInt(GameObject.GetAttitudeTowards(target, player)))) + ", in combat " + ToString(NPCPuppet.IsInCombat(target)) + ", Thunder Breaker armed " + ToString(system.StrongLeapArmed()));
}
