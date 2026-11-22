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

  // A stronger leap is on its way: its hit gets the extra effects until this time.
  private let m_strongUntil: Float;
  private let m_empDone: Bool;
  private let m_hitStopDone: Bool;

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
    this.Log("Stronger leap started");
  }

  public final func DisarmStrongLeap() -> Void {
    this.m_strongUntil = 0.0;
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
  // clears the player's pool instead of the weapon's, and turns the slow
  // fallback decay off whenever a charge starts.
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
    if !IsDefined(weapon) {
      return;
    };
    index = this.ChargeIndex(weapon.GetEntityID());
    if index >= 0 {
      this.m_chargeRates[index] = BluntLeapSystem.BaseChargeRate(weapon);
    };
    this.m_loggedDilation = -1.0;
    this.m_loggedBlocked = false;
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
  //   Partial: as the game does for gun fire rate (CalcCycleTimeDeltaFactor):
  //            1 / slow-down, times 0.5 to 0.9 by the charge time;
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
    if NotEquals(mode, BluntLeapSandevistanCharge.Vanilla) && dilation < 1.0 {
      rate = base / dilation;
      if Equals(mode, BluntLeapSandevistanCharge.Partial) {
        rate *= ProportionalClampF(1.0, 2.0, 100.0 / base, 0.5, 0.9);
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
