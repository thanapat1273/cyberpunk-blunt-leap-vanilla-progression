// Blunt Leap: the texts of the two perks and of the Dash box, through
// Codeware's localization (the perk records name them by key, BluntLeap-...).
// English only for now; other languages fall back to it.
//
// The descriptions are written in the style of the game's own: Flash and
// Thunderclap (the blade leap) and the Gorilla Arms charged attack are the
// models. A few settings change what a perk does, so each description exists
// in every variant and BluntLeapSystem points the perk at the right one.
// Numbers come from the perk records ({float_0}, ...), which follow the
// settings too.

import Codeware.Localization.*

public class BluntLeapLocalization extends ModLocalizationProvider {

  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    switch language {
      case n"en-us":
        return new BluntLeapEnglish();
      default:
        return null;
    }
  }

  public func GetFallback() -> CName {
    return n"en-us";
  }
}

public class BluntLeapEnglish extends ModLocalizationPackage {

  private final func Hl(text: String) -> String {
    return "<Rich color=\"TooltipText.cyberwareDescriptionHighlightColor\" style=\"Semi-Bold\">" + text + "</>";
  }

  protected func DefineTexts() -> Void {
    let charged: Int32 = 0;
    let air: Int32;
    let bonus: Int32;
    let emp: Int32;
    let stagger: Int32;
    let text: String;
    let second: String;

    this.Text("BluntLeap-Perk-Leap-Name", "Battering Ram");
    this.Text("BluntLeap-Perk-Stronger-Name", "Thunder Breaker");

    // Battering Ram: "Always charged" on or off, mid-air on or off, distance
    // bonus on or off. Key: BluntLeap-Perk-Leap-Desc-<C|N><A|G><B|0>.
    while charged < 2 {
      air = 0;
      while air < 2 {
        bonus = 0;
        while bonus < 2 {
          if charged == 1 {
            text = "When performing fully charged Strong Attacks with Blunt Weapons, you now " + this.Hl("automatically leap") + " to enemies within range.";
          } else {
            text = "When performing Strong Attacks with Blunt Weapons, you now " + this.Hl("automatically leap") + " to enemies within range.";
          };
          second = "";
          if air == 1 && bonus == 1 {
            second = "These " + this.Hl("Leap Attacks") + " can also be performed from midair, and deal additional damage that scales with the distance of the leap (max. +{float_0}%).";
          } else {
            if air == 1 {
              second = "These " + this.Hl("Leap Attacks") + " can also be performed from midair.";
            } else {
              if bonus == 1 {
                second = "These " + this.Hl("Leap Attacks") + " deal additional damage that scales with the distance of the leap (max. +{float_0}%).";
              };
            };
          };
          if NotEquals(second, "") {
            text += "\n\n" + second;
          };
          this.Text(BluntLeapEnglish.LeapKey(charged == 1, air == 1, bonus == 1), text);
          bonus += 1;
        };
        air += 1;
      };
      charged += 1;
    };

    // Thunder Breaker: EMP on or off, stagger on or off.
    // Key: BluntLeap-Perk-Stronger-Desc-<E|0><S|0>.
    emp = 0;
    while emp < 2 {
      stagger = 0;
      while stagger < 2 {
        text = "Holding a Strong Attack with Blunt Weapons now charges it up.\n\n";
        text += "A " + this.Hl("fully charged Leap Attack") + " reaches " + this.Hl("+{float_0}% farther") + " and lands faster. ";
        text += "Its hit can " + this.Hl("send the enemy flying") + " ({float_1}% chance, {float_2}% against heavy enemies)";
        if stagger == 1 {
          text += " and staggers them otherwise.";
        } else {
          text += ".";
        };
        if emp == 1 {
          text += "\n\nCrit Hits also release an " + this.Hl("EMP blast") + " around the target.";
        };
        this.Text(BluntLeapEnglish.StrongerKey(emp == 1, stagger == 1), text);
        stagger += 1;
      };
      emp += 1;
    };

    // The lock line on Battering Ram's card while Dash is missing.
    this.Text("BluntLeap-Perk-NeedsDash", "Requires " + this.Hl("Dash") + " (Reflexes) at level 2.");

    // The line on the Dash box's card: where to get Dash, and why it is
    // there. {0} is the Reflexes level that unlocks Dash.
    this.Text("BluntLeap-Dash-Why", "Found in the Reflexes tree (Reflexes {0}). " + this.Hl("Battering Ram") + " needs both of its levels: the leap is a Dash that ends in a heavy hit.");
  }

  public final static func LeapKey(charged: Bool, air: Bool, bonus: Bool) -> String {
    return "BluntLeap-Perk-Leap-Desc-" + (charged ? "C" : "N") + (air ? "A" : "G") + (bonus ? "B" : "0");
  }

  public final static func StrongerKey(emp: Bool, stagger: Bool) -> String {
    return "BluntLeap-Perk-Stronger-Desc-" + (emp ? "E" : "0") + (stagger ? "S" : "0");
  }
}
