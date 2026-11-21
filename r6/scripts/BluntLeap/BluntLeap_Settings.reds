// Blunt Leap: settings. Shown in Mod Settings when it is installed; without
// it the defaults below are used.

public class BluntLeapSettings extends IScriptable {

  // Set by BluntLeapSystem, so a change in the menu can be applied at once.
  public let system: wref<BluntLeapSystem>;

  // ------------------------------------------------------------- general

  @runtimeProperty("ModSettings.mod", "Blunt Leap")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Enabled")
  @runtimeProperty("ModSettings.description", "Master switch. Off leaves blunt weapons fully vanilla.")
  public let enabled: Bool = true;

  // ---------------------------------------------------------------- leap

  @runtimeProperty("ModSettings.mod", "Blunt Leap")
  @runtimeProperty("ModSettings.category", "Leap")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "Leap range (m)")
  @runtimeProperty("ModSettings.description", "How far away an enemy can be for the leap. 15 is the blade leap's range, and the most the game's leap supports for now.")
  @runtimeProperty("ModSettings.step", "0.5")
  @runtimeProperty("ModSettings.min", "5.0")
  @runtimeProperty("ModSettings.max", "15.0")
  public let leapRange: Float = 15.0;

  @runtimeProperty("ModSettings.mod", "Blunt Leap")
  @runtimeProperty("ModSettings.category", "Leap")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "Leap in mid-air")
  @runtimeProperty("ModSettings.description", "On: you can start a leap while jumping or falling, as with blades.")
  public let airLeap: Bool = true;

  @runtimeProperty("ModSettings.mod", "Blunt Leap")
  @runtimeProperty("ModSettings.category", "Leap")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "Distance damage bonus (%)")
  @runtimeProperty("ModSettings.description", "Extra damage for the leap's hit, growing with the distance leaped and reaching this value at 20 m. 50 is the blade leap's value. 0 turns it off.")
  @runtimeProperty("ModSettings.step", "5.0")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "100.0")
  public let distanceBonus: Float = 50.0;

  @runtimeProperty("ModSettings.mod", "Blunt Leap")
  @runtimeProperty("ModSettings.category", "Leap")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "Hammer swing start (s)")
  @runtimeProperty("ModSettings.description", "How long before landing a hammer starts its swing. Hammers swing slower than other weapons, so they start earlier to hit on arrival. Other weapons use the game's 0.3.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.3")
  @runtimeProperty("ModSettings.max", "0.7")
  public let hammerLead: Float = 0.5;

  // -------------------------------------------------------------- charge

  @runtimeProperty("ModSettings.mod", "Blunt Leap")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.displayName", "Always charged")
  @runtimeProperty("ModSettings.description", "Off: any held strong attack leaps, as with blades. On: only a fully charged one leaps; a partly charged one is a normal strong attack. Applies the next time you draw the weapon.")
  public let alwaysCharged: Bool = false;

  @runtimeProperty("ModSettings.mod", "Blunt Leap")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.displayName", "Charge bar")
  @runtimeProperty("ModSettings.description", "Show the game's melee charge bar at the crosshair while a blunt weapon charges. Applies the next time you draw the weapon.")
  public let chargeBar: Bool = true;

  @runtimeProperty("ModSettings.mod", "Blunt Leap")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.displayName", "Charge time: fists (s)")
  @runtimeProperty("ModSettings.description", "Time to a full charge. Stun batons and Gorilla Arms keep their own charge.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.2")
  @runtimeProperty("ModSettings.max", "3.0")
  public let chargeFists: Float = 0.5;

  @runtimeProperty("ModSettings.mod", "Blunt Leap")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.displayName", "Charge time: one-handed (s)")
  @runtimeProperty("ModSettings.description", "Time to a full charge for one-handed blunt weapons.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.2")
  @runtimeProperty("ModSettings.max", "3.0")
  public let chargeOneHanded: Float = 0.75;

  @runtimeProperty("ModSettings.mod", "Blunt Leap")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.displayName", "Charge time: two-handed (s)")
  @runtimeProperty("ModSettings.description", "Time to a full charge for two-handed blunt weapons such as bats.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.2")
  @runtimeProperty("ModSettings.max", "3.0")
  public let chargeTwoHanded: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Blunt Leap")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.displayName", "Charge time: hammer (s)")
  @runtimeProperty("ModSettings.description", "Time to a full charge for hammers.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.2")
  @runtimeProperty("ModSettings.max", "3.0")
  public let chargeHammer: Float = 1.2;

  // --------------------------------------------------------- registration

  public final func Register() -> Void {
    this.RegisterWithModSettings();
  }

  public final func Unregister() -> Void {
    this.UnregisterFromModSettings();
  }

  // Called by Mod Settings after the player accepts changes in its menu.
  public cb func OnModSettingsChange() -> Void {
    if IsDefined(this.system) {
      this.system.Refresh();
    };
  }

  @if(ModuleExists("ModSettingsModule"))
  private final func RegisterWithModSettings() -> Void {
    ModSettings.RegisterListenerToClass(this);
    ModSettings.RegisterListenerToModifications(this);
  }

  @if(!ModuleExists("ModSettingsModule"))
  private final func RegisterWithModSettings() -> Void {}

  @if(ModuleExists("ModSettingsModule"))
  private final func UnregisterFromModSettings() -> Void {
    ModSettings.UnregisterListenerToModifications(this);
    ModSettings.UnregisterListenerToClass(this);
  }

  @if(!ModuleExists("ModSettingsModule"))
  private final func UnregisterFromModSettings() -> Void {}
}
