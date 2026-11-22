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

// Tells the system the moment a charge we added becomes full.
public class BluntLeapChargeListener extends ScriptStatPoolsListener {
  public let system: wref<BluntLeapSystem>;

  public func OnStatPoolValueChanged(oldValue: Float, newValue: Float, percToPoints: Float) -> Void {
    if newValue >= 99.9 && oldValue < 99.9 && IsDefined(this.system) {
      this.system.OnFullCharge();
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

  // The one weapon that carries our charge pool: the one in hand. A weapon is
  // a new object each time it is drawn, so one slot is enough.
  private let m_chargeWeapon: EntityID;
  private let m_chargeTime: Float;
  private let m_chargeTimeMod: ref<gameStatModifierData>;
  private let m_chargeMaxMod: ref<gameStatModifierData>;
  private let m_chargeBonusMod: ref<gameStatModifierData>;
  private let m_chargeListener: ref<BluntLeapChargeListener>;

  // A stronger leap is on its way: its hit gets the extra effects until this time.
  private let m_strongUntil: Float;
  private let m_empDone: Bool;
  private let m_hitStopDone: Bool;

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

    // The numbers shown in the two perks' descriptions follow the settings.
    TweakDBManager.SetFlat(t"NewPerks.BluntLeap_Leap_UI.floatValues", ToVariant([settings.distanceBonus]));
    TweakDBManager.UpdateRecord(t"NewPerks.BluntLeap_Leap_UI");
    TweakDBManager.SetFlat(t"NewPerks.BluntLeap_Stronger_UI.floatValues", ToVariant([settings.extraRange, settings.launchChance]));
    TweakDBManager.UpdateRecord(t"NewPerks.BluntLeap_Stronger_UI");

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

  // Blunt weapons charge only when the charge means something: in "Always
  // charged" mode, or once the stronger leap is available.
  public final func ChargeWanted() -> Bool {
    let settings: ref<BluntLeapSettings> = this.Settings();
    return this.m_hasLeap && (settings.alwaysCharged || this.m_hasStronger);
  }

  // True if this weapon carries the charge pool we added (not one of its own).
  public final func OwnsChargeOf(weapon: wref<WeaponObject>) -> Bool {
    return IsDefined(weapon) && this.OwnsChargeEntity(weapon.GetEntityID());
  }

  public final func OwnsChargeEntity(id: EntityID) -> Bool {
    return EntityID.IsDefined(this.m_chargeWeapon) && id == this.m_chargeWeapon;
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

  // Gives the blunt weapon in hand a charge pool and a charge time, unless it
  // has its own (stun batons, Gorilla Arms). Returns true if the weapon's
  // charge is ours. Called when the weapon's crosshair appears and again when
  // a strong attack starts to be held.
  public final func PrepareCharge(weapon: wref<WeaponObject>) -> Bool {
    if !IsDefined(weapon) {
      return false;
    };
    let game: GameInstance = weapon.GetGame();
    let id: EntityID = weapon.GetEntityID();
    let statsId: StatsObjectID = Cast<StatsObjectID>(id);
    let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(game);
    let pools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(game);
    let settings: ref<BluntLeapSettings> = this.Settings();
    let time: Float;

    if this.OwnsChargeOf(weapon) {
      if !this.ChargeWanted() {
        this.ReleaseCharge(weapon);
        return false;
      };
      // Follow a changed charge-time setting.
      time = this.ChargeTimeFor(weapon);
      if AbsF(time - this.m_chargeTime) > 0.001 {
        stats.RemoveModifier(statsId, this.m_chargeTimeMod);
        this.m_chargeTimeMod = RPGManager.CreateStatModifier(gamedataStatType.ChargeTime, gameStatModifierType.Additive, time);
        stats.AddModifier(statsId, this.m_chargeTimeMod);
        this.m_chargeTime = time;
      };
      return true;
    };

    if !this.ChargeWanted() || !WeaponObject.IsBlunt(weapon.GetItemID()) {
      return false;
    };
    // A weapon with its own charge keeps it untouched.
    if pools.IsStatPoolAdded(statsId, gamedataStatPoolType.WeaponCharge) || stats.GetStatValue(statsId, gamedataStatType.ChargeTime) > 0.0 {
      return false;
    };

    time = this.ChargeTimeFor(weapon);
    this.m_chargeTimeMod = RPGManager.CreateStatModifier(gamedataStatType.ChargeTime, gameStatModifierType.Additive, time);
    stats.AddModifier(statsId, this.m_chargeTimeMod);
    this.m_chargeMaxMod = null;
    if stats.GetStatValue(statsId, gamedataStatType.Charge) <= 0.0 {
      // The pool's size comes from this stat; charged weapons have 100.
      this.m_chargeMaxMod = RPGManager.CreateStatModifier(gamedataStatType.Charge, gameStatModifierType.Additive, 100.0);
      stats.AddModifier(statsId, this.m_chargeMaxMod);
    };
    // The game's charged-attack bonus is a third of the charge multiplier
    // (0.25 on melee weapons, so +33% at full charge). Scale it to the setting.
    this.m_chargeBonusMod = null;
    if AbsF(settings.chargeBonus - 33.0) > 0.5 {
      this.m_chargeBonusMod = RPGManager.CreateStatModifier(gamedataStatType.ChargeMultiplier, gameStatModifierType.Multiplier, settings.chargeBonus / 33.25);
      stats.AddModifier(statsId, this.m_chargeBonusMod);
    };
    pools.RequestAddingStatPool(statsId, t"BluntLeap.ChargePool", true);
    this.m_chargeListener = new BluntLeapChargeListener();
    this.m_chargeListener.system = this;
    pools.RequestRegisteringListener(statsId, gamedataStatPoolType.WeaponCharge, this.m_chargeListener);
    this.m_chargeWeapon = id;
    this.m_chargeTime = time;
    this.Log("Charge added to the weapon in hand, time " + FloatToStringPrec(time, 2) + " s");
    return true;
  }

  // Takes our pool and stats off the weapon again.
  private final func ReleaseCharge(weapon: wref<WeaponObject>) -> Void {
    let statsId: StatsObjectID = Cast<StatsObjectID>(weapon.GetEntityID());
    let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(weapon.GetGame());
    let pools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(weapon.GetGame());
    if IsDefined(this.m_chargeListener) {
      pools.RequestUnregisteringListener(statsId, gamedataStatPoolType.WeaponCharge, this.m_chargeListener);
    };
    pools.RequestRemovingStatPool(statsId, gamedataStatPoolType.WeaponCharge);
    if IsDefined(this.m_chargeTimeMod) {
      stats.RemoveModifier(statsId, this.m_chargeTimeMod);
    };
    if IsDefined(this.m_chargeMaxMod) {
      stats.RemoveModifier(statsId, this.m_chargeMaxMod);
    };
    if IsDefined(this.m_chargeBonusMod) {
      stats.RemoveModifier(statsId, this.m_chargeBonusMod);
    };
    this.m_chargeListener = null;
    this.m_chargeTimeMod = null;
    this.m_chargeMaxMod = null;
    this.m_chargeBonusMod = null;
    this.m_chargeTime = 0.0;
    this.m_chargeWeapon = new EntityID();
  }

  // The charge we added has just become full: sound and rumble. The bar's
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
