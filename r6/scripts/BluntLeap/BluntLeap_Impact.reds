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

    if !IsDefined(attackData) {
      return;
    };
    player = attackData.GetInstigator() as PlayerPuppet;
    target = hitEvent.target as NPCPuppet;
    weapon = attackData.GetWeapon();
    if !IsDefined(player) || !IsDefined(target) || !IsDefined(weapon) || !WeaponObject.IsBlunt(weapon.GetItemID()) {
      return;
    };
    if attackData.HasFlag(hitFlag.WasBlocked) || attackData.HasFlag(hitFlag.WasDeflected) || attackData.HasFlag(hitFlag.WasDodged) || attackData.HasFlag(hitFlag.WasEvaded) {
      return;
    };
    if Equals(GameObject.GetAttitudeTowards(target, player), EAIAttitude.AIA_Friendly) {
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
      return;
    };

    exempt = target.IsBoss() || Equals(target.GetNPCRarity(), gamedataNPCRarity.MaxTac) || target.IsMassive();
    chance = BluntLeapImpact.IsHeavy(target) ? settings.launchChanceHeavy : settings.launchChance;
    if !exempt && RandRangeF(0.0, 100.0) < chance {
      BluntLeapImpact.Launch(system, player, target, hitEvent);
    } else {
      if settings.stagger {
        // Severity 2 is a stagger. The game still refuses it for enemies
        // that resist staggers, and turns it into a twitch for huge ones.
        if attackData.GetHitReactionSeverityMin() < 2 {
          attackData.SetHitReactionSeverityMin(2);
        };
        if attackData.GetHitReactionSeverityMax() < 2 {
          attackData.SetHitReactionSeverityMax(2);
        };
        system.Log("Hit: stagger");
      };
    };
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
  private final static func Launch(system: ref<BluntLeapSystem>, player: ref<PlayerPuppet>, target: ref<NPCPuppet>, hitEvent: ref<gameHitEvent>) -> Void {
    let game: GameInstance = player.GetGame();
    let settings: ref<BluntLeapSettings> = system.Settings();
    let threshold: Float = GameInstance.GetStatsSystem(game).GetStatValue(Cast<StatsObjectID>(target.GetEntityID()), gamedataStatType.KnockdownDamageThresholdImpulse);
    let impulse: Float = (threshold + 10.0) * TweakDBInterface.GetFloat(t"Items.StrongArms.impulseOfOnePunch", 20.0) * settings.launchForce / 100.0;
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
    GameInstance.GetDelaySystem(game).DelayEvent(target, CreateForceRagdollEvent(n"Blunt Leap: sent flying"), 0.01, false);
    GameInstance.GetDelaySystem(game).DelayEvent(target, CreateRagdollApplyImpulseEvent(hitEvent.hitPosition, push, 1.0), 0.1, false);
    system.Log("Hit: sent flying, force " + FloatToStringPrec(impulse, 0) + ", side " + FloatToStringPrec(side, 1) + ", lift " + FloatToStringPrec(lift, 1));
  }
}
