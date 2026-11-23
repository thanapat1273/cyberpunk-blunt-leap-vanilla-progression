// Blunt Leap: settings. Shown in Mod Settings when it is installed; without
// it the defaults below are used.

// How the leap is unlocked.
enum BluntLeapUnlockRule {
  DashAndPerks = 0,   // the two perks; the first also needs Dash
  PerksOnly = 1,      // the two perks, no Dash
  AlwaysBoth = 2,     // no perks: Battering Ram and Thunder Breaker, always
  AlwaysLeap = 3      // no perks: Battering Ram only, always
}

// How fast our charge fills while Sandevistan slows time.
enum BluntLeapSandevistanCharge {
  Vanilla = 0,   // slows with time, like every melee charge in the game
  Partial = 1,   // halfway between Vanilla and Full
  Full = 2       // the same real time as without Sandevistan
}

public class BluntLeapSettings extends IScriptable {

  // Set by BluntLeapSystem, so a change in the menu can be applied at once.
  public let system: wref<BluntLeapSystem>;

  // The options, in the order and groups Mod Settings shows them (2026-11-24
  // layout, D76). Variable names never change: Mod Settings saves the values
  // under them. ModSettings.dependency hides an option while the named switch
  // is off.

  // ---- General

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.order", "1")
  @runtimeProperty("ModSettings.displayName", "Enabled")
  @runtimeProperty("ModSettings.description", "Master switch. Off leaves blunt weapons fully vanilla.")
  public let enabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.order", "2")
  @runtimeProperty("ModSettings.displayName", "Unlock rule")
  @runtimeProperty("ModSettings.description", "How Battering Ram and Thunder Breaker are unlocked. Applies the next time you load a save. Points spent on a perk that is no longer needed, or no longer allowed, are refunded.")
  @runtimeProperty("ModSettings.displayValues.DashAndPerks", "Perks; Battering Ram needs Dash")
  @runtimeProperty("ModSettings.displayValues.PerksOnly", "Perks, no Dash needed")
  @runtimeProperty("ModSettings.displayValues.AlwaysBoth", "No perks: Battering Ram and Thunder Breaker")
  @runtimeProperty("ModSettings.displayValues.AlwaysLeap", "No perks: Battering Ram only")
  public let unlockRule: BluntLeapUnlockRule = BluntLeapUnlockRule.DashAndPerks;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.order", "3")
  @runtimeProperty("ModSettings.displayName", "Dash box on the perk screen")
  @runtimeProperty("ModSettings.description", "When Battering Ram needs Dash: On shows a small Dash box under it, joined by a wire, with its own tooltip. Off shows only the lock and the line in Battering Ram's tooltip.")
  public let dashMarker: Bool = true;

  // ---- Features

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Features")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.order", "4")
  @runtimeProperty("ModSettings.displayName", "Leap in mid-air")
  @runtimeProperty("ModSettings.description", "Start a leap while jumping or falling, as with blades.")
  public let airLeap: Bool = true;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Features")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.order", "5")
  @runtimeProperty("ModSettings.displayName", "Leap only when fully charged")
  @runtimeProperty("ModSettings.description", "Off: any held strong attack leaps, as with blades. On: only a fully charged one leaps; with less charge it is a normal strong attack, and blunt weapons charge even without Thunder Breaker. Applies the next time you draw the weapon.")
  public let alwaysCharged: Bool = false;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Features")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.order", "6")
  @runtimeProperty("ModSettings.displayName", "Charge bar")
  @runtimeProperty("ModSettings.description", "Show the game's melee charge bar at the crosshair while a blunt weapon charges. Gorilla Arms have none: their full charge is told by sound and rumble. Applies the next time you draw the weapon.")
  public let chargeBar: Bool = true;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Features")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.order", "7")
  @runtimeProperty("ModSettings.displayName", "EMP on a crit")
  @runtimeProperty("ModSettings.description", "Thunder Breaker: a fully charged leap that crits sets off an EMP burst at the enemy. It never hurts you. Radius and damage: Thunder Breaker: EMP.")
  public let emp: Bool = true;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Features")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.order", "8")
  @runtimeProperty("ModSettings.displayName", "Send flying")
  @runtimeProperty("ModSettings.description", "Thunder Breaker: a fully charged leap can throw the enemies it hits. Chances and force: Thunder Breaker: Send flying. Off: no throws.")
  public let sendFlying: Bool = true;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Features")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.order", "9")
  @runtimeProperty("ModSettings.displayName", "Stagger when not sent flying")
  @runtimeProperty("ModSettings.description", "Thunder Breaker: an enemy the leap hits and does not send flying is at least staggered, unless it resists staggers. This includes enemies hurt by the EMP.")
  public let stagger: Bool = true;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Features")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.order", "10")
  @runtimeProperty("ModSettings.displayName", "Push follows the swing direction")
  @runtimeProperty("ModSettings.description", "On: a thrown enemy flies the way the weapon swings (sideways, down or up). Off: straight away from you.")
  public let swingPush: Bool = true;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Features")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.order", "11")
  @runtimeProperty("ModSettings.displayName", "Non-lethal throws")
  @runtimeProperty("ModSettings.description", "On: an enemy you send flying that hits a wall or the ground hard is knocked out instead of killed, as blunt weapons knock out. Off: a hard impact can kill, as in the game. Your own hits are not changed.")
  public let nonLethalThrows: Bool = false;

  // ---- Battering Ram: Leap

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Battering Ram: Leap")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.order", "12")
  @runtimeProperty("ModSettings.displayName", "Leap range (m)")
  @runtimeProperty("ModSettings.description", "How far away an enemy can be for the leap. 15 is the blade leap's range. Thunder Breaker adds its own extra range on top.")
  @runtimeProperty("ModSettings.step", "0.5")
  @runtimeProperty("ModSettings.min", "5.0")
  @runtimeProperty("ModSettings.max", "15.0")
  public let leapRange: Float = 15.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Battering Ram: Leap")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.order", "13")
  @runtimeProperty("ModSettings.displayName", "Distance damage bonus (%)")
  @runtimeProperty("ModSettings.description", "Extra damage for the leap's hit, growing with the distance leaped and reaching this value at 20 m. 50 is the blade leap's value. 0 turns it off.")
  @runtimeProperty("ModSettings.step", "5.0")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "100.0")
  public let distanceBonus: Float = 50.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Battering Ram: Leap")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.order", "14")
  @runtimeProperty("ModSettings.displayName", "Minimum leap reach (m)")
  @runtimeProperty("ModSettings.description", "The attack that ends a leap reaches at least this far, whatever the weapon (fists reach 1.5 m in the game, a katana 3.0 m). Only that one attack; normal attacks are unchanged. 0 turns it off. Per-weapon bonuses: Advanced.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "4.0")
  public let leapMinReach: Float = 3.0;

  // ---- Charge

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.order", "15")
  @runtimeProperty("ModSettings.displayName", "Full-charge damage bonus (%)")
  @runtimeProperty("ModSettings.description", "Extra damage for a fully charged strong attack with a blunt weapon charged by this mod; a partial charge gives a share of it. 33 is what the game gives its own charged melee weapons. Applies the next time you draw the weapon.")
  @runtimeProperty("ModSettings.step", "1.0")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "100.0")
  public let chargeBonus: Float = 33.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.order", "16")
  @runtimeProperty("ModSettings.displayName", "Charge speed under Sandevistan")
  @runtimeProperty("ModSettings.description", "Vanilla: the charge slows with time, like every melee charge in the game. Partial: halfway between Vanilla and Full. Full: same real-time charge as normal.")
  @runtimeProperty("ModSettings.displayValues.Vanilla", "Vanilla")
  @runtimeProperty("ModSettings.displayValues.Partial", "Partial")
  @runtimeProperty("ModSettings.displayValues.Full", "Full")
  public let sandevistanCharge: BluntLeapSandevistanCharge = BluntLeapSandevistanCharge.Full;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.order", "17")
  @runtimeProperty("ModSettings.displayName", "Charge time: fists (s)")
  @runtimeProperty("ModSettings.description", "Time to a full charge with fists.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.2")
  @runtimeProperty("ModSettings.max", "3.0")
  public let chargeFists: Float = 0.5;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.order", "18")
  @runtimeProperty("ModSettings.displayName", "Charge time: Gorilla Arms (s)")
  @runtimeProperty("ModSettings.description", "Time to a full charge with Gorilla Arms. Their charge is kept by this mod, apart from the relic perk's charge, which it never touches.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.2")
  @runtimeProperty("ModSettings.max", "3.0")
  public let chargeGorilla: Float = 0.75;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.order", "19")
  @runtimeProperty("ModSettings.displayName", "Charge time: one-handed (s)")
  @runtimeProperty("ModSettings.description", "Time to a full charge with one-handed blunt weapons. Stun batons keep their own charge.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.2")
  @runtimeProperty("ModSettings.max", "3.0")
  public let chargeOneHanded: Float = 0.75;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.order", "20")
  @runtimeProperty("ModSettings.displayName", "Charge time: two-handed (s)")
  @runtimeProperty("ModSettings.description", "Time to a full charge with two-handed blunt weapons such as bats.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.2")
  @runtimeProperty("ModSettings.max", "3.0")
  public let chargeTwoHanded: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.order", "21")
  @runtimeProperty("ModSettings.displayName", "Charge time: hammers (s)")
  @runtimeProperty("ModSettings.description", "Time to a full charge with hammers.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.2")
  @runtimeProperty("ModSettings.max", "3.0")
  public let chargeHammer: Float = 1.2;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.order", "22")
  @runtimeProperty("ModSettings.displayName", "Full charge: sound")
  @runtimeProperty("ModSettings.description", "A short sound when the charge is full.")
  public let fullSound: Bool = true;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.order", "23")
  @runtimeProperty("ModSettings.displayName", "Full charge: rumble")
  @runtimeProperty("ModSettings.description", "One controller rumble pulse when the charge is full.")
  public let fullRumble: Bool = true;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Charge")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.order", "24")
  @runtimeProperty("ModSettings.displayName", "Full charge: bar flash")
  @runtimeProperty("ModSettings.description", "The charge bar pulses once when the charge is full.")
  @runtimeProperty("ModSettings.dependency", "chargeBar")
  public let fullFlash: Bool = true;

  // ---- Thunder Breaker

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Thunder Breaker")
  @runtimeProperty("ModSettings.category.order", "5")
  @runtimeProperty("ModSettings.order", "25")
  @runtimeProperty("ModSettings.displayName", "Extra range (%)")
  @runtimeProperty("ModSettings.description", "A fully charged leap reaches this much further than the leap range. The travel time keeps its cap, so longer leaps are faster.")
  @runtimeProperty("ModSettings.step", "5.0")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "100.0")
  public let extraRange: Float = 50.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Thunder Breaker")
  @runtimeProperty("ModSettings.category.order", "5")
  @runtimeProperty("ModSettings.order", "26")
  @runtimeProperty("ModSettings.displayName", "Hit stop (s)")
  @runtimeProperty("ModSettings.description", "A very short slow-motion beat when a fully charged leap lands. 0 turns it off.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "0.3")
  public let hitStop: Float = 0.15;

  // ---- Thunder Breaker: Send flying

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Thunder Breaker: Send flying")
  @runtimeProperty("ModSettings.category.order", "6")
  @runtimeProperty("ModSettings.order", "27")
  @runtimeProperty("ModSettings.displayName", "Chance, in combat (%)")
  @runtimeProperty("ModSettings.description", "Chance that a fully charged leap sends an enemy already in combat flying. Bosses, MaxTac, very large enemies and enemies the game says cannot be knocked down are never sent flying.")
  @runtimeProperty("ModSettings.dependency", "sendFlying")
  @runtimeProperty("ModSettings.step", "5.0")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "100.0")
  public let launchChance: Float = 80.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Thunder Breaker: Send flying")
  @runtimeProperty("ModSettings.category.order", "6")
  @runtimeProperty("ModSettings.order", "28")
  @runtimeProperty("ModSettings.displayName", "Chance on heavy enemies, in combat (%)")
  @runtimeProperty("ModSettings.description", "The same chance against the game's heavy enemy types.")
  @runtimeProperty("ModSettings.dependency", "sendFlying")
  @runtimeProperty("ModSettings.step", "5.0")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "100.0")
  public let launchChanceHeavy: Float = 30.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Thunder Breaker: Send flying")
  @runtimeProperty("ModSettings.category.order", "6")
  @runtimeProperty("ModSettings.order", "29")
  @runtimeProperty("ModSettings.displayName", "Force, in combat (%)")
  @runtimeProperty("ModSettings.description", "How hard the enemy is thrown. 20 keeps it believable; 100 matches the Gorilla Arms knockout punch, which throws enemies very far.")
  @runtimeProperty("ModSettings.dependency", "sendFlying")
  @runtimeProperty("ModSettings.step", "5.0")
  @runtimeProperty("ModSettings.min", "5.0")
  @runtimeProperty("ModSettings.max", "300.0")
  public let launchForce: Float = 20.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Thunder Breaker: Send flying")
  @runtimeProperty("ModSettings.category.order", "6")
  @runtimeProperty("ModSettings.order", "30")
  @runtimeProperty("ModSettings.displayName", "Chance, unalerted (%)")
  @runtimeProperty("ModSettings.description", "The same chance for an enemy that is not in combat yet (the first strike on an unaware group).")
  @runtimeProperty("ModSettings.dependency", "sendFlying")
  @runtimeProperty("ModSettings.step", "5.0")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "100.0")
  public let unalertedChance: Float = 80.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Thunder Breaker: Send flying")
  @runtimeProperty("ModSettings.category.order", "6")
  @runtimeProperty("ModSettings.order", "31")
  @runtimeProperty("ModSettings.displayName", "Chance on heavy enemies, unalerted (%)")
  @runtimeProperty("ModSettings.description", "The same chance against heavy enemy types that are not in combat yet.")
  @runtimeProperty("ModSettings.dependency", "sendFlying")
  @runtimeProperty("ModSettings.step", "5.0")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "100.0")
  public let unalertedChanceHeavy: Float = 30.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Thunder Breaker: Send flying")
  @runtimeProperty("ModSettings.category.order", "6")
  @runtimeProperty("ModSettings.order", "32")
  @runtimeProperty("ModSettings.displayName", "Force, unalerted (%)")
  @runtimeProperty("ModSettings.description", "How hard an enemy that is not in combat yet is thrown.")
  @runtimeProperty("ModSettings.dependency", "sendFlying")
  @runtimeProperty("ModSettings.step", "5.0")
  @runtimeProperty("ModSettings.min", "5.0")
  @runtimeProperty("ModSettings.max", "300.0")
  public let unalertedForce: Float = 20.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Thunder Breaker: Send flying")
  @runtimeProperty("ModSettings.category.order", "6")
  @runtimeProperty("ModSettings.order", "33")
  @runtimeProperty("ModSettings.displayName", "Small push at an idle spot: force (%)")
  @runtimeProperty("ModSettings.description", "An enemy at an idle spot (leaning on a wall, sitting, smoking, chatting, at a terminal) shows no stagger when hit: the game plays only a twitch. So instead of a stagger it gets a very small throw, at this force (sending flying uses 20). 0: no push.")
  @runtimeProperty("ModSettings.dependency", "stagger")
  @runtimeProperty("ModSettings.step", "1.0")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "50.0")
  public let unalertedStaggerForce: Float = 6.0;

  // ---- Thunder Breaker: EMP

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Thunder Breaker: EMP")
  @runtimeProperty("ModSettings.category.order", "7")
  @runtimeProperty("ModSettings.order", "34")
  @runtimeProperty("ModSettings.displayName", "Radius (m)")
  @runtimeProperty("ModSettings.description", "How far the EMP burst reaches.")
  @runtimeProperty("ModSettings.dependency", "emp")
  @runtimeProperty("ModSettings.step", "0.5")
  @runtimeProperty("ModSettings.min", "1.0")
  @runtimeProperty("ModSettings.max", "6.0")
  public let empRadius: Float = 3.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Thunder Breaker: EMP")
  @runtimeProperty("ModSettings.category.order", "7")
  @runtimeProperty("ModSettings.order", "35")
  @runtimeProperty("ModSettings.displayName", "Damage (% of the weapon's hit)")
  @runtimeProperty("ModSettings.description", "The burst's Electrical damage, as a share of the weapon's own damage per hit. It is not raised by the crit, the charge or the distance.")
  @runtimeProperty("ModSettings.dependency", "emp")
  @runtimeProperty("ModSettings.step", "10.0")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "300.0")
  public let empDamage: Float = 100.0;

  // ---- Advanced: swing and reach per weapon

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Advanced: swing and reach per weapon")
  @runtimeProperty("ModSettings.category.order", "8")
  @runtimeProperty("ModSettings.order", "36")
  @runtimeProperty("ModSettings.displayName", "Swing start: fists (s)")
  @runtimeProperty("ModSettings.description", "How long before landing the leap's strong attack starts. Fists hit 0.19 s after the attack starts, so a swing start a little above that lands the hit as V arrives. The game uses 0.3 for every weapon. Lower it if the hit lands short; raise it if it lands late.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.1")
  @runtimeProperty("ModSettings.max", "0.7")
  public let fistLead: Float = 0.21;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Advanced: swing and reach per weapon")
  @runtimeProperty("ModSettings.category.order", "8")
  @runtimeProperty("ModSettings.order", "37")
  @runtimeProperty("ModSettings.displayName", "Swing start: Gorilla Arms (s)")
  @runtimeProperty("ModSettings.description", "How long before landing the leap's strong attack starts. Gorilla Arms hit 0.19 s after the attack starts, so a swing start a little above that lands the hit as V arrives. The game uses 0.3 for every weapon. Lower it if the hit lands short; raise it if it lands late.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.1")
  @runtimeProperty("ModSettings.max", "0.7")
  public let gorillaLead: Float = 0.21;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Advanced: swing and reach per weapon")
  @runtimeProperty("ModSettings.category.order", "8")
  @runtimeProperty("ModSettings.order", "38")
  @runtimeProperty("ModSettings.displayName", "Swing start: one-handed (s)")
  @runtimeProperty("ModSettings.description", "How long before landing the leap's strong attack starts. One-handed blunt weapons hit 0.29 s after the attack starts (stun batons 0.31 s), so a swing start a little above that lands the hit as V arrives. The game uses 0.3 for every weapon. Lower it if the hit lands short; raise it if it lands late.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.1")
  @runtimeProperty("ModSettings.max", "0.7")
  public let oneHandedLead: Float = 0.3;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Advanced: swing and reach per weapon")
  @runtimeProperty("ModSettings.category.order", "8")
  @runtimeProperty("ModSettings.order", "39")
  @runtimeProperty("ModSettings.displayName", "Swing start: two-handed (s)")
  @runtimeProperty("ModSettings.description", "How long before landing the leap's strong attack starts. Two-handed blunt weapons hit 0.29 s after the attack starts, so a swing start a little above that lands the hit as V arrives. The game uses 0.3 for every weapon. Lower it if the hit lands short; raise it if it lands late.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.1")
  @runtimeProperty("ModSettings.max", "0.7")
  public let twoHandedLead: Float = 0.3;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Advanced: swing and reach per weapon")
  @runtimeProperty("ModSettings.category.order", "8")
  @runtimeProperty("ModSettings.order", "40")
  @runtimeProperty("ModSettings.displayName", "Swing start: hammers (s)")
  @runtimeProperty("ModSettings.description", "How long before landing the leap's strong attack starts. Hammers hit 0.5 s after the attack starts, so a swing start a little above that lands the hit as V arrives. The game uses 0.3 for every weapon. Lower it if the hit lands short; raise it if it lands late.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.1")
  @runtimeProperty("ModSettings.max", "0.7")
  public let hammerLead: Float = 0.5;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Advanced: swing and reach per weapon")
  @runtimeProperty("ModSettings.category.order", "8")
  @runtimeProperty("ModSettings.order", "41")
  @runtimeProperty("ModSettings.displayName", "Reach bonus: fists (m)")
  @runtimeProperty("ModSettings.description", "Extra reach for the attack that ends a leap, added to the weapon's own. Fists reach 1.5 m in the game. The attack also always reaches at least the minimum leap reach. Only that one attack; normal attacks are unchanged.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "2.0")
  public let fistLeapReach: Float = 0.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Advanced: swing and reach per weapon")
  @runtimeProperty("ModSettings.category.order", "8")
  @runtimeProperty("ModSettings.order", "42")
  @runtimeProperty("ModSettings.displayName", "Reach bonus: Gorilla Arms (m)")
  @runtimeProperty("ModSettings.description", "Extra reach for the attack that ends a leap, added to the weapon's own. Gorilla Arms reach 1.5 m in the game. The attack also always reaches at least the minimum leap reach. Only that one attack; normal attacks are unchanged.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "2.0")
  public let gorillaLeapReach: Float = 0.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Advanced: swing and reach per weapon")
  @runtimeProperty("ModSettings.category.order", "8")
  @runtimeProperty("ModSettings.order", "43")
  @runtimeProperty("ModSettings.displayName", "Reach bonus: one-handed (m)")
  @runtimeProperty("ModSettings.description", "Extra reach for the attack that ends a leap, added to the weapon's own. One-handed blunt weapons reach 2.0 m in the game, stun batons 4.0 m. The attack also always reaches at least the minimum leap reach. Only that one attack; normal attacks are unchanged.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "2.0")
  public let oneHandedLeapReach: Float = 0.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Advanced: swing and reach per weapon")
  @runtimeProperty("ModSettings.category.order", "8")
  @runtimeProperty("ModSettings.order", "44")
  @runtimeProperty("ModSettings.displayName", "Reach bonus: two-handed (m)")
  @runtimeProperty("ModSettings.description", "Extra reach for the attack that ends a leap, added to the weapon's own. Two-handed blunt weapons reach 2.5 m in the game. The attack also always reaches at least the minimum leap reach. Only that one attack; normal attacks are unchanged.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "2.0")
  public let twoHandedLeapReach: Float = 0.0;

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Advanced: swing and reach per weapon")
  @runtimeProperty("ModSettings.category.order", "8")
  @runtimeProperty("ModSettings.order", "45")
  @runtimeProperty("ModSettings.displayName", "Reach bonus: hammers (m)")
  @runtimeProperty("ModSettings.description", "Extra reach for the attack that ends a leap, added to the weapon's own. Hammers reach 2.0 m in the game. The attack also always reaches at least the minimum leap reach. Only that one attack; normal attacks are unchanged.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "2.0")
  public let hammerLeapReach: Float = 0.0;

  // ---- Troubleshooting

  @runtimeProperty("ModSettings.mod", "Battering Ram")
  @runtimeProperty("ModSettings.category", "Troubleshooting")
  @runtimeProperty("ModSettings.category.order", "9")
  @runtimeProperty("ModSettings.order", "46")
  @runtimeProperty("ModSettings.displayName", "Write a log")
  @runtimeProperty("ModSettings.description", "Writes what the mod decides (leaps, charge, throws, bodies, refunds) to the game's log, for bug reports. Leave off for normal play.")
  public let debugLog: Bool = false;

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
