// Blunt Leap: charging for blunt weapons that have no charge of their own.
//
// The pool is of the game's WeaponCharge type, so the game's own code does
// the work: MeleeChargedHoldEvents fills it while the attack is held, the
// melee crosshair draws its bar, and the damage rule adds the charged bonus.
// These hooks only make sure the pool is there in time, show or hide the
// bar, flash it when full, and empty the pool after the attack.

// The weapon's crosshair appears: the earliest sure moment the weapon is in
// hand. The original decides here, once, whether to show the charge bar.
@wrapMethod(CrosshairGameController_Melee)
protected cb func OnPreIntro() -> Bool {
  let weapon: ref<WeaponObject> = this.GetWeaponItemObject() as WeaponObject;
  let system: ref<BluntLeapSystem>;
  let pools: ref<StatPoolsSystem>;
  let ours: Bool = false;
  let result: Bool;

  if IsDefined(weapon) {
    system = BluntLeapSystem.Get(weapon.GetGame());
    if IsDefined(system) {
      ours = system.PrepareCharge(weapon);
    };
  };

  result = wrappedMethod();

  if ours {
    if !system.Settings().chargeBar {
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
        this.SetChargeScale(0.0);
        this.m_chargeBar.SetVisible(true);
      };
    };
  };
  return result;
}

// The charge changed. When a charge we added becomes full, the bar pulses once.
@wrapMethod(CrosshairGameController_Melee)
public func UpdateResourceValue(oldValue: Float, newValue: Float, percToPoints: Float) -> Void {
  let system: ref<BluntLeapSystem>;
  let player: ref<GameObject>;
  let pulse: ref<inkAnimDef>;
  let scale: ref<inkAnimScale>;
  wrappedMethod(oldValue, newValue, percToPoints);
  if newValue < 99.9 || oldValue >= 99.9 || !IsDefined(this.m_chargeBar) {
    return;
  };
  player = this.GetPlayerControlledObject();
  if !IsDefined(player) {
    return;
  };
  system = BluntLeapSystem.Get(player.GetGame());
  if !IsDefined(system) || !system.OwnsChargeEntity(this.m_weaponID) || !system.Settings().fullFlash {
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
// (settings changed with the weapon in hand), before the original starts
// the charge.
@wrapMethod(MeleeChargedHoldEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let weapon: ref<WeaponObject> = MeleeTransition.GetWeaponObject(scriptInterface);
  let system: ref<BluntLeapSystem>;
  if IsDefined(weapon) {
    system = BluntLeapSystem.Get(weapon.GetGame());
    if IsDefined(system) {
      system.PrepareCharge(weapon);
    };
  };
  wrappedMethod(stateContext, scriptInterface);
}

// An attack's hit window is over. The game takes the attack's charge cost
// here; blunt attacks have none, so our pool is emptied whole, once. A
// stronger leap's extra effects end here too.
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
  if system.OwnsChargeOf(weapon) {
    this.ChangeStatPoolValue(scriptInterface, weapon.GetEntityID(), gamedataStatPoolType.WeaponCharge, -100.0, true);
  };
  // Gorilla Arms call this on every frame of the swing, so they are left to
  // the timer instead.
  if NotEquals(WeaponObject.GetWeaponType(weapon.GetItemID()), gamedataItemType.Cyb_StrongArms) {
    system.DisarmStrongLeap();
  };
}
