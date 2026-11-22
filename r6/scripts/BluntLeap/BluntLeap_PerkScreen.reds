// Blunt Leap: what the perk screen needs beyond the game's own handling.
//
//   - With an unlock rule that uses no perks, the two nodes are left out.
//   - Blunt leap shows the game's own locked look while Dash is missing.
//   - Three wires in the game's own style: Breakthrough to Blunt leap, Blunt
//     leap to Stronger leap, and the Dash box to Blunt leap. The game's layout
//     has no wire between those slots, so they are added here, at run time,
//     from the game's own wire pictures (perks_new.inkatlas). Each wire keeps
//     the game's details: the connector pads at both ends sit at a slightly
//     different level than the straight middle, with a short jog between.
//   - A small Dash box under Blunt leap while Dash is required, made of the
//     game's own perk-box pictures at 60% size: red without Dash, gold with.
//     It reacts to the pointer like a perk box and opens Dash's own perk card,
//     with a line saying where Dash is and why Battering Ram needs it.
// Colours and states come from the game's own style file, exactly as for
// the game's nodes and wires. No layout file is edited.
//
// Positions are in the perk screen's own 3840 x 2160 space, read from the
// game's layout (new_perks.inkwidget): Stronger leap, Blunt leap and
// Breakthrough sit on one row, centres at x 2169.5, 2464 and 2758.5, y 1361;
// a perk box is 133 x 142.

@addField(NewPerksScreenLogicController)
private let m_bluntLeapFlash: Bool;

// The game is about to build the nodes from the page's perk list.
@wrapMethod(NewPerksScreenLogicController)
private final func AttachSlotControllers() -> Void {
  let system: ref<BluntLeapSystem> = BluntLeapSystem.Get(this.m_player.GetGame());
  let kept: array<wref<NewPerk_Record>>;
  let i: Int32 = 0;
  if !IsDefined(system) || system.NodesHidden() {
    while i < ArraySize(this.m_perksList) {
      if this.m_perksList[i].GetID() != t"NewPerks.BluntLeap_Leap" && this.m_perksList[i].GetID() != t"NewPerks.BluntLeap_Stronger" {
        ArrayPush(kept, this.m_perksList[i]);
      };
      i += 1;
    };
    this.m_perksList = kept;
  };
  wrappedMethod();
}

@wrapMethod(NewPerksScreenLogicController)
private final func BuildPerkTree() -> Void {
  wrappedMethod();
  this.BluntLeap_ApplyDashLock();
  this.BluntLeap_UpdateWires();
}

@wrapMethod(NewPerksScreenLogicController)
private final func ReevaluatePerkAvailability() -> Void {
  wrappedMethod();
  this.BluntLeap_ApplyDashLock();
  this.BluntLeap_UpdateWires();
}

@wrapMethod(NewPerksScreenLogicController)
protected cb func OnNewPerkUnlocked(evt: ref<NewPerkUnlockedEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  this.BluntLeap_ApplyDashLock();
  this.BluntLeap_UpdateWires();
  return result;
}

@wrapMethod(NewPerksScreenLogicController)
protected cb func OnNewPerkBought(evt: ref<NewPerkBoughtEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  this.BluntLeap_UpdateWires();
  return result;
}

@wrapMethod(NewPerksScreenLogicController)
protected cb func OnNewPerkSold(evt: ref<NewPerkSoldEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  this.BluntLeap_UpdateWires();
  return result;
}

// A click on a locked perk: the game flashes the unmaxed perks on its path.
// For Blunt leap the missing piece may be Dash, which is not on this page:
// its box and wire flash red instead, until the pointer leaves the perk.
@wrapMethod(NewPerksScreenLogicController)
private final func IndicateUnmaxedPerksInPath(controller: wref<NewPerksPerkItemLogicController>) -> Void {
  wrappedMethod(controller);
  if IsDefined(controller) && IsDefined(this.m_playerDevelopmentData) && this.m_playerDevelopmentData.BluntLeap_BlockedByDash(controller.GetPerkType()) {
    this.m_bluntLeapFlash = true;
    this.BluntLeap_UpdateWires();
  };
}

@wrapMethod(NewPerksScreenLogicController)
public final func StopPathToTargetPerkAnimations() -> Void {
  wrappedMethod();
  if this.m_bluntLeapFlash {
    this.m_bluntLeapFlash = false;
    this.BluntLeap_UpdateWires();
  };
}

// The game's locked look for Blunt leap while Dash is missing, whatever
// told the node otherwise.
@addMethod(NewPerksScreenLogicController)
private final func BluntLeap_ApplyDashLock() -> Void {
  let leap: gamedataNewPerkType = BluntLeapSystem.LeapPerk();
  let node: wref<NewPerksPerkItemLogicController>;
  if Equals(leap, gamedataNewPerkType.Invalid) || !IsDefined(this.m_playerDevelopmentData) || !IsDefined(this.m_perksControllers) {
    return;
  };
  node = this.GetCachedPerkItemLogicController(leap);
  if IsDefined(node) && this.m_playerDevelopmentData.BluntLeap_BlockedByDash(leap) && node.IsUnlocked() {
    node.SetUnlocked(false);
  };
}

// The canvas that holds the three perk columns: three steps up from a node.
@addMethod(NewPerksScreenLogicController)
private final func BluntLeap_Trees() -> wref<inkCompoundWidget> {
  let container: wref<NewPerksPerkContainerLogicController> = this.GetCachedPerkContainerLogicController(gamedataNewPerkSlotType.Inbetween_Right_2);
  let widget: wref<inkWidget>;
  if !IsDefined(container) {
    return null;
  };
  widget = container.GetRootWidget();
  if IsDefined(widget) {
    widget = widget.parentWidget;
  };
  if IsDefined(widget) {
    widget = widget.parentWidget;
  };
  if IsDefined(widget) {
    widget = widget.parentWidget;
  };
  return widget as inkCompoundWidget;
}

// One of the game's wire pictures, stretched in the middle only (nine-slice),
// so the pads and the jogs at both ends keep the game's shape.
@addMethod(NewPerksScreenLogicController)
private final func BluntLeap_Wire(trees: wref<inkCompoundWidget>, name: CName, part: CName, x: Float, y: Float, width: Float, height: Float, slices: inkMargin) -> wref<inkWidget> {
  let existing: wref<inkWidget> = trees.GetWidgetByPathName(name);
  let wire: ref<inkImage>;
  if IsDefined(existing) {
    return existing;
  };
  wire = new inkImage();
  wire.SetName(name);
  wire.SetAtlasResource(r"base\\gameplay\\gui\\fullscreen\\perks\\perks_new.inkatlas");
  wire.SetTexturePart(part);
  wire.SetNineSliceScale(true);
  wire.SetNineSliceGrid(slices);
  wire.SetAnchor(inkEAnchor.TopLeft);
  wire.SetMargin(new inkMargin(x, y, 0.0, 0.0));
  wire.SetSize(new Vector2(width, height));
  wire.SetStyle(r"base\\gameplay\\gui\\fullscreen\\perks\\new_perks_style.inkstyle");
  wire.BindProperty(n"tintColor", n"PerkWire.wireColor");
  wire.SetState(n"Default");
  wire.SetInteractive(false);
  wire.Reparent(trees);
  return wire;
}

// One layer of a perk box: a picture centred in the box, tinted (and faded)
// by the game's own perk-box style. Layers carry the game's own names.
//
// It returns nothing on purpose. A script function that returns a weak
// reference made from a strong one crashes the game when its caller ignores
// the result: the game writes the reference into a result slot that is not
// there. The callers find a layer again by its name instead.
@addMethod(NewPerksScreenLogicController)
private final func BluntLeap_BoxLayer(box: wref<inkCanvas>, name: CName, atlas: ResRef, part: CName, width: Float, height: Float, tint: CName, opacity: CName) -> Void {
  let layer: ref<inkImage> = new inkImage();
  layer.SetName(name);
  layer.SetAtlasResource(atlas);
  layer.SetTexturePart(part);
  layer.SetAnchor(inkEAnchor.Centered);
  layer.SetAnchorPoint(new Vector2(0.5, 0.5));
  layer.SetSize(new Vector2(width, height));
  layer.SetStyle(r"base\\gameplay\\gui\\fullscreen\\perks\\new_perks_style.inkstyle");
  layer.BindProperty(n"tintColor", tint);
  if NotEquals(opacity, n"") {
    layer.BindProperty(n"opacity", opacity);
  };
  layer.SetInteractive(false);
  layer.Reparent(box);
}

// The small Dash box: the game's perk box at 60%, 48 px under Blunt leap
// (the game's gap between two stacked perks). It reacts to the pointer like
// a perk box and opens Dash's own perk card.
@addMethod(NewPerksScreenLogicController)
private final func BluntLeap_DashBox(trees: wref<inkCompoundWidget>) -> wref<inkCanvas> {
  let existing: wref<inkWidget> = trees.GetWidgetByPathName(n"BluntLeap_DashBox");
  let box: ref<inkCanvas>;
  let icon: ref<UIIcon_Record>;
  let image: wref<inkImage>;
  let sweep: wref<inkImage>;
  let cells: ResRef = r"base\\gameplay\\gui\\fullscreen\\perks\\perks_new.inkatlas";
  if IsDefined(existing) {
    return existing as inkCanvas;
  };
  box = new inkCanvas();
  box.SetName(n"BluntLeap_DashBox");
  box.SetAnchor(inkEAnchor.TopLeft);
  // Centre at (2464, 1522.6): the box's top edge, once scaled, is 48 px
  // under Blunt leap's bottom edge (1432).
  box.SetMargin(new inkMargin(2397.5, 1451.6, 0.0, 0.0));
  box.SetSize(new Vector2(133.0, 142.0));
  box.SetRenderTransformPivot(0.5, 0.5);
  box.SetScale(new Vector2(0.6, 0.6));
  box.SetStyle(r"base\\gameplay\\gui\\fullscreen\\perks\\new_perks_style.inkstyle");
  // Back to front, as the game layers its perk box.
  this.BluntLeap_BoxLayer(box, n"cell_outer_bg", cells, n"Perk_Cell_outer_bg", 133.0, 142.0, n"PerkCellBase.backgroundColorOuter", n"");
  this.BluntLeap_BoxLayer(box, n"cell_outer_fg", cells, n"Perk_Cell_outer_fg", 133.0, 142.0, n"PerkCellBase.foregroundColor", n"PerkCellBase.foregroundOpacity");
  this.BluntLeap_BoxLayer(box, n"cell_inner_bg", cells, n"Perk_Cell_inner_bg", 125.0, 116.0, n"PerkCellBase.backgroundColorInner", n"");
  icon = TweakDBInterface.GetUIIconRecord(t"UIIcon.Reflexes_Central_Milestone_2");
  if IsDefined(icon) {
    this.BluntLeap_BoxLayer(box, n"ico_master", icon.AtlasResourcePath(), icon.AtlasPartName(), 125.0, 116.0, n"PerkCellBase.iconColor", n"PerkCellBase.iconOpacity");
    image = box.GetWidgetByPathName(n"ico_master") as inkImage;
    if IsDefined(image) {
      image.SetRenderTransformPivot(0.5, 0.5);
    };
  };
  // The light that sweeps across the box on hover, as on the game's boxes.
  this.BluntLeap_BoxLayer(box, n"cell_inner_fg_9slices", cells, n"Perk_Cell_inner_fg_9slices", 40.0, 116.0, n"PerkCellBase.foregroundColorInner", n"");
  sweep = box.GetWidgetByPathName(n"cell_inner_fg_9slices") as inkImage;
  if IsDefined(sweep) {
    sweep.SetNineSliceScale(true);
    sweep.SetNineSliceGrid(new inkMargin(20.0, 0.0, 20.0, 0.0));
    sweep.SetOpacity(0.0);
  };
  this.BluntLeap_BoxLayer(box, n"cell_inner_fg", cells, n"Perk_Cell_inner_fg", 125.0, 116.0, n"PerkCellBase.foregroundColorInner", n"PerkCellBase.foregroundColorInnerOpacity");
  // Only the box itself takes the pointer.
  box.SetInteractive(true);
  box.RegisterToCallback(n"OnHoverOver", this, n"OnBluntLeapDashHoverOver");
  box.RegisterToCallback(n"OnHoverOut", this, n"OnBluntLeapDashHoverOut");
  box.Reparent(trees);
  return box;
}

@addField(NewPerksScreenLogicController)
private let m_bluntLeapDashHovered: Bool;

@addMethod(NewPerksScreenLogicController)
protected cb func OnBluntLeapDashHoverOver(evt: ref<inkPointerEvent>) -> Bool {
  let trees: wref<inkCompoundWidget>;
  let box: wref<inkWidget>;
  if !this.m_isActiveScreen {
    return false;
  };
  trees = this.BluntLeap_Trees();
  if !IsDefined(trees) {
    return false;
  };
  box = trees.GetWidgetByPathName(n"BluntLeap_DashBox");
  if !IsDefined(box) || !box.IsVisible() {
    return false;
  };
  this.m_bluntLeapDashHovered = true;
  this.SetCursorContext(n"Hover");
  this.BluntLeap_UpdateWires();
  this.BluntLeap_DashHoverAnimation(box as inkCompoundWidget, true);
  if IsDefined(this.m_gameController) {
    this.m_gameController.BluntLeap_ShowDashCard(box);
  };
  return false;
}

@addMethod(NewPerksScreenLogicController)
protected cb func OnBluntLeapDashHoverOut(evt: ref<inkPointerEvent>) -> Bool {
  let trees: wref<inkCompoundWidget>;
  if !this.m_bluntLeapDashHovered {
    return false;
  };
  this.m_bluntLeapDashHovered = false;
  this.SetCursorContext(n"Default");
  this.BluntLeap_UpdateWires();
  trees = this.BluntLeap_Trees();
  if IsDefined(trees) {
    this.BluntLeap_DashHoverAnimation(trees.GetWidgetByPathName(n"BluntLeap_DashBox") as inkCompoundWidget, false);
  };
  if IsDefined(this.m_gameController) {
    this.m_gameController.BluntLeap_HideDashCard();
  };
  return false;
}

// The game's hover on a perk box (perk_cell_hoverover / _hoverout): the icon
// grows by 8%, and a faint light sweeps across the box.
@addMethod(NewPerksScreenLogicController)
private final func BluntLeap_DashHoverAnimation(box: wref<inkCompoundWidget>, over: Bool) -> Void {
  let icon: wref<inkWidget>;
  let sweep: wref<inkWidget>;
  let iconAnim: ref<inkAnimDef>;
  let grow: ref<inkAnimScale>;
  let sweepAnim: ref<inkAnimDef>;
  let size: ref<inkAnimSize>;
  let fadeIn: ref<inkAnimTransparency>;
  let fadeOut: ref<inkAnimTransparency>;
  if !IsDefined(box) {
    return;
  };
  icon = box.GetWidgetByPathName(n"ico_master");
  sweep = box.GetWidgetByPathName(n"cell_inner_fg_9slices");
  if IsDefined(icon) {
    grow = new inkAnimScale();
    grow.SetStartScale(over ? new Vector2(1.0, 1.0) : new Vector2(1.08, 1.08));
    grow.SetEndScale(over ? new Vector2(1.08, 1.08) : new Vector2(1.0, 1.0));
    grow.SetDuration(0.156);
    grow.SetType(inkanimInterpolationType.Quadratic);
    grow.SetMode(inkanimInterpolationMode.EasyOut);
    iconAnim = new inkAnimDef();
    iconAnim.AddInterpolator(grow);
    icon.PlayAnimation(iconAnim);
  };
  if over && IsDefined(sweep) {
    size = new inkAnimSize();
    size.SetStartSize(new Vector2(40.0, 116.0));
    size.SetEndSize(new Vector2(116.0, 116.0));
    size.SetDuration(0.1865);
    fadeIn = new inkAnimTransparency();
    fadeIn.SetStartTransparency(0.0);
    fadeIn.SetEndTransparency(0.3);
    fadeIn.SetDuration(0.038);
    fadeOut = new inkAnimTransparency();
    fadeOut.SetStartTransparency(0.3);
    fadeOut.SetEndTransparency(0.0);
    fadeOut.SetStartDelay(0.1545);
    fadeOut.SetDuration(0.0325);
    sweepAnim = new inkAnimDef();
    sweepAnim.AddInterpolator(size);
    sweepAnim.AddInterpolator(fadeIn);
    sweepAnim.AddInterpolator(fadeOut);
    sweep.PlayAnimation(sweepAnim);
  };
}

// Dash's own perk card, opened from the Dash box: the same card as on the
// Reflexes page, placed beside the box the way the game places a perk's card.
// Marked, so the card adds where Dash is and why it is needed, and shows no
// buy or sell hints (BluntLeap_Perks.reds).
@addMethod(NewPerksCategoriesGameController)
public final func BluntLeap_ShowDashCard(box: wref<inkWidget>) -> Void {
  let dash: gamedataNewPerkType = gamedataNewPerkType.Reflexes_Central_Milestone_2;
  let record: ref<NewPerk_Record> = RPGManager.GetNewPerkRecord(dash);
  let development: ref<PlayerDevelopmentData>;
  let data: ref<NewPerkDisplayData>;
  let tooltipData: ref<BasePerksMenuTooltipData>;
  let holder: wref<inkWidget>;
  let boxPosition: Vector2;
  let boxSize: Vector2;
  let holderPosition: Vector2;
  let inverse: Float;
  let scale: Float = 0.6;
  let marginX: Float;
  let marginY: Float;
  if !IsDefined(box) || !IsDefined(record) || !IsDefined(this.m_player) || !IsDefined(this.m_tooltipsManager) || !IsDefined(this.m_uiSystem) {
    return;
  };
  development = PlayerDevelopmentSystem.GetData(this.m_player);
  if !IsDefined(development) {
    return;
  };
  data = new NewPerkDisplayData();
  data.m_type = dash;
  data.m_area = gamedataNewPerkSlotType.Central_Milestone_2;
  data.m_binkRef = record.BinkPath();
  data.m_level = development.IsNewPerkBought(dash);
  data.m_maxLevel = record.GetLevelsCount();
  data.m_locked = !development.IsNewPerkUnlocked(dash);
  data.bluntLeapDashBox = true;
  tooltipData = data.CreateTooltipData(this.m_dataManager);
  if !IsDefined(tooltipData) {
    return;
  };
  inverse = this.m_uiSystem.GetInverseUIScale();
  boxPosition = WidgetUtils.LocalToGlobal(box);
  boxSize = box.GetSize();
  if boxPosition.X < this.AdjustValueToScaleAndBlackBars(1400.0) {
    holder = inkWidgetRef.Get(this.m_perkTooltipPlacementRight);
    holderPosition = WidgetUtils.LocalToGlobal(holder);
    // The box is drawn at 60% around its centre: its right edge.
    marginX = ((boxPosition.X + boxSize.X * (1.0 + scale) / 2.0 / inverse) - holderPosition.X + 50.0 / inverse) * inverse;
    marginY = ((boxPosition.Y - holderPosition.Y) + boxSize.Y / inverse / 2.0) * inverse;
    this.m_tooltipsManager.ShowTooltipAtWidget(n"perkTooltip", holder, tooltipData, gameuiETooltipPlacement.RightCenter, true, new inkMargin(marginX, marginY, 0.0, 0.0));
    this.ShowTooltipBackground(this.m_perkTooltipBgRight);
  } else {
    holder = inkWidgetRef.Get(this.m_perkTooltipPlacementLeft);
    holderPosition = WidgetUtils.LocalToGlobal(holder);
    // Its left edge.
    marginX = ((boxPosition.X + boxSize.X * (1.0 - scale) / 2.0 / inverse) - holderPosition.X - 100.0 / inverse) * inverse;
    marginY = ((boxPosition.Y - holderPosition.Y) + boxSize.Y / inverse / 2.0) * inverse;
    this.m_tooltipsManager.ShowTooltipAtWidget(n"perkTooltip", holder, tooltipData, gameuiETooltipPlacement.LeftCenter, true, new inkMargin(marginX, marginY, 0.0, 0.0));
    this.ShowTooltipBackground(this.m_perkTooltipBgLeft);
  };
}

@addMethod(NewPerksCategoriesGameController)
public final func BluntLeap_HideDashCard() -> Void {
  this.HideTooltip();
}

// Sets a style state on a widget and on every widget inside it.
@addMethod(NewPerksScreenLogicController)
private final func BluntLeap_SetState(widget: wref<inkWidget>, state: CName) -> Void {
  let compound: wref<inkCompoundWidget> = widget as inkCompoundWidget;
  let i: Int32 = 0;
  if !IsDefined(widget) {
    return;
  };
  widget.SetState(state);
  if IsDefined(compound) {
    while i < compound.GetNumChildren() {
      this.BluntLeap_SetState(compound.GetWidgetByIndex(i), state);
      i += 1;
    };
  };
}

@addMethod(NewPerksScreenLogicController)
private final func BluntLeap_UpdateWires() -> Void {
  let trees: wref<inkCompoundWidget> = this.BluntLeap_Trees();
  let system: ref<BluntLeapSystem>;
  let data: ref<PlayerDevelopmentData>;
  let toLeap: wref<inkWidget>;
  let toStronger: wref<inkWidget>;
  let dashWire: wref<inkWidget>;
  let dashBox: wref<inkWidget>;
  let horizontal: inkMargin = new inkMargin(16.0, 0.0, 16.0, 0.0);
  let vertical: inkMargin = new inkMargin(0.0, 16.0, 0.0, 16.0);
  let show: Bool;
  let showDash: Bool;
  let hasDash: Bool;
  let leapLevel: Int32;
  let strongerLevel: Int32;

  if !IsDefined(trees) || !IsDefined(this.m_player) {
    return;
  };
  system = BluntLeapSystem.Get(this.m_player.GetGame());
  data = this.m_playerDevelopmentData;

  // Each wire spans the gap between two box edges exactly: 161.5 px across,
  // 48 px down. The game's horizontal wire picture is 60 x 26 (pads 0-11 and
  // 49-58, middle 16-43); its vertical one is 28 x 59 (pads 3-12 and 50-58).
  toLeap = this.BluntLeap_Wire(trees, n"BluntLeap_WireToLeap", n"wire_CPerk1_1_to_CPerk1_3", 2530.5, 1348.0, 161.5, 26.0, horizontal);
  toStronger = this.BluntLeap_Wire(trees, n"BluntLeap_WireToStronger", n"wire_CPerk1_1_to_CPerk1_3", 2236.0, 1348.0, 161.5, 26.0, horizontal);
  dashWire = this.BluntLeap_Wire(trees, n"BluntLeap_WireToDash", n"wire_CPerk2_1_to_CPerk2_3", 2450.0, 1432.0, 28.0, 48.0, vertical);
  dashBox = this.BluntLeap_DashBox(trees);

  // The same widgets serve every attribute page; ours belong to Body only.
  show = IsDefined(system) && IsDefined(data) && !system.NodesHidden() && Equals(this.m_initData.attributeData.Type(), gamedataAttributeDataType.BodyAttributeData);
  showDash = show && system.NeedsDash() && system.Settings().dashMarker;
  toLeap.SetVisible(show);
  toStronger.SetVisible(show);
  dashWire.SetVisible(showDash);
  dashBox.SetVisible(showDash);
  if !show {
    return;
  };

  leapLevel = data.IsNewPerkBought(BluntLeapSystem.LeapPerk());
  strongerLevel = data.IsNewPerkBought(BluntLeapSystem.StrongerPerk());
  hasDash = BluntLeapSystem.HasDash(data);

  // The game's rule: a wire turns blue (Available) once its own parent is
  // bought, and gold (Bought) once the perk it leads to is bought.
  if leapLevel > 0 {
    this.BluntLeap_SetState(toLeap, n"Bought");
  } else {
    if data.IsNewPerkBought(gamedataNewPerkType.Body_Right_Perk_2_4) > 0 {
      this.BluntLeap_SetState(toLeap, n"Available");
    } else {
      this.BluntLeap_SetState(toLeap, n"Default");
    };
  };

  if strongerLevel > 0 {
    this.BluntLeap_SetState(toStronger, n"Bought");
  } else {
    if leapLevel > 0 {
      this.BluntLeap_SetState(toStronger, n"Available");
    } else {
      this.BluntLeap_SetState(toStronger, n"Default");
    };
  };

  if showDash {
    if leapLevel > 0 {
      this.BluntLeap_SetState(dashWire, n"Bought");
    } else {
      if hasDash {
        this.BluntLeap_SetState(dashWire, n"Available");
      } else {
        if this.m_bluntLeapFlash {
          this.BluntLeap_SetState(dashWire, n"LockedHighlight");
        } else {
          this.BluntLeap_SetState(dashWire, n"Default");
        };
      };
    };
    if hasDash {
      this.BluntLeap_SetState(dashBox, this.m_bluntLeapDashHovered ? n"BoughtHover" : n"Bought");
    } else {
      if this.m_bluntLeapFlash || this.m_bluntLeapDashHovered {
        this.BluntLeap_SetState(dashBox, n"LockedHover");
      } else {
        this.BluntLeap_SetState(dashBox, n"Locked");
      };
    };
  };
}
