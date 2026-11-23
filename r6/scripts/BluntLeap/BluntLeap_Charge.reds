// Blunt Leap: charging for blunt weapons that have no charge of their own.
//
// The pool is of the game's WeaponCharge type, so the game's own code does
// most of the work: MeleeChargedHoldEvents fills it while the attack is held,
// the melee crosshair draws its bar, and the damage rule adds the charged
// bonus. These hooks make sure the pool is there in time, show or hide the
// bar, flash it when full, and empty the pool again.
//
// Emptying matters: the game's own code never empties a weapon's charge (it
// clears the player's pool instead), and it switches the slow fallback decay
// off whenever a charge starts. Without these hooks a charge stays full for
// good. So ours is emptied:
//   - when the weapon is drawn;
//   - when a strong attack starts to be held (each hold starts from zero);
//   - when the hold ends without an attack (block, dodge, hit, release);
//   - when the attack ends, however it ends.
// A leap carries its charge through on its own (BluntLeap_Leap.reds).

// The weapon's crosshair appears: the weapon has just been drawn. The
// original decides here, once, whether to show the charge bar; later stance
// changes (block, aim, sprint) show it again if m_displayChargeBar is true.
@wrapMethod(CrosshairGameController_Melee)
protected cb func OnPreIntro() -> Bool {
  let weapon: ref<WeaponObject> = this.GetWeaponItemObject() as WeaponObject;
  let system: ref<BluntLeapSystem>;
  let pools: ref<StatPoolsSystem>;
  let ourType: Bool = false;
  let ours: Bool = false;
  let result: Bool;

  if IsDefined(weapon) {
    system = BluntLeapSystem.Get(weapon.GetGame());
    if IsDefined(system) {
      ourType = BluntLeapSystem.IsOurChargeType(weapon);
      system.NoteCrosshair(this);
      ours = system.PrepareCharge(weapon);
      if ours {
        system.ClearCharge(weapon);
      };
      system.RemoveLeapReach();
      system.StopGorillaCharge();
    };
  };

  result = wrappedMethod();

  if ourType {
    if !ours || !system.Settings().chargeBar {
      // No bar for this weapon. Cleared here too, so the game's stance
      // changes cannot bring it back (the original may have seen a pool that
      // is about to be removed, or one the setting hides).
      this.m_displayChargeBar = false;
      this.m_chargeBar.SetVisible(false);
    } else {
      if !this.m_displayChargeBar {
        // The pool was added a moment ago and the original did not see it
        // yet: do what it does when it finds one.
        pools = GameInstance.GetStatPoolsSystem(weapon.GetGame());
        this.m_weaponID = weapon.GetEntityID();
        this.m_displayChargeBar = true;
        this.m_meleeResourcePoolListener = new MeleeResourcePoolListener();
        this.m_meleeResourcePoolListener.Bind(this);
        pools.RequestRegisteringListener(Cast<StatsObjectID>(this.m_weaponID), gamedataStatPoolType.WeaponCharge, this.m_meleeResourcePoolListener);
        this.m_chargeBar.SetVisible(true);
      };
      this.SetChargeScale(0.0);
    };
  };
  return result;
}

// The charge changed. When a charge we added becomes full, the bar pulses once.
@wrapMethod(CrosshairGameController_Melee)
public func UpdateResourceValue(oldValue: Float, newValue: Float, percToPoints: Float) -> Void {
  let system: ref<BluntLeapSystem>;
  let weapon: ref<WeaponObject>;
  let pulse: ref<inkAnimDef>;
  let scale: ref<inkAnimScale>;
  wrappedMethod(oldValue, newValue, percToPoints);
  if newValue < 99.9 || oldValue >= 99.9 || !IsDefined(this.m_chargeBar) || !this.m_displayChargeBar {
    return;
  };
  weapon = this.GetWeaponItemObject() as WeaponObject;
  if !IsDefined(weapon) {
    return;
  };
  system = BluntLeapSystem.Get(weapon.GetGame());
  if !IsDefined(system) || !system.OwnsChargeOf(weapon) || !system.Settings().fullFlash {
    return;
  };
  scale = new inkAnimScale();
  scale.SetStartScale(new Vector2(1.5, 1.5));
  scale.SetEndScale(new Vector2(1.0, 1.0));
  scale.SetDuration(0.3);
  scale.SetType(inkanimInterpolationType.Quadratic);
  scale.SetMode(inkanimInterpolationMode.EasyOut);
  pulse = new inkAnimDef();
  pulse.AddInterpolator(scale);
  this.m_chargeBar.PlayAnimation(pulse);
}

// A strong attack starts to be held. Second chance to prepare the weapon
// (settings changed with the weapon in hand), and the charge starts from
// zero, before the original starts filling it.
@wrapMethod(MeleeChargedHoldEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let weapon: ref<WeaponObject> = MeleeTransition.GetWeaponObject(scriptInterface);
  let system: ref<BluntLeapSystem>;
  if IsDefined(weapon) {
    system = BluntLeapSystem.Get(weapon.GetGame());
    if IsDefined(system) && system.PrepareCharge(weapon) {
      system.ClearCharge(weapon);
    };
  };
  wrappedMethod(stateContext, scriptInterface);
  if IsDefined(system) {
    system.NoteChargeStarted(weapon);
    system.StartGorillaCharge(weapon);
  };
}

// The hold ends. The original keeps the charge only when the hold turns into
// a strong attack (m_clearWeaponCharge false); otherwise ours is emptied.
// A leap stores its charge before this and gives it back when it starts.
@wrapMethod(MeleeChargedHoldEvents)
public func OnExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let weapon: ref<WeaponObject>;
  let system: ref<BluntLeapSystem>;
  wrappedMethod(stateContext, scriptInterface);
  // Gorilla Arms' timed charge ends with the hold (a leap has read it by now).
  system = BluntLeapSystem.Get(scriptInterface.executionOwner.GetGame());
  if IsDefined(system) {
    system.StopGorillaCharge();
    system.NoteHoldEnded();
  };
  if !this.m_clearWeaponCharge {
    return;
  };
  weapon = MeleeTransition.GetWeaponObject(scriptInterface);
  if IsDefined(weapon) {
    system = BluntLeapSystem.Get(weapon.GetGame());
    if IsDefined(system) {
      system.ClearCharge(weapon);
    };
  };
}

// The hold is cut short (a block, a hit, a dodge): always empty.
@wrapMethod(MeleeChargedHoldEvents)
public func OnForcedExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let weapon: ref<WeaponObject>;
  let system: ref<BluntLeapSystem>;
  wrappedMethod(stateContext, scriptInterface);
  weapon = MeleeTransition.GetWeaponObject(scriptInterface);
  if IsDefined(weapon) {
    system = BluntLeapSystem.Get(weapon.GetGame());
    if IsDefined(system) {
      system.ClearCharge(weapon);
      system.StopGorillaCharge();
      system.NoteHoldEnded();
    };
  };
}

// An attack's hit window is over. The game takes the attack's charge cost
// here (on the wrong object, and blunt attacks have none); ours is emptied.
// A stronger leap's extra effects end here too.
@wrapMethod(MeleeAttackGenericEvents)
protected func ConsumeWeaponCharge(scriptInterface: ref<StateGameScriptInterface>, attackData: ref<MeleeAttackData>) -> Void {
  let weapon: ref<WeaponObject>;
  let system: ref<BluntLeapSystem>;
  wrappedMethod(scriptInterface, attackData);
  weapon = MeleeTransition.GetWeaponObject(scriptInterface);
  if !IsDefined(weapon) {
    return;
  };
  system = BluntLeapSystem.Get(weapon.GetGame());
  if !IsDefined(system) {
    return;
  };
  system.ClearCharge(weapon);
  // Gorilla Arms call this on every frame of the swing, so they are left to
  // the timer instead.
  if NotEquals(WeaponObject.GetWeaponType(weapon.GetItemID()), gamedataItemType.Cyb_StrongArms) {
    system.DisarmStrongLeap();
  };
}

// The attack ends, however it ends (the hit window may never be reached when
// it is interrupted). The damage has already taken the charge it needed, and
// a fist leap's punch its extra reach.
@wrapMethod(MeleeAttackGenericEvents)
public func OnExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let weapon: ref<WeaponObject>;
  let system: ref<BluntLeapSystem>;
  wrappedMethod(stateContext, scriptInterface);
  weapon = MeleeTransition.GetWeaponObject(scriptInterface);
  if IsDefined(weapon) {
    system = BluntLeapSystem.Get(weapon.GetGame());
    if IsDefined(system) {
      system.ClearCharge(weapon);
      system.RemoveLeapReach();
      // Thunder Breaker belongs to the leap's own attack only. Most weapons
      // already ended it with the hit window (ConsumeWeaponCharge); Gorilla
      // Arms end it here.
      system.DisarmStrongLeap();
    };
  };
}

@wrapMethod(MeleeAttackGenericEvents)
public func OnForcedExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let weapon: ref<WeaponObject>;
  let system: ref<BluntLeapSystem>;
  wrappedMethod(stateContext, scriptInterface);
  weapon = MeleeTransition.GetWeaponObject(scriptInterface);
  if IsDefined(weapon) {
    system = BluntLeapSystem.Get(weapon.GetGame());
    if IsDefined(system) {
      system.ClearCharge(weapon);
      system.RemoveLeapReach();
      // Thunder Breaker belongs to the leap's own attack only. Most weapons
      // already ended it with the hit window (ConsumeWeaponCharge); Gorilla
      // Arms end it here.
      system.DisarmStrongLeap();
    };
  };
}
