// Blunt Leap: what the perk screen needs beyond the game's own handling.
//
//   - With an unlock rule that uses no perks, the two nodes are left out.
//   - Two short lines: Breakthrough to Blunt leap, Blunt leap to Stronger
//     leap. The game's layout has no line between those slots, so they are
//     drawn here, at run time. No layout file is edited.
//   - Optionally a small Dash marker above Blunt leap while Dash is required.
//
// Positions are in the perk screen's own 3840 x 2160 space, read from the
// game's layout (new_perks.inkwidget): the three nodes sit on one row, their
// centres at x 2169.5, 2464 and 2758.5, y 1361.

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
  this.BluntLeap_UpdateLines();
}

@wrapMethod(NewPerksScreenLogicController)
protected cb func OnNewPerkBought(evt: ref<NewPerkBoughtEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  this.BluntLeap_UpdateLines();
  return result;
}

@wrapMethod(NewPerksScreenLogicController)
protected cb func OnNewPerkSold(evt: ref<NewPerkSoldEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  this.BluntLeap_UpdateLines();
  return result;
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

// Finds one of our widgets on the screen, or makes it.
@addMethod(NewPerksScreenLogicController)
private final func BluntLeap_Bar(trees: wref<inkCompoundWidget>, name: CName, x: Float, y: Float, width: Float, height: Float) -> wref<inkWidget> {
  let existing: wref<inkWidget> = trees.GetWidgetByPathName(name);
  let bar: ref<inkRectangle>;
  if IsDefined(existing) {
    return existing;
  };
  bar = new inkRectangle();
  bar.SetName(name);
  bar.SetAnchor(inkEAnchor.TopLeft);
  bar.SetMargin(new inkMargin(x, y, 0.0, 0.0));
  bar.SetSize(new Vector2(width, height));
  bar.SetInteractive(false);
  bar.Reparent(trees);
  return bar;
}

@addMethod(NewPerksScreenLogicController)
private final func BluntLeap_Marker(trees: wref<inkCompoundWidget>) -> wref<inkWidget> {
  let existing: wref<inkWidget> = trees.GetWidgetByPathName(n"BluntLeap_DashMarker");
  let icon: ref<UIIcon_Record>;
  let image: ref<inkImage>;
  if IsDefined(existing) {
    return existing;
  };
  image = new inkImage();
  image.SetName(n"BluntLeap_DashMarker");
  image.SetAnchor(inkEAnchor.TopLeft);
  image.SetMargin(new inkMargin(2428.0, 1193.0, 0.0, 0.0));
  image.SetSize(new Vector2(72.0, 72.0));
  image.SetInteractive(false);
  icon = TweakDBInterface.GetUIIconRecord(t"UIIcon.Reflexes_Central_Milestone_2");
  if IsDefined(icon) {
    image.SetAtlasResource(icon.AtlasResourcePath());
    image.SetTexturePart(icon.AtlasPartName());
  };
  image.Reparent(trees);
  return image;
}

// 0 = not reachable yet, 1 = can be bought, 2 = bought.
@addMethod(NewPerksScreenLogicController)
private final func BluntLeap_Paint(widget: wref<inkWidget>, state: Int32) -> Void {
  if !IsDefined(widget) {
    return;
  };
  if state >= 2 {
    widget.SetTintColor(new HDRColor(1.1192, 0.8441, 0.2565, 1.0));
    widget.SetOpacity(1.0);
  } else {
    if state == 1 {
      widget.SetTintColor(new HDRColor(1.1761, 0.3809, 0.3476, 1.0));
      widget.SetOpacity(1.0);
    } else {
      widget.SetTintColor(new HDRColor(0.4500, 0.1600, 0.1500, 1.0));
      widget.SetOpacity(0.7);
    };
  };
}

@addMethod(NewPerksScreenLogicController)
private final func BluntLeap_UpdateLines() -> Void {
  let trees: wref<inkCompoundWidget> = this.BluntLeap_Trees();
  let system: ref<BluntLeapSystem>;
  let data: ref<PlayerDevelopmentData>;
  let toLeap: wref<inkWidget>;
  let toStronger: wref<inkWidget>;
  let marker: wref<inkWidget>;
  let markerLine: wref<inkWidget>;
  let show: Bool;
  let showMarker: Bool;
  let leapLevel: Int32;
  let strongerLevel: Int32;
  let state: Int32;

  if !IsDefined(trees) || !IsDefined(this.m_player) {
    return;
  };
  system = BluntLeapSystem.Get(this.m_player.GetGame());
  data = this.m_playerDevelopmentData;
  toLeap = this.BluntLeap_Bar(trees, n"BluntLeap_LineToLeap", 2523.0, 1359.0, 176.0, 4.0);
  toStronger = this.BluntLeap_Bar(trees, n"BluntLeap_LineToStronger", 2229.0, 1359.0, 176.0, 4.0);
  markerLine = this.BluntLeap_Bar(trees, n"BluntLeap_DashLine", 2462.0, 1267.0, 4.0, 30.0);
  marker = this.BluntLeap_Marker(trees);

  // The same widgets serve every attribute page; ours belong to Body only.
  show = IsDefined(system) && IsDefined(data) && !system.NodesHidden() && Equals(this.m_initData.attributeData.Type(), gamedataAttributeDataType.BodyAttributeData);
  showMarker = show && system.NeedsDash() && system.Settings().dashMarker;
  toLeap.SetVisible(show);
  toStronger.SetVisible(show);
  marker.SetVisible(showMarker);
  markerLine.SetVisible(showMarker);
  if !show {
    return;
  };

  leapLevel = data.IsNewPerkBought(BluntLeapSystem.LeapPerk());
  strongerLevel = data.IsNewPerkBought(BluntLeapSystem.StrongerPerk());

  state = 0;
  if leapLevel > 0 {
    state = 2;
  } else {
    if data.IsNewPerkUnlocked(BluntLeapSystem.LeapPerk()) {
      state = 1;
    };
  };
  this.BluntLeap_Paint(toLeap, state);

  state = 0;
  if strongerLevel > 0 {
    state = 2;
  } else {
    if leapLevel > 0 {
      state = 1;
    };
  };
  this.BluntLeap_Paint(toStronger, state);

  if showMarker {
    state = BluntLeapSystem.HasDash(data) ? 2 : 0;
    this.BluntLeap_Paint(marker, state);
    this.BluntLeap_Paint(markerLine, state);
  };
}
