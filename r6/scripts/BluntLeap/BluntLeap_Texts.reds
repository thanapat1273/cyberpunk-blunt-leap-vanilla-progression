// Blunt Leap: the texts of the two perks, through Codeware's localization
// (the perk records name them by key, BluntLeap-...). English only for
// now; other languages fall back to it. The names are working names.

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

  protected func DefineTexts() -> Void {
    this.Text("BluntLeap-Perk-Leap-Name", "Blunt Leap");
    this.Text("BluntLeap-Perk-Leap-Desc", "When performing Strong Attacks with Blunt Weapons, you now <Rich color=\"TooltipText.cyberwareDescriptionHighlightColor\" style=\"Semi-Bold\">automatically leap</> to enemies within range.\n\nThese <Rich color=\"TooltipText.cyberwareDescriptionHighlightColor\" style=\"Semi-Bold\">Leap Attacks</> deal up to +{float_0}% damage, depending on the distance leaped.");
    this.Text("BluntLeap-Perk-Stronger-Name", "Stronger Leap");
    this.Text("BluntLeap-Perk-Stronger-Desc", "A <Rich color=\"TooltipText.cyberwareDescriptionHighlightColor\" style=\"Semi-Bold\">fully charged</> Leap Attack with a Blunt Weapon reaches +{float_0}% further, and faster.\n\nIts hit has a {float_1}% chance to <Rich color=\"TooltipText.cyberwareDescriptionHighlightColor\" style=\"Semi-Bold\">send the enemy flying</>, and staggers them otherwise. A Crit Hit also sets off an EMP burst.");
    this.Text("BluntLeap-Perk-NeedsDash", "Requires Dash (Reflexes) at level 2");
  }
}
