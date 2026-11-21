// Blunt Leap: the system. Holds the settings, gives the player the leap
// ability (three small data packages from r6/tweaks/BluntLeap), and looks
// after the charge pool of the blunt weapon in hand.
//
// The leap itself is the game's own: MeleeLeapDecisions only asks for the
// CanMeleeLeap flag, which the vanilla perk grants while a blade is held.
// Our package grants it while a blunt weapon is held.

public class BluntLeapSystem extends ScriptableSystem {

  private let m_settings: ref<BluntLeapSettings>;

  // The one weapon that carries our charge pool: the one in hand. A weapon is
  // a new object each time it is drawn, so one slot is enough.
  private let m_chargeWeapon: EntityID;
  private let m_chargeTime: Float;
  private let m_chargeTimeMod: ref<gameStatModifierData>;
  private let m_chargeMaxMod: ref<gameStatModifierData>;

  public final static func Get(game: GameInstance) -> ref<BluntLeapSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"BluntLeapSystem") as BluntLeapSystem;
  }

  private func OnAttach() -> Void {
    this.Settings();
  }

  private func OnDetach() -> Void {
    if IsDefined(this.m_settings) {
      this.m_settings.Unregister();
    };
  }

  private final func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    this.Refresh();
  }

  public final func Settings() -> ref<BluntLeapSettings> {
    if !IsDefined(this.m_settings) {
      this.m_settings = new BluntLeapSettings();
      this.m_settings.system = this;
      this.m_settings.Register();
    };
    return this.m_settings;
  }

  // ------------------------------------------------------------ ability

  // Applies the settings to the player. Removes before it applies, so it is
  // safe to call any number of times (game load, settings change).
  public final func Refresh() -> Void {
    let game: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GetPlayer(game);
    if !IsDefined(player) {
      return;
    };
    let settings: ref<BluntLeapSettings> = this.Settings();
    let packages: ref<GameplayLogicPackageSystem> = GameInstance.GetGameplayLogicPackageSystem(game);

    packages.RemovePackage(player, t"BluntLeap.LeapAbility");
    packages.RemovePackage(player, t"BluntLeap.AirLeapAbility");
    packages.RemovePackage(player, t"BluntLeap.DistanceBonus");

    if !settings.enabled {
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
  }

  // Steps 2 and 3 will answer this from the Stronger leap perk and the unlock
  // rule. Until then nobody has it.
  public final func HasStrongerLeap() -> Bool {
    return false;
  }

  // ------------------------------------------------------------- charge

  // Blunt weapons charge only when the charge means something: in "Always
  // charged" mode, or once the stronger leap is available.
  public final func ChargeWanted() -> Bool {
    let settings: ref<BluntLeapSettings> = this.Settings();
    return settings.enabled && (settings.alwaysCharged || this.HasStrongerLeap());
  }

  // True if this weapon carries the charge pool we added (not one of its own).
  public final func OwnsChargeOf(weapon: wref<WeaponObject>) -> Bool {
    return IsDefined(weapon) && EntityID.IsDefined(this.m_chargeWeapon) && weapon.GetEntityID() == this.m_chargeWeapon;
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
    pools.RequestAddingStatPool(statsId, t"BluntLeap.ChargePool", true);
    this.m_chargeWeapon = id;
    this.m_chargeTime = time;
    return true;
  }

  // Takes our pool and stats off the weapon again.
  private final func ReleaseCharge(weapon: wref<WeaponObject>) -> Void {
    let statsId: StatsObjectID = Cast<StatsObjectID>(weapon.GetEntityID());
    let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(weapon.GetGame());
    GameInstance.GetStatPoolsSystem(weapon.GetGame()).RequestRemovingStatPool(statsId, gamedataStatPoolType.WeaponCharge);
    if IsDefined(this.m_chargeTimeMod) {
      stats.RemoveModifier(statsId, this.m_chargeTimeMod);
    };
    if IsDefined(this.m_chargeMaxMod) {
      stats.RemoveModifier(statsId, this.m_chargeMaxMod);
    };
    this.m_chargeTimeMod = null;
    this.m_chargeMaxMod = null;
    this.m_chargeTime = 0.0;
    this.m_chargeWeapon = new EntityID();
  }
}
