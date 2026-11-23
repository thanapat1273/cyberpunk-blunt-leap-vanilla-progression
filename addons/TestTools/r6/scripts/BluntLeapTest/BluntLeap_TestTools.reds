// Battering Ram (Blunt Leap): test tools. An optional add-on for testing,
// NOT part of the release. Needs Battering Ram 1.2.1 or later (its test
// listener, BluntLeapTestListener).
//
// Install: copy the folder r6/scripts/BluntLeapTest into the game's
// r6/scripts folder (or unzip BatteringRam-TestTools.zip into the game
// folder). Remove: delete r6/scripts/BluntLeapTest. Install or remove it
// only while the game is closed.
//
// While installed:
//   - every thrown enemy's death shows a short message on screen, 2.5 s
//     after it, with how it died and what the game's loot check says;
//   - the CET console can turn on the wall-kill test mode
//     (cet_wall_kill_test.lua): every fully charged leap hit throws, with a
//     chosen force, and leaves the enemy with 1 health, so the impact with
//     a wall or the ground kills it. Off by default; off after a load;
//   - the CET console can list the last 10 thrown enemies that died
//     (cet_thrown_deaths.lua);
//   - with "Write a log" on, a "Game hit" line for every hit V lands with a
//     blunt weapon within 3 s of a stronger leap's start.
//
// (Redscript cannot add to or wrap a class a mod defines itself, so the
// main mod calls a listener object, and this add-on registers its own.)

// Registers the listener with the main mod each time a save loads (which
// also turns the test mode off and empties the list), and is what the CET
// lines call.
public class BluntLeapTestSystem extends ScriptableSystem {
  private let m_tools: ref<BluntLeapTestTools>;

  public final static func Get(game: GameInstance) -> ref<BluntLeapTestSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"BluntLeapTestSystem") as BluntLeapTestSystem;
  }

  private final func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    let main: ref<BluntLeapSystem> = BluntLeapSystem.Get(this.GetGameInstance());
    this.m_tools = new BluntLeapTestTools();
    this.m_tools.game = this.GetGameInstance();
    if IsDefined(main) {
      main.SetTestListener(this.m_tools);
    };
  }

  // From the CET console (cet_wall_kill_test.lua). On: every fully charged
  // leap hit on an enemy that can be thrown throws it (no stagger or
  // small-push roll, alerted or not) with the given force (%, 5 to 300),
  // and 0.05 s after the hit it is left with 1 health point (if the hit
  // itself did not take it down), so its impact with a wall or the ground
  // kills it. Returns what it did, for the console.
  public final func SetWallKillTest(on: Bool, force: Float) -> String {
    let text: String;
    if !IsDefined(this.m_tools) {
      return "Battering Ram test tools: load a save first";
    };
    this.m_tools.wallKills = on;
    this.m_tools.wallForce = ClampF(force, 5.0, 300.0);
    text = on ? "Battering Ram test: wall kills ON, every charged leap hit throws with force " + FloatToStringPrec(this.m_tools.wallForce, 0) + "% and leaves 1 health" : "Battering Ram test: wall kills OFF";
    this.m_tools.ScreenMessage(text);
    this.m_tools.Log(text);
    return text;
  }

  // From the CET console (cet_thrown_deaths.lua).
  public final func ThrownDeathReport() -> String {
    if !IsDefined(this.m_tools) {
      return "Battering Ram test tools: load a save first";
    };
    return this.m_tools.Report();
  }
}

// Wall-kill test: 0.05 s after the throwing hit, leave the enemy with one
// health point.
public class BluntLeapTestLowHealthCallback extends DelayCallback {
  public let tools: wref<BluntLeapTestTools>;
  public let npc: wref<NPCPuppet>;

  public func Call() -> Void {
    if IsDefined(this.tools) {
      this.tools.LeaveOneHealth(this.npc);
    };
  }
}

public class BluntLeapTestTools extends BluntLeapTestListener {
  public let game: GameInstance;
  public let wallKills: Bool;
  public let wallForce: Float;
  // The last thrown enemies that died (newest last, at most 10).
  private let m_diedIds: array<EntityID>;
  private let m_diedTimes: array<Float>;
  private let m_diedTexts: array<String>;

  public func ThrowChance(chance: Float) -> Float {
    return this.wallKills ? 100.0 : chance;
  }

  public func ThrowForce(force: Float) -> Float {
    return this.wallKills ? this.wallForce : force;
  }

  public func Thrown(system: ref<BluntLeapSystem>, target: ref<NPCPuppet>) -> Void {
    let callback: ref<BluntLeapTestLowHealthCallback>;
    if !this.wallKills || !IsDefined(target) {
      return;
    };
    callback = new BluntLeapTestLowHealthCallback();
    callback.tools = this;
    callback.npc = target;
    GameInstance.GetDelaySystem(this.game).DelayCallback(callback, 0.05, false);
  }

  // A thrown enemy died: shown on screen and remembered for the CET list.
  public func ThrownDeath(system: ref<BluntLeapSystem>, npc: wref<NPCPuppet>, reason: String, lootable: Bool) -> Void {
    if !IsDefined(npc) {
      return;
    };
    if ArraySize(this.m_diedIds) >= 10 {
      ArrayErase(this.m_diedIds, 0);
      ArrayErase(this.m_diedTimes, 0);
      ArrayErase(this.m_diedTexts, 0);
    };
    ArrayPush(this.m_diedIds, npc.GetEntityID());
    ArrayPush(this.m_diedTimes, this.Now());
    ArrayPush(this.m_diedTexts, reason);
    this.ScreenMessage("Battering Ram: #" + BluntLeapSystem.ShortId(npc.GetEntityID()) + " " + reason + ". Loot check: " + (lootable ? "ON" : "OFF"));
  }

  // Wall-kill test: one health point left, if the hit did not take it down.
  public func LeaveOneHealth(npc: wref<NPCPuppet>) -> Void {
    let pools: ref<StatPoolsSystem>;
    let id: StatsObjectID;
    if !IsDefined(npc) {
      return;
    };
    if npc.IsDead() || npc.IsIncapacitated() {
      this.Log("Test: #" + BluntLeapSystem.ShortId(npc.GetEntityID()) + " already went down from the hit");
      return;
    };
    pools = GameInstance.GetStatPoolsSystem(this.game);
    id = Cast<StatsObjectID>(npc.GetEntityID());
    this.Log("Test: #" + BluntLeapSystem.ShortId(npc.GetEntityID()) + " had " + FloatToStringPrec(pools.GetStatPoolValue(id, gamedataStatPoolType.Health, false), 1) + " health after the hit, left with 1");
    pools.RequestSettingStatPoolValue(id, gamedataStatPoolType.Health, 1.0, GetPlayer(this.game), false);
  }

  // The last thrown enemies that died since the save was loaded, newest
  // first, with how long ago, how they died, and what the game's loot check
  // says for each body now.
  public func Report() -> String {
    let text: String;
    let i: Int32 = ArraySize(this.m_diedIds) - 1;
    let npc: ref<NPCPuppet>;
    let now: String;
    if i < 0 {
      return "Battering Ram: no thrown enemy has died since the save was loaded.";
    };
    text = "Battering Ram: thrown enemies that died (newest first):";
    while i >= 0 {
      npc = GameInstance.FindEntityByID(this.game, this.m_diedIds[i]) as NPCPuppet;
      if IsDefined(npc) {
        now = npc.BluntLeapRefreshLoot() ? "loot prompt ON" : "loot prompt OFF";
      } else {
        now = "body no longer loaded";
      };
      text += "\n  #" + BluntLeapSystem.ShortId(this.m_diedIds[i]) + ", " + FloatToStringPrec(this.Now() - this.m_diedTimes[i], 0) + " s ago, " + this.m_diedTexts[i] + ": " + now;
      i -= 1;
    };
    return text;
  }

  public func Now() -> Float {
    return EngineTime.ToFloat(GameInstance.GetSimTime(this.game));
  }

  // A short message on screen.
  public func ScreenMessage(text: String) -> Void {
    let msg: SimpleScreenMessage;
    msg.isShown = true;
    msg.duration = 5.0;
    msg.message = text;
    GameInstance.GetBlackboardSystem(this.game).Get(GetAllBlackboardDefs().UI_Notifications).SetVariant(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(msg), true);
  }

  // Through the main mod's log ("Write a log").
  public func Log(text: String) -> Void {
    let main: ref<BluntLeapSystem> = BluntLeapSystem.Get(this.game);
    if IsDefined(main) {
      main.Log(text);
    };
  }
}

// For the log only (with "Write a log" on): every hit the game processes,
// from V with a blunt weapon, within 3 s of a stronger leap's start. It runs
// right after the hit-reaction stage callbacks (where the Thunder Breaker
// effector runs), so a "Game hit" line without a "Hit #" line before it is a
// hit the effector did not see; the line says what kind of hit it was.
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
