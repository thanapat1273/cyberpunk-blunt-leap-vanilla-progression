// Blunt Leap: the two hooks on the game's leap.
//
// Both wrap the original and call it first; neither replaces it. Finisher
// leaps and every weapon that is not blunt pass through untouched (a mod that
// replaced MeleeLeapDecisions broke Gorilla Arms quick finishers this way).

// Our own checks on a leap the game has already said yes to. Also stores the
// charge the leap starts with (in a state-machine parameter, nothing is
// written to the save): the game empties the weapon's charge between this
// decision and the leap.
@addMethod(MeleeLeapDecisions)
private final const func BluntLeap_Allow(stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let system: ref<BluntLeapSystem>;
  let settings: ref<BluntLeapSettings>;
  let weapon: ref<WeaponObject>;
  let charge: Float;

  // A finisher leap is the game's own business.
  if EntityID.IsDefined(scriptInterface.localBlackboard.GetEntityID(GetAllBlackboardDefs().PlayerStateMachine.FinisherTarget)) {
    return true;
  };
  weapon = MeleeTransition.GetWeaponObject(scriptInterface);
  if !IsDefined(weapon) || !WeaponObject.IsBlunt(weapon.GetItemID()) {
    return true;
  };
  system = BluntLeapSystem.Get(scriptInterface.executionOwner.GetGame());
  if !IsDefined(system) {
    return true;
  };
  settings = system.Settings();
  if !settings.enabled {
    return true;
  };

  // Shorter range than the game's own, if the setting asks for it.
  if settings.leapRange < this.GetStaticFloatParameterDefault("maxDistToTarget", 15.0) - 0.01 {
    if !IsDefined(DefaultTransition.GetTargetObject(scriptInterface, settings.leapRange, false)) {
      return false;
    };
  };

  charge = BluntLeapSystem.ChargeOf(weapon);

  // "Always charged": only a full charge leaps. A weapon without any charge
  // pool is let through, so a missing pool can never switch the leap off.
  if settings.alwaysCharged && charge < 1.0 {
    if GameInstance.GetStatPoolsSystem(weapon.GetGame()).IsStatPoolAdded(Cast<StatsObjectID>(weapon.GetEntityID()), gamedataStatPoolType.WeaponCharge) {
      return false;
    };
  };

  stateContext.SetPermanentFloatParameter(n"BluntLeap_Charge", charge, true);
  return true;
}

@wrapMethod(MeleeLeapDecisions)
protected const func EnterCondition(stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if !wrappedMethod(stateContext, scriptInterface) {
    return false;
  };
  if this.BluntLeap_Allow(stateContext, scriptInterface) {
    return true;
  };
  // The original marked the leap as started just before it said yes.
  stateContext.SetPermanentBoolParameter(n"IsInMeleeLeapState", false, true);
  return false;
}

@wrapMethod(MeleeLeapEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let weapon: ref<WeaponObject>;
  let system: ref<BluntLeapSystem>;
  let settings: ref<BluntLeapSettings>;
  let stored: StateResultFloat;
  let exitTime: StateResultFloat;
  let target: ref<GameObject>;
  let perkData: ref<IBlackboard>;
  let owner: ref<GameObject>;

  wrappedMethod(stateContext, scriptInterface);

  stored = stateContext.GetPermanentFloatParameter(n"BluntLeap_Charge");
  stateContext.SetPermanentFloatParameter(n"BluntLeap_Charge", 0.0, true);

  if this.m_isFinisher {
    return;
  };
  // The original sets this only when the leap really started.
  if !scriptInterface.localBlackboard.GetBool(GetAllBlackboardDefs().PlayerStateMachine.MeleeLeap) {
    return;
  };
  weapon = MeleeTransition.GetWeaponObject(scriptInterface);
  if !IsDefined(weapon) || !WeaponObject.IsBlunt(weapon.GetItemID()) {
    return;
  };
  owner = scriptInterface.executionOwner;
  system = BluntLeapSystem.Get(owner.GetGame());
  if !IsDefined(system) {
    return;
  };
  settings = system.Settings();
  if !settings.enabled {
    return;
  };

  // 1. Distance leaped, for the distance damage bonus. The game records it
  //    for blades only. The player has not moved yet at this point.
  target = DefaultTransition.GetTargetObject(scriptInterface, this.GetStaticFloatParameterDefault("maxDistToTarget", 15.0), false, this.GetStaticFloatParameterDefault("leapTargetWithinAngle", 10.0));
  perkData = GameInstance.GetBlackboardSystem(owner.GetGame()).Get(GetAllBlackboardDefs().PlayerPerkData);
  if IsDefined(target) && IsDefined(perkData) {
    perkData.SetFloat(GetAllBlackboardDefs().PlayerPerkData.LeapedDistance, Vector4.Distance(target.GetWorldPosition(), owner.GetWorldPosition()), true);
  };

  // 2. Hammers swing slower, so they leave the leap for the swing earlier.
  if Equals(WeaponObject.GetWeaponType(weapon.GetItemID()), gamedataItemType.Wea_Hammer) {
    exitTime = stateContext.GetConditionFloatParameter(n"LeapExitTime");
    if exitTime.valid && exitTime.value > 0.0 {
      stateContext.SetConditionFloatParameter(n"LeapExitTime", MaxF(exitTime.value - (settings.hammerLead - this.GetStaticFloatParameterDefault("attackStartupDuration", 0.3)), 0.0), true);
    };
  };

  // 3. Give the weapon back the charge the leap started with, so the hit
  //    gets the game's charged-attack bonus. Only for the pool we added.
  if stored.valid && stored.value > 0.0 && system.OwnsChargeOf(weapon) {
    GameInstance.GetStatPoolsSystem(owner.GetGame()).RequestSettingStatPoolValue(Cast<StatsObjectID>(weapon.GetEntityID()), gamedataStatPoolType.WeaponCharge, stored.value * 100.0, null, true);
  };
}
