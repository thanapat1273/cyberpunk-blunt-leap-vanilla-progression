// Blunt Leap: the two perks and the rules around them.
//
// The perks are real perks (Perk Addition Framework adds their IDs to the
// game's list), so buying, selling, respec and saving are the game's own.
// These hooks add what the game cannot do by itself:
//   - the Dash requirement, which lives on another page of the perk screen;
//   - refunds when a requirement or the unlock rule changes;
//   - telling BluntLeapSystem when ownership changed.
// Every wrapper calls the original first and only acts for the player.

@addMethod(PlayerDevelopmentData)
private final const func BluntLeap_System() -> ref<BluntLeapSystem> {
  if !IsDefined(this.m_owner as PlayerPuppet) {
    return null;
  };
  return BluntLeapSystem.Get(this.m_owner.GetGame());
}

// True when this is the Blunt leap perk and the rule asks for Dash, which the
// player does not have at level 2.
@addMethod(PlayerDevelopmentData)
public final const func BluntLeap_BlockedByDash(perkType: gamedataNewPerkType) -> Bool {
  let system: ref<BluntLeapSystem>;
  // Perks of the game itself can never be ours: the added ones come after.
  if EnumInt(perkType) <= EnumInt(gamedataNewPerkType.Invalid) {
    return false;
  };
  system = this.BluntLeap_System();
  if !IsDefined(system) || !system.UsesPerks() || !system.NeedsDash() {
    return false;
  };
  if NotEquals(perkType, BluntLeapSystem.LeapPerk()) {
    return false;
  };
  return this.IsNewPerkBought(gamedataNewPerkType.Reflexes_Central_Milestone_2) < 2;
}

// Sells every level of one of our perks and gives the points back. The perk
// screen is not told: it is either closed or showing another page, and it
// rebuilds itself from the data when the Body page is opened.
@addMethod(PlayerDevelopmentData)
public final func BluntLeap_Refund(perkType: gamedataNewPerkType) -> Bool {
  let level: Int32;
  let sold: Bool = false;
  let soldEvent: ref<NewPerkSoldEvent>;
  if EnumInt(perkType) <= EnumInt(gamedataNewPerkType.Invalid) {
    return false;
  };
  while this.ForceSellNewPerk(perkType, level) {
    sold = true;
    soldEvent = new NewPerkSoldEvent();
    soldEvent.perkType = perkType;
    soldEvent.perkLevelSold = level;
    this.m_owner.QueueEvent(soldEvent);
  };
  return sold;
}

// The Dash requirement, part 0: while Dash is missing the perk is never put
// on the game's list of unlocked perks. Otherwise the game tells the open
// perk screen "perk unlocked" (for example right after Breakthrough is
// bought) and the node turns blue without asking any other check. When Dash
// is bought the game unlocks it as usual the next time the Body page opens.
@wrapMethod(PlayerDevelopmentData)
public final func UnlockNewPerk(perkType: gamedataNewPerkType) -> Bool {
  if this.BluntLeap_BlockedByDash(perkType) {
    return false;
  };
  return wrappedMethod(perkType);
}

// The Dash requirement, part 1: the perk shows as locked.
@wrapMethod(PlayerDevelopmentData)
public final const func IsNewPerkUnlocked(perkType: gamedataNewPerkType) -> Bool {
  if !wrappedMethod(perkType) {
    return false;
  };
  return !this.BluntLeap_BlockedByDash(perkType);
}

// The Dash requirement, part 2: the perk cannot be bought.
@wrapMethod(PlayerDevelopmentData)
private final const func CanNewPerkBeBought(perkType: gamedataNewPerkType, isEspionagePerk: Bool, isEspionageMilestonePerk: Bool) -> Bool {
  if !wrappedMethod(perkType, isEspionagePerk, isEspionageMilestonePerk) {
    return false;
  };
  return !this.BluntLeap_BlockedByDash(perkType);
}

@wrapMethod(PlayerDevelopmentData)
public final func BuyNewPerk(perkType: gamedataNewPerkType, opt forceBuy: Bool) -> Bool {
  let bought: Bool = wrappedMethod(perkType, forceBuy);
  let system: ref<BluntLeapSystem>;
  if bought {
    system = this.BluntLeap_System();
    if IsDefined(system) {
      system.OnPerksChanged();
    };
  };
  return bought;
}

// Selling Dash while it is required refunds our perks with it.
@wrapMethod(PlayerDevelopmentData)
public final func SellNewPerk(perkType: gamedataNewPerkType, out perkLevelSold: Int32) -> Bool {
  let sold: Bool = wrappedMethod(perkType, perkLevelSold);
  let system: ref<BluntLeapSystem>;
  if sold {
    system = this.BluntLeap_System();
    if IsDefined(system) {
      if Equals(perkType, gamedataNewPerkType.Reflexes_Central_Milestone_2) {
        system.Validate();
      } else {
        system.OnPerksChanged();
      };
    };
  };
  return sold;
}

// One of the added perks was sold by force (a respec through Perk Addition
// Framework, its repair at load, or our own refund).
@wrapMethod(PlayerDevelopmentData)
public final func ForceSellNewPerk(perkType: gamedataNewPerkType, out perkLevelSold: Int32) -> Bool {
  let sold: Bool = wrappedMethod(perkType, perkLevelSold);
  let system: ref<BluntLeapSystem>;
  if sold && EnumInt(perkType) > EnumInt(gamedataNewPerkType.Invalid) {
    system = this.BluntLeap_System();
    if IsDefined(system) {
      system.OnPerksChanged();
    };
  };
  return sold;
}

// A full respec.
@wrapMethod(PlayerDevelopmentData)
public final func ResetNewPerks() -> Void {
  let system: ref<BluntLeapSystem>;
  wrappedMethod();
  system = this.BluntLeap_System();
  if IsDefined(system) {
    system.OnPerksChanged();
  };
}

// Marks the perk card opened from the Dash box on the Body page (see
// BluntLeap_PerkScreen.reds), so its card can say where Dash is and why it is
// there, and offer no buy or sell.
@addField(NewPerkDisplayData)
public let bluntLeapDashBox: Bool;

// The Dash requirement, part 3: the cards say what is missing.
//   - Battering Ram's card, while Dash is missing: "Requires Dash ...".
//   - The Dash box's card: where to get Dash and why Battering Ram needs it.
// The game's current perk card has no requirement row (the controller's
// unlock-info fields point at nothing), so the line goes into the card's
// text block under the level descriptions, which perk cards leave unused
// (the game hides it again for every other card).
@wrapMethod(PerkDisplayTooltipController)
private final func UpdateRequirements(playerDevelopmentData: wref<PlayerDevelopmentData>, data: ref<NewPerkTooltipData>) -> Void {
  let record: ref<NewPerk_Record>;
  let level: Int32 = 9;
  let block: wref<inkWidget>;
  wrappedMethod(playerDevelopmentData, data);
  block = inkWidgetRef.Get(this.m_traitLevelGrowthText);
  if !IsDefined(data) || !IsDefined(block) {
    return;
  };
  // Every other perk card: the block keeps the game's own colour.
  block.BindProperty(n"tintColor", n"PerkTooltip.levelColor");
  if IsDefined(data.perkData) && data.perkData.bluntLeapDashBox {
    record = RPGManager.GetNewPerkRecord(gamedataNewPerkType.Reflexes_Central_Milestone_2);
    if IsDefined(record) && IsDefined(record.Tier()) {
      level = record.Tier().RequiredAttributePoints();
    };
    this.BluntLeap_CardLine(StrReplace(GetLocalizedText("BluntLeap-Dash-Why"), "{0}", IntToString(level)));
    return;
  };
  if IsDefined(playerDevelopmentData) && playerDevelopmentData.BluntLeap_BlockedByDash(data.perkType) {
    this.BluntLeap_CardLine(GetLocalizedText("BluntLeap-Perk-NeedsDash"));
    return;
  };
}

// Shows one of our lines in the card's text block. The game tints that block
// black (it was made to sit on a gold bar), so it is given the colour of the
// card's descriptions while it shows our line.
@addMethod(PerkDisplayTooltipController)
private final func BluntLeap_CardLine(text: String) -> Void {
  let block: wref<inkWidget> = inkWidgetRef.Get(this.m_traitLevelGrowthText);
  if !IsDefined(block) {
    return;
  };
  block.BindProperty(n"tintColor", n"PerkTooltip.descriptionColour");
  inkTextRef.SetText(this.m_traitLevelGrowthText, text);
  inkTextRef.SetVisible(this.m_traitLevelGrowthText, true);
}

// The Dash box's card shows Dash, a perk of another page: no buy or sell
// hints on it.
@wrapMethod(PerkDisplayTooltipController)
private final func UpdateTooltipHints(data: ref<BasePerksMenuTooltipData>, perkData: ref<BasePerkDisplayData>) -> Void {
  let newPerk: ref<NewPerkDisplayData> = perkData as NewPerkDisplayData;
  wrappedMethod(data, perkData);
  if IsDefined(newPerk) && newPerk.bluntLeapDashBox {
    inkWidgetRef.SetVisible(this.m_inputHints, false);
  };
}
