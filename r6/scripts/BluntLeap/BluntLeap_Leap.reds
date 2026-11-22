// Blunt Leap: the hooks on the game's leap.
//
// Both wrappers call the original first; neither replaces it. Finisher leaps
// and every weapon that is not blunt pass through untouched (a mod that
// replaced MeleeLeapDecisions broke Gorilla Arms quick finishers this way).
//
// Two state-machine parameters carry facts from the decision to the leap
// (nothing is written to the save):
//   BluntLeap_Charge  the charge the leap starts with, 0.0 to 1.0. The game
//                     empties the weapon's charge between the two.
//   BluntLeap_Long    the leap was allowed by us, beyond the game's range.

// Our own checks on a leap the game has already said yes to.
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
  if !IsDefined(system) || !system.HasLeap() {
    // Not ours to judge (the mod is off, or another mod grants this leap).
    return true;
  };
  settings = system.Settings();
  charge = system.LeapCharge(weapon);

  // "Always charged": only a full charge leaps. A weapon without any charge
  // pool is let through, so a missing pool can never switch the leap off.
  if settings.alwaysCharged && charge < 1.0 {
    if GameInstance.GetStatPoolsSystem(weapon.GetGame()).IsStatPoolAdded(Cast<StatsObjectID>(weapon.GetEntityID()), gamedataStatPoolType.WeaponCharge) {
      return false;
    };
  };

  // Shorter range than the game's own, if the setting asks for it. A fully
  // charged stronger leap is not held back by it.
  if settings.leapRange < this.GetStaticFloatParameterDefault("maxDistToTarget", 15.0) - 0.01 && !(system.HasStrongerLeap() && charge >= 1.0) {
    if !IsDefined(DefaultTransition.GetTargetObject(scriptInterface, settings.leapRange, false)) {
      return false;
    };
  };

  stateContext.SetPermanentFloatParameter(n"BluntLeap_Charge", charge, true);
  stateContext.SetPermanentBoolParameter(n"BluntLeap_Long", false, true);
  return true;
}

// The game said no. With the stronger leap, a fully charged blunt weapon may
// still leap to an enemy beyond the game's range. Every other condition is
// the game's own, repeated here.
@addMethod(MeleeLeapDecisions)
private final const func BluntLeap_AllowLong(stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let system: ref<BluntLeapSystem>;
  let weapon: ref<WeaponObject>;
  let range: Float;
  let gameRange: Float;

  weapon = MeleeTransition.GetWeaponObject(scriptInterface);
  if !IsDefined(weapon) || !WeaponObject.IsBlunt(weapon.GetItemID()) {
    return false;
  };
  system = BluntLeapSystem.Get(scriptInterface.executionOwner.GetGame());
  if !IsDefined(system) || !system.HasStrongerLeap() {
    return false;
  };
  if !this.IsInMeleeState(stateContext, n"meleeChargedHold") || !MeleeTransition.MeleeAttackReleased(scriptInterface) {
    return false;
  };
  if this.m_driverCombatListener.IsMounted() {
    return false;
  };
  if EntityID.IsDefined(scriptInterface.localBlackboard.GetEntityID(GetAllBlackboardDefs().PlayerStateMachine.FinisherTarget)) {
    return false;
  };
  if !scriptInterface.HasStatFlag(gamedataStatType.CanMeleeLeap) {
    return false;
  };
  if !scriptInterface.IsOnGround() && !scriptInterface.HasStatFlag(gamedataStatType.CanMeleeLeapInAir) {
    return false;
  };
  if system.LeapCharge(weapon) < 1.0 {
    return false;
  };
  gameRange = this.GetStaticFloatParameterDefault("maxDistToTarget", 15.0);
  range = system.StrongRange(MinF(system.Settings().leapRange, gameRange));
  if range <= gameRange {
    return false;
  };
  if !IsDefined(DefaultTransition.GetTargetObject(scriptInterface, range, false)) {
    return false;
  };
  if IsDefined(DefaultTransition.GetTargetObject(scriptInterface, this.GetStaticFloatParameterDefault("minDistToTarget", 2.0), false)) {
    return false;
  };
  stateContext.SetPermanentFloatParameter(n"BluntLeap_Charge", 1.0, true);
  stateContext.SetPermanentBoolParameter(n"BluntLeap_Long", true, true);
  return true;
}

@wrapMethod(MeleeLeapDecisions)
protected const func EnterCondition(stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if wrappedMethod(stateContext, scriptInterface) {
    if this.BluntLeap_Allow(stateContext, scriptInterface) {
      return true;
    };
    // The original marked the leap as started just before it said yes.
    stateContext.SetPermanentBoolParameter(n"IsInMeleeLeapState", false, true);
    return false;
  };
  if this.BluntLeap_AllowLong(stateContext, scriptInterface) {
    stateContext.SetPermanentBoolParameter(n"IsInMeleeLeapState", true, true);
    return true;
  };
  return false;
}

// The game's own leap (MeleeLeapEvents.LeapToTarget) with a longer range. The
// travel time keeps the game's limits, so a longer leap is a faster one.
@addMethod(MeleeLeapEvents)
private final func BluntLeap_LongLeap(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>, range: Float) -> Bool {
  let owner: ref<GameObject> = scriptInterface.executionOwner;
  let target: ref<GameObject>;
  let targetPuppet: ref<ScriptedPuppet>;
  let toTarget: Vector4;
  let targetPos: Vector4;
  let angles: EulerAngles;
  let distance: Float;
  let minDistance: Float;
  let duration: Float;
  let rotationDuration: Float;

  target = DefaultTransition.GetTargetObject(scriptInterface, range, false, this.GetStaticFloatParameterDefault("leapTargetWithinAngle", 10.0));
  if !IsDefined(target) {
    return false;
  };
  targetPuppet = target as ScriptedPuppet;
  if IsDefined(targetPuppet) {
    targetPuppet.SetFinisherSoundPlayed(false);
  };
  toTarget = target.GetWorldPosition() - owner.GetWorldPosition();
  angles = Vector4.ToRotation(toTarget);
  if -angles.Pitch > this.GetStaticFloatParameterDefault("leapMaxPitch", 45.0) {
    return false;
  };
  distance = Vector4.Length(toTarget);
  minDistance = this.GetStaticFloatParameterDefault("minDistToTarget", 2.0);
  duration = LerpF((distance - minDistance) / (range - minDistance), this.GetStaticFloatParameterDefault("minAdjustmentDuration", 0.25), this.GetStaticFloatParameterDefault("maxAdjustmentDuration", 0.5), true);
  stateContext.SetConditionFloatParameter(n"LeapExitTime", duration - this.GetStaticFloatParameterDefault("attackStartupDuration", 0.3), true);

  rotationDuration = this.GetStaticFloatParameterDefault("rotationDuration", -1.0);
  this.m_isTargetKnockedOver = (target.GetWorldPosition().Z - owner.GetWorldPosition().Z) < 0.2 && StatusEffectSystem.ObjectHasStatusEffectOfType(target, gamedataStatusEffectType.Knockdown);
  this.GetSlotTransformToTarget(scriptInterface, target, duration, this.m_isTargetKnockedOver, targetPos, rotationDuration);
  rotationDuration = this.GetStaticFloatParameterDefault("rotationDuration", -1.0);
  if !SpatialQueriesHelper.IsTargetReachable(owner, target, targetPos, false, this.m_enableVaultFromLeapAttack) {
    return false;
  };

  scriptInterface.localBlackboard.SetBool(GetAllBlackboardDefs().PlayerStateMachine.MeleeLeap, true);
  if this.m_enableVaultFromLeapAttack {
    stateContext.SetPermanentBoolParameter(n"enableVaultFromleapAttack", true, true);
  };
  if this.m_isTargetKnockedOver {
    stateContext.SetPermanentBoolParameter(n"crouchAfterLeaping", true, true);
  };
  this.AdjustPlayerPosition(stateContext, scriptInterface, target, duration, this.GetStaticFloatParameterDefault("distanceRadiusToTarget", 0.9), rotationDuration, n"", true, targetPos);
  PlayerStaminaHelpers.ModifyStaminaBasedOnLeapAttackDistance(owner as PlayerPuppet, scriptInterface.IsOnGround(), distance, range);
  return true;
}

@wrapMethod(MeleeLeapEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let weapon: ref<WeaponObject>;
  let system: ref<BluntLeapSystem>;
  let settings: ref<BluntLeapSettings>;
  let stored: StateResultFloat;
  let long: StateResultBool;
  let exitTime: StateResultFloat;
  let target: ref<GameObject>;
  let perkData: ref<IBlackboard>;
  let owner: ref<GameObject>;
  let range: Float;
  let started: Bool;
  let distance: Float;
  let type: gamedataItemType;
  let lead: Float;

  wrappedMethod(stateContext, scriptInterface);

  stored = stateContext.GetPermanentFloatParameter(n"BluntLeap_Charge");
  long = stateContext.GetPermanentBoolParameter(n"BluntLeap_Long");
  stateContext.SetPermanentFloatParameter(n"BluntLeap_Charge", 0.0, true);
  stateContext.SetPermanentBoolParameter(n"BluntLeap_Long", false, true);

  if this.m_isFinisher {
    return;
  };
  weapon = MeleeTransition.GetWeaponObject(scriptInterface);
  if !IsDefined(weapon) || !WeaponObject.IsBlunt(weapon.GetItemID()) {
    return;
  };
  owner = scriptInterface.executionOwner;
  system = BluntLeapSystem.Get(owner.GetGame());
  if !IsDefined(system) || !system.HasLeap() {
    return;
  };
  settings = system.Settings();

  // The original sets this only when the leap really started.
  started = scriptInterface.localBlackboard.GetBool(GetAllBlackboardDefs().PlayerStateMachine.MeleeLeap);
  range = this.GetStaticFloatParameterDefault("maxDistToTarget", 15.0);
  if !started && long.valid && long.value && system.HasStrongerLeap() {
    range = system.StrongRange(MinF(settings.leapRange, range));
    started = this.BluntLeap_LongLeap(stateContext, scriptInterface, range);
    system.Log("Long leap, range " + FloatToStringPrec(range, 1) + " m, started=" + ToString(started));
  };
  if !started {
    return;
  };

  // 1. Distance leaped, for the distance damage bonus. The game records it
  //    for blades only. The player has not moved yet at this point.
  target = DefaultTransition.GetTargetObject(scriptInterface, range, false, this.GetStaticFloatParameterDefault("leapTargetWithinAngle", 10.0));
  perkData = GameInstance.GetBlackboardSystem(owner.GetGame()).Get(GetAllBlackboardDefs().PlayerPerkData);
  if IsDefined(target) && IsDefined(perkData) {
    distance = Vector4.Distance(target.GetWorldPosition(), owner.GetWorldPosition());
    perkData.SetFloat(GetAllBlackboardDefs().PlayerPerkData.LeapedDistance, distance, true);
  };

  // 2. The swing should land on arrival. The game starts it
  //    attackStartupDuration (0.3 s) before arrival, tuned for blades (a
  //    katana's strong attack hits 0.25 s after it starts; knives get their
  //    own 0.1 s for their 0.08 s). Blunt strong attacks hit after: fists and
  //    Gorilla Arms 0.19 s, one- and two-handed 0.29 s (stun batons 0.31 s),
  //    hammers 0.5 s. Each type has its own swing start (settings "Swing
  //    start"; defaults 0.21, 0.21, 0.3, 0.3, 0.5).
  type = WeaponObject.GetWeaponType(weapon.GetItemID());
  lead = system.SwingStartFor(type);
  exitTime = stateContext.GetConditionFloatParameter(n"LeapExitTime");
  if exitTime.valid && AbsF(lead - this.GetStaticFloatParameterDefault("attackStartupDuration", 0.3)) > 0.001 {
    stateContext.SetConditionFloatParameter(n"LeapExitTime", MaxF(exitTime.value - (lead - this.GetStaticFloatParameterDefault("attackStartupDuration", 0.3)), 0.0), true);
  };
  //    And the attack that ends the leap reaches at least the minimum leap
  //    reach (3.0 m, a katana's: fists and Gorilla Arms reach 1.5 m,
  //    one-handed and hammers 2.0 m, two-handed 2.5 m), plus any per-type
  //    reach bonus.
  system.AddLeapReach(weapon);

  if !stored.valid || stored.value <= 0.0 {
    system.Log("Leap, " + FloatToStringPrec(distance, 1) + " m, no charge");
    return;
  };

  // 3. Give the weapon back the charge the leap started with, so the hit
  //    gets the game's charged-attack bonus. Gorilla Arms are left alone:
  //    their charged punch is a separate attack of the game's.
  if system.OwnsChargeOf(weapon) || NotEquals(WeaponObject.GetWeaponType(weapon.GetItemID()), gamedataItemType.Cyb_StrongArms) {
    GameInstance.GetStatPoolsSystem(owner.GetGame()).RequestSettingStatPoolValue(Cast<StatsObjectID>(weapon.GetEntityID()), gamedataStatPoolType.WeaponCharge, stored.value * 100.0, null, true);
  };

  // 4. A fully charged leap with the stronger leap: its hit gets the extra
  //    effects. Armed for the flight plus the swing.
  if system.HasStrongerLeap() && stored.value >= 1.0 {
    system.ArmStrongLeap(2.0);
  };
  system.Log("Leap, " + FloatToStringPrec(distance, 1) + " m, charge " + FloatToStringPrec(stored.value * 100.0, 0) + "%");
}

// The leap ends. If it does not go on into its strong attack (no target hit,
// a block, a dodge), the extra reach for its punch comes off here; otherwise
// it comes off when that attack ends (BluntLeap_Charge.reds).
@wrapMethod(MeleeLeapEvents)
public func OnExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let system: ref<BluntLeapSystem>;
  wrappedMethod(stateContext, scriptInterface);
  if this.m_exitingToMeleeStrongAttack {
    return;
  };
  system = BluntLeapSystem.Get(scriptInterface.executionOwner.GetGame());
  if IsDefined(system) {
    system.RemoveLeapReach();
  };
}

@wrapMethod(MeleeLeapEvents)
public func OnForcedExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let system: ref<BluntLeapSystem>;
  wrappedMethod(stateContext, scriptInterface);
  system = BluntLeapSystem.Get(scriptInterface.executionOwner.GetGame());
  if IsDefined(system) {
    system.RemoveLeapReach();
  };
}
