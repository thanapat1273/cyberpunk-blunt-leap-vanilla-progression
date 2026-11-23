// Blunt Leap: the system. Holds the settings, knows what the player has
// unlocked, gives the player the matching data packages (r6/tweaks/BluntLeap),
// and looks after the charge pool of the blunt weapon in hand.
//
// The leap itself is the game's own: MeleeLeapDecisions only asks for the
// CanMeleeLeap flag, which the vanilla perk grants while a blade is held.
// Our package grants it while a blunt weapon is held.

// Runs the refund check a moment after a save has loaded, when the player's
// perks are sure to be in place.
public class BluntLeapValidateCallback extends DelayCallback {
  public let system: wref<BluntLeapSystem>;

  public func Call() -> Void {
    if IsDefined(this.system) {
      this.system.Validate();
    };
  }
}

// Gorilla Arms: tells the system their timed charge is full (if it is still
// the same hold).
public class BluntLeapGorillaChargeCallback extends DelayCallback {
  public let system: wref<BluntLeapSystem>;
  public let hold: Int32;

  public func Call() -> Void {
    if IsDefined(this.system) {
      this.system.OnGorillaFull(this.hold);
    };
  }
}

// A charge pool was just requested: settle it once it exists (see
// BluntLeapSystem.SettleCharge). Tries counts the retries.
public class BluntLeapSettleChargeCallback extends DelayCallback {
  public let system: wref<BluntLeapSystem>;
  public let weapon: wref<WeaponObject>;
  public let tries: Int32;

  public func Call() -> Void {
    if IsDefined(this.system) {
      this.system.SettleCharge(this.weapon, this.tries);
    };
  }
}

// A moment after a thrown NPC went down (after, in seconds): is its body
// lootable?
public class BluntLeapBodyCheckCallback extends DelayCallback {
  public let system: wref<BluntLeapSystem>;
  public let npc: wref<NPCPuppet>;
  public let after: Float;

  public func Call() -> Void {
    if IsDefined(this.system) {
      this.system.RecheckThrownBody(this.npc, this.after);
    };
  }
}

// Watches a charge we added. Tells the system the moment it becomes full,
// and, while it fills, lets the system match its speed to Sandevistan. (The
// hold state has no update of its own, and the game does not call the empty
// one it inherits: a wrapper on it never ran in the test.)
public class BluntLeapChargeListener extends ScriptStatPoolsListener {
  public let system: wref<BluntLeapSystem>;
  public let weapon: wref<WeaponObject>;

  public func OnStatPoolValueChanged(oldValue: Float, newValue: Float, percToPoints: Float) -> Void {
    if !IsDefined(this.system) {
      return;
    };
    this.system.NoteChargeChanged(oldValue, newValue);
    if newValue >= 99.9 && oldValue < 99.9 {
      this.system.OnFullCharge();
      return;
    };
    if newValue > oldValue && newValue < 99.9 && IsDefined(this.weapon) {
      this.system.UpdateChargeRate(this.weapon, GameInstance.GetTimeSystem(this.weapon.GetGame()), "charge grew");
    };
  }
}

public class BluntLeapSystem extends ScriptableSystem {

  private let m_settings: ref<BluntLeapSettings>;

  // The unlock rule, read once per loaded save (a change applies at the next load).
  private let m_rule: BluntLeapUnlockRule;
  private let m_ruleRead: Bool;

  // What the player has right now.
  private let m_hasLeap: Bool;
  private let m_hasStronger: Bool;

  // Every weapon we gave a charge pool, with what we added to it (same index
  // in each array).
  private let m_chargeIds: array<EntityID>;
  private let m_chargeTimes: array<Float>;
  private let m_chargeBonuses: array<Float>;
  private let m_chargeTimeMods: array<ref<gameStatModifierData>>;
  private let m_chargeMaxMods: array<ref<gameStatModifierData>>;
  private let m_chargeBonusMods: array<ref<gameStatModifierData>>;
  private let m_chargeListeners: array<ref<BluntLeapChargeListener>>;
  // The fill rate (charge points per second) the weapon's pool has now.
  private let m_chargeRates: array<Float>;
  // For the log: the slow-down last written for the current hold (-1 = none
  // yet; set when a hold starts).
  private let m_loggedDilation: Float;
  private let m_loggedBlocked: Bool;

  // Extra reach for the punch that ends a fist leap: the modifier and the
  // weapon it is on.
  private let m_reachMod: ref<gameStatModifierData>;
  private let m_reachId: EntityID;

  // Gorilla Arms' timed charge: the arms it is for, whether it is full, and
  // a number for each hold, so a timer left over from an earlier hold is
  // ignored.
  private let m_gorillaId: EntityID;
  private let m_gorillaActive: Bool;
  private let m_gorillaFull: Bool;
  private let m_gorillaHold: Int32;

  // NPCs this mod sent flying (newest last, at most 64), so their bodies can
  // be made lootable again when they die (ClearThrownBody).
  private let m_thrownIds: array<EntityID>;

  // The melee crosshair now on screen (its bar shows our charge), and
  // whether a strong attack is being held.
  private let m_crosshair: wref<CrosshairGameController_Melee>;
  private let m_holding: Bool;

  // A pool was requested for this weapon and is not settled yet: its bar
  // stays hidden until then. When it was requested (sim time).
  private let m_settleId: EntityID;
  private let m_settlePending: Bool;
  private let m_settleRequested: Float;

  // For the log: when the button hold began, when the charged hold started,
  // its number since the save loaded, whether its first growth and first
  // bar move were written, and how many bar changes outside a hold were.
  private let m_pressStart: Float;
  private let m_holdStart: Float;
  private let m_holdNumber: Int32;
  private let m_growthLogged: Bool;
  private let m_barLogged: Bool;
  private let m_barOutsideLogged: Int32;

  // A stronger leap is on its way: its hit gets the extra effects until this time.
  private let m_strongUntil: Float;
  private let m_empDone: Bool;
  private let m_hitStopDone: Bool;
  // For the log: when the stronger leap started, and how many of its hits
  // the effector has seen.
  private let m_strongStart: Float;
  private let m_strongHits: Int32;
  // The enemies this stronger leap has already sent flying: each goes once.
  private let m_strongThrown: array<EntityID>;

  // What the perk texts were last set to, so the records are only touched
  // when a setting really changed (the perk screen may be open on a refresh).
  private let m_appliedLeapDesc: String;
  private let m_appliedStrongerDesc: String;
  private let m_appliedLeapFloats: String;
  private let m_appliedStrongerFloats: String;

  public final static func Get(game: GameInstance) -> ref<BluntLeapSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"BluntLeapSystem") as BluntLeapSystem;
  }

  private func OnAttach() -> Void {
    this.Settings();
    this.Rule();
  }

  private func OnDetach() -> Void {
    if IsDefined(this.m_settings) {
      this.m_settings.Unregister();
    };
  }

  private final func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    let callback: ref<BluntLeapValidateCallback> = new BluntLeapValidateCallback();
    callback.system = this;
    this.ForgetCharges();
    this.m_reachMod = null;
    this.StopGorillaCharge();
    ArrayClear(this.m_thrownIds);
    // m_settlePending is left as it is: the crosshair may have appeared and
    // requested a pool before this runs, and every new request sets it.
    this.m_holding = false;
    this.m_holdNumber = 0;
    this.m_barOutsideLogged = 0;
    this.Refresh();
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(callback, 1.5, false);
  }

  public final func Settings() -> ref<BluntLeapSettings> {
    if !IsDefined(this.m_settings) {
      this.m_settings = new BluntLeapSettings();
      this.m_settings.system = this;
      this.m_settings.Register();
    };
    return this.m_settings;
  }

  public final func Log(const text: script_ref<String>) -> Void {
    if this.Settings().debugLog {
      FTLog("[Blunt Leap] " + Deref(text));
    };
  }

  private final func Now() -> Float {
    return EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
  }

  // -------------------------------------------------------- unlock rule

  public final func Rule() -> BluntLeapUnlockRule {
    if !this.m_ruleRead {
      this.m_rule = this.Settings().unlockRule;
      this.m_ruleRead = true;
    };
    return this.m_rule;
  }

  // The perk IDs are added to the game's list by Perk Addition Framework at
  // each start, so they are looked up, never written down.
  public final static func LeapPerk() -> gamedataNewPerkType {
    let record: ref<NewPerk_Record> = TweakDBInterface.GetNewPerkRecord(t"NewPerks.BluntLeap_Leap");
    if !IsDefined(record) {
      return gamedataNewPerkType.Invalid;
    };
    return record.Type();
  }

  public final static func StrongerPerk() -> gamedataNewPerkType {
    let record: ref<NewPerk_Record> = TweakDBInterface.GetNewPerkRecord(t"NewPerks.BluntLeap_Stronger");
    if !IsDefined(record) {
      return gamedataNewPerkType.Invalid;
    };
    return record.Type();
  }

  // False when Perk Addition Framework is missing: the perks cannot exist then.
  public final static func PerksAvailable() -> Bool {
    let leap: gamedataNewPerkType = BluntLeapSystem.LeapPerk();
    let stronger: gamedataNewPerkType = BluntLeapSystem.StrongerPerk();
    return NotEquals(leap, gamedataNewPerkType.Invalid) && NotEquals(stronger, gamedataNewPerkType.Invalid) && NotEquals(leap, stronger);
  }

  public final func UsesPerks() -> Bool {
    let rule: BluntLeapUnlockRule = this.Rule();
    return (Equals(rule, BluntLeapUnlockRule.DashAndPerks) || Equals(rule, BluntLeapUnlockRule.PerksOnly)) && BluntLeapSystem.PerksAvailable();
  }

  // The two perk nodes are shown only when the perks are in use.
  public final func NodesHidden() -> Bool {
    return !this.UsesPerks();
  }

  public final func NeedsDash() -> Bool {
    return Equals(this.Rule(), BluntLeapUnlockRule.DashAndPerks);
  }

  // Dash has two levels; the rule asks for both.
  public final static func HasDash(data: ref<PlayerDevelopmentData>) -> Bool {
    return IsDefined(data) && data.IsNewPerkBought(gamedataNewPerkType.Reflexes_Central_Milestone_2) >= 2;
  }

  public final func HasLeap() -> Bool {
    return this.m_hasLeap;
  }

  public final func HasStrongerLeap() -> Bool {
    return this.m_hasStronger;
  }

  private final func UpdateOwnership() -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    let data: ref<PlayerDevelopmentData>;
    let rule: BluntLeapUnlockRule = this.Rule();
    if !this.Settings().enabled {
      this.m_hasLeap = false;
      this.m_hasStronger = false;
      return;
    };
    if Equals(rule, BluntLeapUnlockRule.AlwaysLeap) {
      this.m_hasLeap = true;
      this.m_hasStronger = false;
      return;
    };
    if Equals(rule, BluntLeapUnlockRule.AlwaysBoth) || !BluntLeapSystem.PerksAvailable() {
      // Without Perk Addition Framework there are no perks to buy, so the
      // mod falls back to giving both.
      this.m_hasLeap = true;
      this.m_hasStronger = true;
      return;
    };
    data = PlayerDevelopmentSystem.GetData(player);
    this.m_hasLeap = IsDefined(data) && data.IsNewPerkBought(BluntLeapSystem.LeapPerk()) > 0;
    this.m_hasStronger = this.m_hasLeap && data.IsNewPerkBought(BluntLeapSystem.StrongerPerk()) > 0;
  }

  // A perk was bought, sold or reset.
  public final func OnPerksChanged() -> Void {
    this.Refresh();
  }

  // Refunds points spent on our perks when the rule no longer allows them:
  // the rule changed to one without perks, or Dash is required and missing.
  public final func Validate() -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    let data: ref<PlayerDevelopmentData>;
    let refundAll: Bool;
    if !IsDefined(player) || !BluntLeapSystem.PerksAvailable() {
      return;
    };
    data = PlayerDevelopmentSystem.GetData(player);
    if !IsDefined(data) {
      return;
    };
    if !this.UsesPerks() {
      refundAll = true;
    } else {
      refundAll = this.NeedsDash() && !BluntLeapSystem.HasDash(data);
    };
    if refundAll {
      if data.BluntLeap_Refund(BluntLeapSystem.StrongerPerk()) {
        this.Log("Refunded the stronger leap perk");
      };
      if data.BluntLeap_Refund(BluntLeapSystem.LeapPerk()) {
        this.Log("Refunded the blunt leap perk");
      };
    };
    this.Refresh();
  }

  // ------------------------------------------------------------ packages

  // Applies what the player has. Removes before it applies, so it is safe to
  // call any number of times (save load, settings change, perk bought or sold).
  public final func Refresh() -> Void {
    let game: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GetPlayer(game);
    if !IsDefined(player) {
      return;
    };
    let settings: ref<BluntLeapSettings> = this.Settings();
    let packages: ref<GameplayLogicPackageSystem> = GameInstance.GetGameplayLogicPackageSystem(game);

    this.UpdateOwnership();

    this.UpdatePerkTexts();

    packages.RemovePackage(player, t"BluntLeap.LeapAbility");
    packages.RemovePackage(player, t"BluntLeap.AirLeapAbility");
    packages.RemovePackage(player, t"BluntLeap.DistanceBonus");
    packages.RemovePackage(player, t"BluntLeap.Impact");

    if !this.m_hasLeap {
      return;
    };

    packages.ApplyPackage(player, player, t"BluntLeap.LeapAbility");
    if settings.airLeap {
      packages.ApplyPackage(player, player, t"BluntLeap.AirLeapAbility");
    };
    if settings.distanceBonus > 0.0 {
      // The game's effector reads this value when the package is applied.
      TweakDBManager.SetFlat(t"BluntLeap.DistanceBonusEffector.maxPercentMult", ToVariant(1.0 + settings.distanceBonus / 100.0));
      TweakDBManager.UpdateRecord(t"BluntLeap.DistanceBonusEffector");
      packages.ApplyPackage(player, player, t"BluntLeap.DistanceBonus");
    };
    if this.m_hasStronger {
      TweakDBManager.SetFlat(t"BluntLeap.EMP.range", ToVariant(settings.empRadius));
      // Enemies the EMP blast damages (beside the one the swing hit) ask the
      // game for a stagger, when "Stagger when not sent flying" is on: hit
      // reaction strength 2 at least. The game still decides: resistances, a
      // stagger threshold of 0 (Berserk and similar), a power difference, a
      // recent stagger or knockdown (the struck enemy itself, just thrown or
      // staggered, gets only a twitch). The blast copies the Yinglong EMP, a
      // Ranged attack, so the game's "strong explosion" knockdown never
      // applies. Off: the Yinglong's own 1 to 2 (usually a twitch).
      TweakDBManager.SetFlat(t"BluntLeap.EMP.hitReactionSeverityMin", ToVariant(settings.stagger ? 2 : 1));
      TweakDBManager.SetFlat(t"BluntLeap.EMP.hitReactionSeverityMax", ToVariant(2));
      TweakDBManager.UpdateRecord(t"BluntLeap.EMP");
      packages.ApplyPackage(player, player, t"BluntLeap.Impact");
    };
    this.Log("Applied: leap=" + ToString(this.m_hasLeap) + " stronger=" + ToString(this.m_hasStronger));
  }

  // ---------------------------------------------------------- perk texts

  // Points each perk at the description that matches the settings, and puts
  // the numbers the descriptions show ({float_0}, ...) into the perk records.
  // The default description keys are already in the records, so with default
  // settings nothing is rewritten.
  private final func UpdatePerkTexts() -> Void {
    let settings: ref<BluntLeapSettings> = this.Settings();
    let leapDesc: String = BluntLeapEnglish.LeapKey(settings.alwaysCharged, settings.airLeap, settings.distanceBonus > 0.0);
    let strongerDesc: String = BluntLeapEnglish.StrongerKey(settings.emp, settings.stagger);
    let leapFloats: String = FloatToStringPrec(settings.distanceBonus, 2);
    let strongerFloats: String = FloatToStringPrec(settings.extraRange, 2) + "/" + FloatToStringPrec(settings.launchChance, 2) + "/" + FloatToStringPrec(settings.launchChanceHeavy, 2);

    if NotEquals(this.m_appliedLeapFloats, leapFloats) {
      TweakDBManager.SetFlat(t"NewPerks.BluntLeap_Leap_UI.floatValues", ToVariant([settings.distanceBonus]));
      TweakDBManager.UpdateRecord(t"NewPerks.BluntLeap_Leap_UI");
      this.m_appliedLeapFloats = leapFloats;
    };
    if NotEquals(this.m_appliedStrongerFloats, strongerFloats) {
      TweakDBManager.SetFlat(t"NewPerks.BluntLeap_Stronger_UI.floatValues", ToVariant([settings.extraRange, settings.launchChance, settings.launchChanceHeavy]));
      TweakDBManager.UpdateRecord(t"NewPerks.BluntLeap_Stronger_UI");
      this.m_appliedStrongerFloats = strongerFloats;
    };
    if NotEquals(this.m_appliedLeapDesc, leapDesc) {
      if NotEquals(TweakDBInterface.GetString(t"NewPerks.BluntLeap_Leap.loc_desc_key", ""), leapDesc) {
        TweakDBManager.SetFlat(t"NewPerks.BluntLeap_Leap.loc_desc_key", ToVariant(leapDesc));
        TweakDBManager.UpdateRecord(t"NewPerks.BluntLeap_Leap");
      };
      this.m_appliedLeapDesc = leapDesc;
    };
    if NotEquals(this.m_appliedStrongerDesc, strongerDesc) {
      if NotEquals(TweakDBInterface.GetString(t"NewPerks.BluntLeap_Stronger.loc_desc_key", ""), strongerDesc) {
        TweakDBManager.SetFlat(t"NewPerks.BluntLeap_Stronger.loc_desc_key", ToVariant(strongerDesc));
        TweakDBManager.UpdateRecord(t"NewPerks.BluntLeap_Stronger");
      };
      this.m_appliedStrongerDesc = strongerDesc;
    };
  }

  // ------------------------------------------------------- stronger leap

  // The leap range of a fully charged leap with the stronger leap.
  public final func StrongRange(baseRange: Float) -> Float {
    return baseRange * (1.0 + this.Settings().extraRange / 100.0);
  }

  // A fully charged leap has started: its hit gets the extra effects.
  public final func ArmStrongLeap(seconds: Float) -> Void {
    this.m_strongUntil = this.Now() + seconds;
    this.m_empDone = false;
    this.m_hitStopDone = false;
    this.m_strongStart = this.Now();
    this.m_strongHits = 0;
    ArrayClear(this.m_strongThrown);
    this.Log("Stronger leap started");
  }

  public final func DisarmStrongLeap() -> Void {
    if this.m_strongUntil > 0.0 {
      this.Log("Stronger leap ended at +" + FloatToStringPrec(this.Now() - this.m_strongStart, 2) + " s (end of the leap attack)");
    };
    this.m_strongUntil = 0.0;
  }

  // One throw per enemy per stronger leap. A swing that hits one enemy twice
  // pushed it twice (the 20 to 50 m flights); several enemies hit by one
  // swing still all fly. True the first time it is asked for an enemy.
  public final func TakeThrow(id: EntityID) -> Bool {
    if ArrayContains(this.m_strongThrown, id) {
      return false;
    };
    ArrayPush(this.m_strongThrown, id);
    return true;
  }

  // For the log: seconds since the last stronger leap started (-1 if none).
  public final func SinceStrongStart() -> Float {
    if this.m_strongStart <= 0.0 {
      return -1.0;
    };
    return this.Now() - this.m_strongStart;
  }

  // For the log: "Hit #n +t s" for a hit during the stronger leap.
  public final func NextStrongHitLabel() -> String {
    this.m_strongHits += 1;
    return "Hit #" + IntToString(this.m_strongHits) + " +" + FloatToStringPrec(this.Now() - this.m_strongStart, 2) + " s";
  }

  public final func StrongLeapArmed() -> Bool {
    return this.m_hasStronger && this.m_strongUntil > 0.0 && this.Now() <= this.m_strongUntil;
  }

  // True the first time it is asked during one stronger leap.
  public final func TakeEmp() -> Bool {
    if this.m_empDone {
      return false;
    };
    this.m_empDone = true;
    return true;
  }

  public final func TakeHitStop() -> Bool {
    if this.m_hitStopDone {
      return false;
    };
    this.m_hitStopDone = true;
    return true;
  }

  // ------------------------------------------------------------- charge
  //
  // Which charge is ours is decided from the weapon itself, never from memory
  // of the last weapon drawn: a weapon keeps its entity when it is holstered
  // and drawn again, so several weapons can carry our pool at once.
  //   - ours: a blunt weapon whose game record has no charge pool;
  //   - theirs: stun batons and Gorilla Arms, which have their own.
  // The modifiers we add are remembered per weapon, so they can be changed
  // or taken off again.

  // Blunt weapons charge only when the charge means something: in "Always
  // charged" mode, or once the stronger leap is available.
  public final func ChargeWanted() -> Bool {
    let settings: ref<BluntLeapSettings> = this.Settings();
    return this.m_hasLeap && (settings.alwaysCharged || this.m_hasStronger);
  }

  // True if the weapon's game record gives it a charge pool of its own.
  public final static func HasOwnCharge(weapon: wref<WeaponObject>) -> Bool {
    let record: ref<WeaponItem_Record>;
    let pools: array<wref<StatPool_Record>>;
    let i: Int32 = 0;
    if !IsDefined(weapon) {
      return false;
    };
    record = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(weapon.GetItemID()));
    if !IsDefined(record) {
      return false;
    };
    record.StatPools(pools);
    while i < ArraySize(pools) {
      if IsDefined(pools[i]) && Equals(pools[i].StatPoolType(), gamedataStatPoolType.WeaponCharge) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  // A weapon whose charge, if it has one, is ours.
  public final static func IsOurChargeType(weapon: wref<WeaponObject>) -> Bool {
    return IsDefined(weapon) && WeaponObject.IsBlunt(weapon.GetItemID()) && !BluntLeapSystem.HasOwnCharge(weapon);
  }

  // True if this weapon carries a charge pool we added.
  public final func OwnsChargeOf(weapon: wref<WeaponObject>) -> Bool {
    return BluntLeapSystem.IsOurChargeType(weapon) && GameInstance.GetStatPoolsSystem(weapon.GetGame()).IsStatPoolAdded(Cast<StatsObjectID>(weapon.GetEntityID()), gamedataStatPoolType.WeaponCharge);
  }

  // 0.0 to 1.0, the same measure the game's damage rule uses.
  public final static func ChargeOf(weapon: wref<WeaponObject>) -> Float {
    if !IsDefined(weapon) {
      return 0.0;
    };
    if !GameInstance.GetStatPoolsSystem(weapon.GetGame()).IsStatPoolAdded(Cast<StatsObjectID>(weapon.GetEntityID()), gamedataStatPoolType.WeaponCharge) {
      return 0.0;
    };
    return WeaponObject.GetWeaponChargeNormalized(weapon);
  }

  // Empties a charge we added. The game's own code never empties it: it
  // clears the player's pool instead of the weapon's, and the pool has no
  // decay.
  public final func ClearCharge(weapon: wref<WeaponObject>) -> Void {
    if !this.OwnsChargeOf(weapon) {
      return;
    };
    GameInstance.GetStatPoolsSystem(weapon.GetGame()).RequestSettingStatPoolValue(Cast<StatsObjectID>(weapon.GetEntityID()), gamedataStatPoolType.WeaponCharge, 0.0, null, true);
  }

  private final func ChargeTimeFor(weapon: wref<WeaponObject>) -> Float {
    let settings: ref<BluntLeapSettings> = this.Settings();
    let type: gamedataItemType = WeaponObject.GetWeaponType(weapon.GetItemID());
    switch type {
      case gamedataItemType.Wea_Fists:
        return settings.chargeFists;
      case gamedataItemType.Wea_OneHandedClub:
        return settings.chargeOneHanded;
      case gamedataItemType.Wea_TwoHandedClub:
        return settings.chargeTwoHanded;
      case gamedataItemType.Wea_Hammer:
        return settings.chargeHammer;
    };
    return settings.chargeOneHanded;
  }

  private final func ChargeIndex(id: EntityID) -> Int32 {
    let i: Int32 = 0;
    while i < ArraySize(this.m_chargeIds) {
      if this.m_chargeIds[i] == id {
        return i;
      };
      i += 1;
    };
    return -1;
  }

  // Forget every weapon (a save was loaded: all weapons are new).
  private final func ForgetCharges() -> Void {
    ArrayClear(this.m_chargeIds);
    ArrayClear(this.m_chargeTimes);
    ArrayClear(this.m_chargeBonuses);
    ArrayClear(this.m_chargeTimeMods);
    ArrayClear(this.m_chargeMaxMods);
    ArrayClear(this.m_chargeBonusMods);
    ArrayClear(this.m_chargeListeners);
    ArrayClear(this.m_chargeRates);
  }

  // Gives the blunt weapon in hand our charge pool and charge time when the
  // charge is wanted, and takes them off when it is not. Returns true when
  // the weapon has our charge afterwards. Called when the weapon's crosshair
  // appears and again when a strong attack starts to be held.
  public final func PrepareCharge(weapon: wref<WeaponObject>) -> Bool {
    let game: GameInstance;
    let id: EntityID;
    let statsId: StatsObjectID;
    let stats: ref<StatsSystem>;
    let pools: ref<StatPoolsSystem>;
    let settings: ref<BluntLeapSettings> = this.Settings();
    let index: Int32;
    let hasPool: Bool;
    let time: Float;
    let bonus: Float;
    let timeMod: ref<gameStatModifierData>;
    let maxMod: ref<gameStatModifierData>;
    let bonusMod: ref<gameStatModifierData>;
    let listener: ref<BluntLeapChargeListener>;
    let settle: ref<BluntLeapSettleChargeCallback>;

    if !BluntLeapSystem.IsOurChargeType(weapon) {
      return false;
    };
    game = weapon.GetGame();
    id = weapon.GetEntityID();
    statsId = Cast<StatsObjectID>(id);
    stats = GameInstance.GetStatsSystem(game);
    pools = GameInstance.GetStatPoolsSystem(game);
    index = this.ChargeIndex(id);
    hasPool = pools.IsStatPoolAdded(statsId, gamedataStatPoolType.WeaponCharge);

    if !this.ChargeWanted() {
      if hasPool || index >= 0 {
        this.ReleaseCharge(weapon);
      };
      return false;
    };

    // Remembered, but the entity lost our pool: it is a new weapon object.
    if index >= 0 && !hasPool {
      this.ReleaseCharge(weapon);
      index = -1;
    };

    time = this.ChargeTimeFor(weapon);
    bonus = settings.chargeBonus;

    if index < 0 {
      timeMod = RPGManager.CreateStatModifier(gamedataStatType.ChargeTime, gameStatModifierType.Additive, time);
      stats.AddModifier(statsId, timeMod);
      maxMod = null;
      if stats.GetStatValue(statsId, gamedataStatType.Charge) <= 0.0 {
        // The pool's size comes from this stat; charged weapons have 100.
        maxMod = RPGManager.CreateStatModifier(gamedataStatType.Charge, gameStatModifierType.Additive, 100.0);
        stats.AddModifier(statsId, maxMod);
      };
      bonusMod = this.BonusModifier(bonus);
      if IsDefined(bonusMod) {
        stats.AddModifier(statsId, bonusMod);
      };
      if !hasPool {
        pools.RequestAddingStatPool(statsId, t"BluntLeap.ChargePool", true);
        // Emptying it now may do nothing, and its bar can show a leftover
        // fill: settle it half a second later (the time seen to work in
        // game), and keep the bar hidden until then.
        this.m_settleId = id;
        this.m_settlePending = true;
        this.m_settleRequested = this.Now();
        settle = new BluntLeapSettleChargeCallback();
        settle.system = this;
        settle.weapon = weapon;
        settle.tries = 0;
        GameInstance.GetDelaySystem(game).DelayCallback(settle, 0.5, false);
      };
      listener = new BluntLeapChargeListener();
      listener.system = this;
      listener.weapon = weapon;
      pools.RequestRegisteringListener(statsId, gamedataStatPoolType.WeaponCharge, listener);
      ArrayPush(this.m_chargeIds, id);
      ArrayPush(this.m_chargeTimes, time);
      ArrayPush(this.m_chargeBonuses, bonus);
      ArrayPush(this.m_chargeTimeMods, timeMod);
      ArrayPush(this.m_chargeMaxMods, maxMod);
      ArrayPush(this.m_chargeBonusMods, bonusMod);
      ArrayPush(this.m_chargeListeners, listener);
      ArrayPush(this.m_chargeRates, 0.0);
      this.Log("Charge added to the weapon in hand, time " + FloatToStringPrec(time, 2) + " s");
      return true;
    };

    // Known weapon: follow changed settings.
    if AbsF(time - this.m_chargeTimes[index]) > 0.001 {
      stats.RemoveModifier(statsId, this.m_chargeTimeMods[index]);
      this.m_chargeTimeMods[index] = RPGManager.CreateStatModifier(gamedataStatType.ChargeTime, gameStatModifierType.Additive, time);
      stats.AddModifier(statsId, this.m_chargeTimeMods[index]);
      this.m_chargeTimes[index] = time;
    };
    if AbsF(bonus - this.m_chargeBonuses[index]) > 0.01 {
      if IsDefined(this.m_chargeBonusMods[index]) {
        stats.RemoveModifier(statsId, this.m_chargeBonusMods[index]);
      };
      this.m_chargeBonusMods[index] = this.BonusModifier(bonus);
      if IsDefined(this.m_chargeBonusMods[index]) {
        stats.AddModifier(statsId, this.m_chargeBonusMods[index]);
      };
      this.m_chargeBonuses[index] = bonus;
    };
    return true;
  }

  // The game's charged-attack bonus is a third of the charge multiplier
  // (0.25 on melee weapons, so +33% at full charge). Scaled to the setting.
  private final func BonusModifier(bonus: Float) -> ref<gameStatModifierData> {
    if AbsF(bonus - 33.0) <= 0.5 {
      return null;
    };
    return RPGManager.CreateStatModifier(gamedataStatType.ChargeMultiplier, gameStatModifierType.Multiplier, bonus / 33.25);
  }

  // Takes our pool and modifiers off a weapon.
  private final func ReleaseCharge(weapon: wref<WeaponObject>) -> Void {
    let statsId: StatsObjectID = Cast<StatsObjectID>(weapon.GetEntityID());
    let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(weapon.GetGame());
    let pools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(weapon.GetGame());
    let index: Int32 = this.ChargeIndex(weapon.GetEntityID());
    if index >= 0 {
      if IsDefined(this.m_chargeListeners[index]) {
        pools.RequestUnregisteringListener(statsId, gamedataStatPoolType.WeaponCharge, this.m_chargeListeners[index]);
      };
      if IsDefined(this.m_chargeTimeMods[index]) {
        stats.RemoveModifier(statsId, this.m_chargeTimeMods[index]);
      };
      if IsDefined(this.m_chargeMaxMods[index]) {
        stats.RemoveModifier(statsId, this.m_chargeMaxMods[index]);
      };
      if IsDefined(this.m_chargeBonusMods[index]) {
        stats.RemoveModifier(statsId, this.m_chargeBonusMods[index]);
      };
      ArrayErase(this.m_chargeIds, index);
      ArrayErase(this.m_chargeTimes, index);
      ArrayErase(this.m_chargeBonuses, index);
      ArrayErase(this.m_chargeTimeMods, index);
      ArrayErase(this.m_chargeMaxMods, index);
      ArrayErase(this.m_chargeBonusMods, index);
      ArrayErase(this.m_chargeListeners, index);
      ArrayErase(this.m_chargeRates, index);
    };
    if pools.IsStatPoolAdded(statsId, gamedataStatPoolType.WeaponCharge) {
      pools.RequestRemovingStatPool(statsId, gamedataStatPoolType.WeaponCharge);
    };
  }

  // The fill rate the game gives a charge: 100 points over the weapon's
  // ChargeTime (MeleeChargedHoldEvents.GetChargeValuePerSec). 0 if none.
  private final static func BaseChargeRate(weapon: wref<WeaponObject>) -> Float {
    let chargeTime: Float = GameInstance.GetStatsSystem(weapon.GetGame()).GetStatValue(Cast<StatsObjectID>(weapon.GetEntityID()), gamedataStatType.ChargeTime);
    if chargeTime <= 0.0 {
      return 0.0;
    };
    return 100.0 / chargeTime;
  }

  // A hold has just started: the game set the pool's fill rate to the base
  // rate (StartPool).
  public final func NoteChargeStarted(weapon: wref<WeaponObject>) -> Void {
    let index: Int32;
    let pools: ref<StatPoolsSystem>;
    let statsId: StatsObjectID;
    let regen: StatPoolModifier;
    let since: String;
    this.m_holding = true;
    this.m_holdStart = this.Now();
    this.m_holdNumber += 1;
    this.m_growthLogged = false;
    this.m_barLogged = false;
    if !IsDefined(weapon) {
      return;
    };
    index = this.ChargeIndex(weapon.GetEntityID());
    if index >= 0 {
      this.m_chargeRates[index] = BluntLeapSystem.BaseChargeRate(weapon);
    };
    this.m_loggedDilation = -1.0;
    this.m_loggedBlocked = false;
    if this.Settings().debugLog && this.OwnsChargeOf(weapon) {
      pools = GameInstance.GetStatPoolsSystem(weapon.GetGame());
      statsId = Cast<StatsObjectID>(weapon.GetEntityID());
      pools.GetModifier(statsId, gamedataStatPoolType.WeaponCharge, gameStatPoolModificationTypes.Regeneration, regen);
      if this.m_pressStart > 0.0 && this.m_holdStart - this.m_pressStart < 10.0 {
        since = FloatToStringPrec(this.m_holdStart - this.m_pressStart, 2) + " s after the button hold began";
      } else {
        since = "(button hold start not seen)";
      };
      this.Log("Hold #" + IntToString(this.m_holdNumber) + ": charged hold started " + since + "; pool " + FloatToStringPrec(pools.GetStatPoolValue(statsId, gamedataStatPoolType.WeaponCharge, true), 0) + "%, filling " + (regen.enabled ? "on" : "off") + ", start delay " + FloatToStringPrec(regen.startDelay, 2) + " s, " + FloatToStringPrec(regen.valuePerSec, 1) + " per s" + (this.m_settlePending ? "; the pool is not settled yet" : ""));
    };
    this.m_pressStart = 0.0;
  }

  // The attack button is being held (MeleeHoldEvents), before the charged
  // hold starts. For the log.
  public final func NotePressStarted() -> Void {
    this.m_pressStart = this.Now();
  }

  // A charge we added changed. For the log: when the current hold's charge
  // first grew and when it became full.
  public final func NoteChargeChanged(oldValue: Float, newValue: Float) -> Void {
    if !this.m_holding || !this.Settings().debugLog {
      return;
    };
    if !this.m_growthLogged && newValue > oldValue {
      this.m_growthLogged = true;
      this.Log("Hold #" + IntToString(this.m_holdNumber) + ": charge first grew " + FloatToStringPrec(this.Now() - this.m_holdStart, 2) + " s after the hold started (" + FloatToStringPrec(oldValue, 0) + " to " + FloatToStringPrec(newValue, 0) + "%)");
    };
    if newValue >= 99.9 && oldValue < 99.9 {
      this.Log("Hold #" + IntToString(this.m_holdNumber) + ": charge full " + FloatToStringPrec(this.Now() - this.m_holdStart, 2) + " s after the hold started");
    };
  }

  // The crosshair's bar was moved by the game (its pool listener). For the
  // log: the first move of each hold, and moves outside a hold in the
  // first 3 s after a pool was requested (a leftover fill would come from
  // one).
  public final func NoteBarMoved(weapon: wref<WeaponObject>, oldValue: Float, newValue: Float) -> Void {
    if !this.Settings().debugLog || !BluntLeapSystem.IsOurChargeType(weapon) {
      return;
    };
    if this.m_holding {
      if !this.m_barLogged && newValue > oldValue {
        this.m_barLogged = true;
        this.Log("Hold #" + IntToString(this.m_holdNumber) + ": bar first moved " + FloatToStringPrec(this.Now() - this.m_holdStart, 2) + " s after the hold started (to " + FloatToStringPrec(newValue, 0) + "%)");
      };
      return;
    };
    if newValue > 0.0 && this.m_barOutsideLogged < 5 && this.Now() - this.m_settleRequested < 3.0 {
      this.m_barOutsideLogged += 1;
      this.Log("Bar set to " + FloatToStringPrec(newValue, 0) + "% outside a hold (from " + FloatToStringPrec(oldValue, 0) + "%)" + (this.m_settlePending ? ", before the pool was settled" : ""));
    };
  }

  // True while the bar of this weapon should stay hidden: its pool was
  // requested and is not settled yet.
  public final func SettlePending(weapon: wref<WeaponObject>) -> Bool {
    return this.m_settlePending && IsDefined(weapon) && this.m_settleId == weapon.GetEntityID();
  }

  public final func NoteHoldEnded() -> Void {
    this.m_holding = false;
  }

  public final func NoteCrosshair(crosshair: wref<CrosshairGameController_Melee>) -> Void {
    this.m_crosshair = crosshair;
  }

  // Half a second after a charge pool was requested (a save loaded, a
  // weapon drawn), and then every 0.1 s until the pool exists (for up to
  // about 5 s): empty it unless a hold has started, then show the
  // crosshair's bar, which stayed hidden until now, at the pool's real
  // value. In game the bar showed a leftover fill (50 to 100%) right after
  // a load while the pool itself held 0%; hiding it until here means that
  // fill is never seen.
  public final func SettleCharge(weapon: wref<WeaponObject>, tries: Int32) -> Void {
    let pools: ref<StatPoolsSystem>;
    let statsId: StatsObjectID;
    let before: Float;
    let shown: Bool = false;
    let retry: ref<BluntLeapSettleChargeCallback>;
    if !IsDefined(weapon) || !this.SettlePending(weapon) {
      return;
    };
    if !this.OwnsChargeOf(weapon) {
      if tries < 45 && this.ChargeIndex(weapon.GetEntityID()) >= 0 {
        retry = new BluntLeapSettleChargeCallback();
        retry.system = this;
        retry.weapon = weapon;
        retry.tries = tries + 1;
        GameInstance.GetDelaySystem(weapon.GetGame()).DelayCallback(retry, 0.1, false);
      } else {
        this.m_settlePending = false;
        this.Log("Charge pool not there " + FloatToStringPrec(this.Now() - this.m_settleRequested, 2) + " s after it was requested; gave up waiting");
      };
      return;
    };
    this.m_settlePending = false;
    pools = GameInstance.GetStatPoolsSystem(weapon.GetGame());
    statsId = Cast<StatsObjectID>(weapon.GetEntityID());
    before = pools.GetStatPoolValue(statsId, gamedataStatPoolType.WeaponCharge, true);
    if !this.m_holding {
      this.ClearCharge(weapon);
    };
    if IsDefined(this.m_crosshair) && this.Settings().chargeBar {
      shown = this.m_crosshair.BluntLeapBarReady(weapon.GetEntityID(), this.m_holding ? before : 0.0);
    };
    this.Log("Charge pool settled " + FloatToStringPrec(this.Now() - this.m_settleRequested, 2) + " s after it was requested: it held " + FloatToStringPrec(before, 0) + "%" + (this.m_holding ? " (a hold had started, kept)" : ", emptied") + (shown ? "; bar shown" : "; bar not shown (no crosshair for it)"));
  }

  // How slowly Sandevistan makes the world run: 0 to 1, where 1 means it is
  // off. Sandevistan slows the world under the time reason "sandevistan" and
  // exempts the player (SandevistanEvents, SetTimeDilationGlobal). The time
  // system's own figure is used first. If that shows no slow-down while
  // Sandevistan is on (with the player exempt it may report the player's
  // time), the figure the game sets is used: the player's Sandevistan time
  // scale (TimeDilationSandevistanTimeScale). The report is for the log.
  private final func SandevistanDilation(time: ref<TimeSystem>, out report: String) -> Float {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    let keyOn: Bool = time.IsTimeDilationActive(TimeDilationHelper.GetSandevistanKey());
    let anyOn: Bool = time.IsTimeDilationActive();
    let effectOn: Bool = false;
    let active: Float = time.GetActiveTimeDilation();
    let scale: Float = 0.0;
    let dilation: Float = 1.0;
    if IsDefined(player) {
      effectOn = StatusEffectSystem.ObjectHasStatusEffectOfType(player, gamedataStatusEffectType.Sandevistan);
      scale = GameInstance.GetStatsSystem(this.GetGameInstance()).GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.TimeDilationSandevistanTimeScale);
    };
    if keyOn || (effectOn && anyOn) {
      if active > 0.0 && active < 1.0 {
        dilation = active;
      } else {
        if scale > 0.0 && scale < 1.0 {
          dilation = scale;
        };
      };
    };
    report = "Sandevistan time " + (keyOn ? "on" : "off") + ", Sandevistan effect " + (effectOn ? "on" : "off") + ", any slow-down " + (anyOn ? "on" : "off") + ", time system " + FloatToStringPrec(active, 3) + ", Sandevistan time scale " + FloatToStringPrec(scale, 3);
    return dilation;
  }

  // While a charge fills (called each time the charge grows). The charge fills in world time, so Sandevistan slows it,
  // as it slows every melee charge in the game. The setting can make ours
  // catch up:
  //   Partial: halfway between Vanilla and Full. With slow-down d the charge
  //            fills at d of its normal real-time speed under Vanilla and at
  //            1 under Full; Partial gives (1 + d) / 2, that is a world-time
  //            rate of (1 + d) / (2 d). (It used the game's gun catch-up,
  //            1 / d times 0.5 to 0.9, until 2026-11-23: for milder
  //            Sandevistans that came out slower than Vanilla.)
  //   Full:    1 / slow-down, the same real time as without Sandevistan.
  // The pool's fill rate is only changed when it should differ from what it
  // is, and the charge already built up is kept, so Sandevistan starting or
  // ending mid-charge only changes the speed. With "Write a log" on, what was
  // seen is written once per hold and again whenever the slow-down changes.
  public final func UpdateChargeRate(weapon: wref<WeaponObject>, time: ref<TimeSystem>, source: String) -> Void {
    let mode: BluntLeapSandevistanCharge = this.Settings().sandevistanCharge;
    let modeName: String = "Vanilla";
    let index: Int32;
    let base: Float;
    let rate: Float;
    let dilation: Float;
    let report: String;
    let pools: ref<StatPoolsSystem>;
    let statsId: StatsObjectID;
    let regen: StatPoolModifier;
    if !IsDefined(weapon) || !IsDefined(time) {
      return;
    };
    index = this.ChargeIndex(weapon.GetEntityID());
    if index < 0 {
      return;
    };
    base = BluntLeapSystem.BaseChargeRate(weapon);
    if base <= 0.0 {
      return;
    };
    dilation = this.SandevistanDilation(time, report);
    rate = base;
    if Equals(mode, BluntLeapSandevistanCharge.Partial) {
      modeName = "Partial";
    };
    if Equals(mode, BluntLeapSandevistanCharge.Full) {
      modeName = "Full";
    };
    if dilation < 1.0 {
      if Equals(mode, BluntLeapSandevistanCharge.Full) {
        rate = base / dilation;
      };
      if Equals(mode, BluntLeapSandevistanCharge.Partial) {
        rate = base * (1.0 + dilation) / (2.0 * dilation);
      };
    };
    pools = GameInstance.GetStatPoolsSystem(weapon.GetGame());
    statsId = Cast<StatsObjectID>(weapon.GetEntityID());
    if this.Settings().debugLog && AbsF(dilation - this.m_loggedDilation) > 0.001 {
      pools.GetModifier(statsId, gamedataStatPoolType.WeaponCharge, gameStatPoolModificationTypes.Regeneration, regen);
      this.m_loggedDilation = dilation;
      this.Log("Charge (" + source + "): setting " + modeName + "; " + report + "; slow-down used " + FloatToStringPrec(dilation, 3) + "; rate base " + FloatToStringPrec(base, 1) + ", pool now " + FloatToStringPrec(regen.valuePerSec, 1) + (regen.enabled ? "" : " (not filling)") + ", wanted " + FloatToStringPrec(rate, 1));
    };
    if AbsF(rate - this.m_chargeRates[index]) < 0.01 {
      return;
    };
    if !this.OwnsChargeOf(weapon) {
      return;
    };
    pools.GetModifier(statsId, gamedataStatPoolType.WeaponCharge, gameStatPoolModificationTypes.Regeneration, regen);
    // Only while the game is filling it: turning filling on here could
    // leave a charge filling after the hold has ended.
    if !regen.enabled {
      if !this.m_loggedBlocked {
        this.m_loggedBlocked = true;
        this.Log("Charge (" + source + "): rate not changed, the pool is not filling");
      };
      return;
    };
    regen.valuePerSec = rate;
    pools.RequestSettingModifier(statsId, gamedataStatPoolType.WeaponCharge, gameStatPoolModificationTypes.Regeneration, regen);
    this.m_chargeRates[index] = rate;
    this.Log("Charge (" + source + "): rate set to " + FloatToStringPrec(rate, 1) + " per s");
  }

  // A leap has started: the attack at its end reaches at least the minimum
  // leap reach (setting, 3.0 m), and at least the weapon type's reach bonus
  // farther than the weapon's own reach (settings "Reach bonus", 0 by
  // default). A melee hit's box is as long as the weapon's Range stat
  // (MeleeAttackGenericEvents.CreateMeleeAttack). After a leap the game does
  // not move V towards the target again (the attack's move-to-target, the
  // other use of Range, is skipped when it follows a leap), so the bonus
  // only lengthens the punch. It is taken off when that attack ends, or when
  // the leap ends without one.
  public final func AddLeapReach(weapon: wref<WeaponObject>) -> Void {
    let stats: ref<StatsSystem>;
    let range: Float;
    let bonus: Float;
    this.RemoveLeapReach();
    if !IsDefined(weapon) {
      return;
    };
    // The weapon's own reach right now (its type's, or its own if the
    // weapon differs), then: at least the minimum, and at least the type's
    // bonus on top.
    stats = GameInstance.GetStatsSystem(weapon.GetGame());
    range = stats.GetStatValue(Cast<StatsObjectID>(weapon.GetEntityID()), gamedataStatType.Range);
    bonus = MaxF(this.LeapReachFor(WeaponObject.GetWeaponType(weapon.GetItemID())), this.Settings().leapMinReach - range);
    if bonus <= 0.0 {
      return;
    };
    this.m_reachMod = RPGManager.CreateStatModifier(gamedataStatType.Range, gameStatModifierType.Additive, bonus);
    this.m_reachId = weapon.GetEntityID();
    stats.AddModifier(Cast<StatsObjectID>(this.m_reachId), this.m_reachMod);
    this.Log("Leap reach " + FloatToStringPrec(range, 1) + " + " + FloatToStringPrec(bonus, 1) + " = " + FloatToStringPrec(range + bonus, 1) + " m");
  }

  // How long before landing the leap's strong attack starts (settings
  // "Swing start"). The game uses 0.3 s for every weapon.
  public final func SwingStartFor(type: gamedataItemType) -> Float {
    let settings: ref<BluntLeapSettings> = this.Settings();
    switch type {
      case gamedataItemType.Wea_Fists:
        return settings.fistLead;
      case gamedataItemType.Cyb_StrongArms:
        return settings.gorillaLead;
      case gamedataItemType.Wea_OneHandedClub:
        return settings.oneHandedLead;
      case gamedataItemType.Wea_TwoHandedClub:
        return settings.twoHandedLead;
      case gamedataItemType.Wea_Hammer:
        return settings.hammerLead;
    };
    return 0.3;
  }

  // Extra reach for the attack that ends a leap (settings "Reach bonus").
  public final func LeapReachFor(type: gamedataItemType) -> Float {
    let settings: ref<BluntLeapSettings> = this.Settings();
    switch type {
      case gamedataItemType.Wea_Fists:
        return settings.fistLeapReach;
      case gamedataItemType.Cyb_StrongArms:
        return settings.gorillaLeapReach;
      case gamedataItemType.Wea_OneHandedClub:
        return settings.oneHandedLeapReach;
      case gamedataItemType.Wea_TwoHandedClub:
        return settings.twoHandedLeapReach;
      case gamedataItemType.Wea_Hammer:
        return settings.hammerLeapReach;
    };
    return 0.0;
  }

  public final func RemoveLeapReach() -> Void {
    if !IsDefined(this.m_reachMod) {
      return;
    };
    GameInstance.GetStatsSystem(this.GetGameInstance()).RemoveModifier(Cast<StatsObjectID>(this.m_reachId), this.m_reachMod);
    this.m_reachMod = null;
  }

  // ------------------------------------------------- thrown NPCs and loot
  //
  // When a ragdoll starts while an NPC is alive, the game puts the status
  // effect NonInteractable on it (NPCPuppet.OnRagdollEnabledEvent). It has no
  // time limit and can stack. The game takes it off only when the NPC gets
  // up again (the AI task DoClearActiveStatusEffect, at the end of the
  // ragdoll recovery). An NPC this mod sends flying is alive when its ragdoll
  // starts; if it dies before getting up, the recovery never runs, the effect
  // stays, and the body and its loot show no prompt. So for the NPCs we
  // threw, every stack is taken off when they die or are knocked out.
  //
  // "Alive" there means not dead, and blunt weapons knock out instead of
  // killing: a knocked-out NPC counts as alive. When the throwing hit itself
  // knocks the NPC out (or it is knocked out while still lying from an
  // earlier throw), its ragdoll starts after it went down and puts the
  // effect back on, with no recovery to come. Seen in game 2026-11-24: two
  // bodies without a prompt, both thrown by the hit that took them down.
  // So the effect is also taken off when a ragdoll starts on a thrown NPC
  // that is already down. The game adds it a moment after the ragdoll
  // starts (it was not there yet when looked for right away: seen in game
  // 2026-11-24, a knocked-out body moved again over a minute later, and the
  // 1 s check took it off), so the body is checked again 0.1 s and 1 s later.

  public final func NoteThrown(id: EntityID) -> Void {
    if ArrayContains(this.m_thrownIds, id) {
      return;
    };
    if ArraySize(this.m_thrownIds) >= 64 {
      ArrayErase(this.m_thrownIds, 0);
    };
    ArrayPush(this.m_thrownIds, id);
  }

  // A thrown NPC is down (reason, for the log): take every stack of the
  // effect off (it can stack to 200; the removal takes effect a moment
  // later), and look again in a second. The NPC stays in the list, so a
  // ragdoll starting later is handled too.
  public final func ClearThrownBody(npc: ref<NPCPuppet>, reason: String) -> Void {
    let effect: TweakDBID = t"BaseStatusEffect.NonInteractable";
    let had: Bool;
    let check: ref<BluntLeapBodyCheckCallback>;
    if !IsDefined(npc) || !ArrayContains(this.m_thrownIds, npc.GetEntityID()) {
      return;
    };
    had = StatusEffectSystem.ObjectHasStatusEffect(npc, effect);
    if had {
      GameInstance.GetStatusEffectSystem(npc.GetGame()).RemoveStatusEffect(npc.GetEntityID(), effect, 200u);
    };
    this.Log("Thrown NPC #" + BluntLeapSystem.ShortId(npc.GetEntityID()) + " " + reason + ": " + (had ? "NonInteractable taken off" : "no NonInteractable on it"));
    check = new BluntLeapBodyCheckCallback();
    check.system = this;
    check.npc = npc;
    check.after = 0.1;
    GameInstance.GetDelaySystem(npc.GetGame()).DelayCallback(check, 0.1, false);
    check = new BluntLeapBodyCheckCallback();
    check.system = this;
    check.npc = npc;
    check.after = 1.0;
    GameInstance.GetDelaySystem(npc.GetGame()).DelayCallback(check, 1.0, false);
  }

  // 0.1 s and 1 s after a thrown NPC went down (after). If it is still down
  // and has the effect, it is taken off again. The log says so; the 1 s
  // check also says when the body is lootable.
  public final func RecheckThrownBody(npc: wref<NPCPuppet>, after: Float) -> Void {
    let effect: TweakDBID = t"BaseStatusEffect.NonInteractable";
    if !IsDefined(npc) || (!npc.IsIncapacitated() && ScriptedPuppet.IsActive(npc)) {
      return;
    };
    if StatusEffectSystem.ObjectHasStatusEffect(npc, effect) {
      GameInstance.GetStatusEffectSystem(npc.GetGame()).RemoveStatusEffect(npc.GetEntityID(), effect, 200u);
      this.Log("Thrown NPC #" + BluntLeapSystem.ShortId(npc.GetEntityID()) + " had NonInteractable " + FloatToStringPrec(after, 1) + " s after going down: taken off");
    } else {
      if after >= 1.0 {
        this.Log("Thrown NPC #" + BluntLeapSystem.ShortId(npc.GetEntityID()) + " " + FloatToStringPrec(after, 1) + " s after going down: no NonInteractable, lootable");
      };
    };
  }

  // The last 5 digits of an entity's hash, as the hit lines show them.
  public final static func ShortId(id: EntityID) -> String {
    return StrRight(ToString(EntityID.GetHash(id)), 5);
  }

  // ---------------------------------------------------- Gorilla Arms charge
  //
  // Gorilla Arms do not charge by holding: they have no ChargeTime, and their
  // WeaponCharge pool (StrongArmsCharge) belongs to the Phantom Liberty relic
  // perk, which fills it its own way and arms its relic punch when it is full.
  // So their charge for this mod is a timer instead of a pool, and the relic
  // perk's charge is never read or touched. A hold lasting the charge time
  // makes it full: the full-charge sound and rumble play, and a leap released
  // then counts as fully charged (Thunder Breaker). There is no bar: the
  // game's bar shows a pool.

  // A strong attack starts to be held.
  public final func StartGorillaCharge(weapon: wref<WeaponObject>) -> Void {
    let settings: ref<BluntLeapSettings> = this.Settings();
    let callback: ref<BluntLeapGorillaChargeCallback>;
    let time: ref<TimeSystem>;
    let needed: Float;
    let dilation: Float;
    let report: String;
    let affected: Bool;
    this.StopGorillaCharge();
    if !IsDefined(weapon) || NotEquals(WeaponObject.GetWeaponType(weapon.GetItemID()), gamedataItemType.Cyb_StrongArms) || !this.ChargeWanted() {
      return;
    };
    needed = MaxF(settings.chargeGorilla, 0.05);
    // Under Sandevistan, as the setting "Charge speed under Sandevistan" says:
    // Vanilla slows with world time; Full takes the same real time; Partial
    // is halfway between: real-time speed (1 + d) / 2 (see UpdateChargeRate).
    affected = Equals(settings.sandevistanCharge, BluntLeapSandevistanCharge.Vanilla);
    if Equals(settings.sandevistanCharge, BluntLeapSandevistanCharge.Partial) {
      time = GameInstance.GetTimeSystem(this.GetGameInstance());
      dilation = this.SandevistanDilation(time, report);
      if dilation < 1.0 {
        needed = needed * 2.0 / (1.0 + dilation);
      };
    };
    this.m_gorillaId = weapon.GetEntityID();
    this.m_gorillaActive = true;
    this.m_gorillaFull = false;
    callback = new BluntLeapGorillaChargeCallback();
    callback.system = this;
    callback.hold = this.m_gorillaHold;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(callback, needed, affected);
    this.Log("Gorilla Arms charge started, full in " + FloatToStringPrec(needed, 2) + " s");
  }

  public final func OnGorillaFull(hold: Int32) -> Void {
    if !this.m_gorillaActive || hold != this.m_gorillaHold {
      return;
    };
    this.m_gorillaFull = true;
    this.Log("Gorilla Arms fully charged");
    this.OnFullCharge();
  }

  // The hold ended (after the leap, if any, has read the charge), a weapon
  // was drawn, or a save was loaded.
  public final func StopGorillaCharge() -> Void {
    this.m_gorillaHold += 1;
    this.m_gorillaActive = false;
    this.m_gorillaFull = false;
  }

  // The charge a leap starts with, 0.0 to 1.0: the timed charge for Gorilla
  // Arms (full or nothing), the weapon's charge pool for everything else.
  public final func LeapCharge(weapon: wref<WeaponObject>) -> Float {
    if !IsDefined(weapon) {
      return 0.0;
    };
    if Equals(WeaponObject.GetWeaponType(weapon.GetItemID()), gamedataItemType.Cyb_StrongArms) {
      if this.m_gorillaActive && this.m_gorillaFull && this.m_gorillaId == weapon.GetEntityID() {
        return 1.0;
      };
      return 0.0;
    };
    return BluntLeapSystem.ChargeOf(weapon);
  }

  // A charge we added has just become full: sound and rumble. The bar's
  // flash is done by the crosshair itself (BluntLeap_Charge.reds).
  public final func OnFullCharge() -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    let settings: ref<BluntLeapSettings> = this.Settings();
    if !IsDefined(player) {
      return;
    };
    if settings.fullSound {
      // The game's "charged" cue of the Gorilla Arms relic attack.
      GameObject.PlaySoundEvent(player, n"w_cyb_strongarms_spy_perk_charge");
    };
    if settings.fullRumble {
      GameObject.PlaySound(player, TDB.GetCName(t"rumble.local.heavy_pulse"));
    };
  }
}
