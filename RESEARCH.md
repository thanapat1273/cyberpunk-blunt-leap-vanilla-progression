# Blunt Leap: research and design notes

- **Status (2026-11-22):** research only. Nothing is built or installed.
- **Goal:** let V do the leap attack with blunt weapons, with Mod Settings options for how it unlocks and an optional charged mode.
- **Sources:** the game's 2.5 scripts (`CDPR-Modding-Documentation/Cyberpunk-Scripts`), the 2.5 tweak source (`Cyberpunk-Tweaks`) and this PC's compiled `tweakdb_ep1.bin`. Everything below is read from those unless marked **unverified**.
- **Still open:** the in-game feel test (§6).
- **Survey of existing mods:** done 2026-11-22 (§8). It changed §3 and §5: a real new perk is possible with Perk Addition Framework.

---

## 1. How the vanilla leap works

**The trigger** (`MeleeLeapDecisions.EnterCondition`, `meleeTransitions.script`):
- V is in `meleeChargedHold` (attack held longer than `HoldEnterDuration`, 0.2 s) and the attack button is released.
- V has the stat flag `CanMeleeLeap`. In the air, `CanMeleeLeapInAir` too.
- A target is between `minDistToTarget` (2 m) and `maxDistToTarget` (**15 m** in the 2.5 data).
- V isn't mounted. **There is no weapon-type check here.**

**What the leap is** (`MeleeLeapEvents`):
- It moves V to the target over 0.25–0.5 s (`AdjustPlayerPosition`), then hands over to `meleeStrongAttack` 0.3 s before arrival (0.1 s for knives).
- **There's no leap-specific attack.** The weapon's normal strong attack plays at the end.
- Stamina: 15 on the ground, 20 in the air (`player.staminaCosts`).
- Targets above 35° pitch are refused; unreachable targets are refused (`SpatialQueriesHelper.IsTargetReachable`).

**Who grants the flags:**
- **Flash and Thunderclap** (`NewPerks.Reflexes_Inbetween_Right_2`, Reflexes 9 tier). It's a *bridge* perk: it requires Mad Dash (a Dash sub-perk) and Seeing Double (a Blades sub-perk).
  - Effect 1: `ApplyStatGroupOnPlayer` with `Prereqs.BladeWeaponHeldPrereq` → `CanMeleeLeap` + `CanMeleeLeapInAir`.
  - Effect 2: `ModifyDamageWithLeapedDistance`, up to ×1.5 strong-attack damage at 20 m leaped.
- Mantis Blades grant `CanMeleeLeap` themselves. Three iconic mods and one weapon-mod status effect do too.

**The blade-only parts of the script:**
- `ShouldCheckForLeapableTarget` (`WeaponObject.IsBlade`) only adds extra target kinds (turrets, weakspots) and writes `LeapedDistance` for the damage bonus.
- The crosshair's leap-target highlight (`CrosshairGameController_Melee.UpdateTargetIndicator`) checks weapon types.

**Conclusion:** granting the two flags while a blunt weapon is held should make the leap work, ending in the blunt strong attack. `Prereqs.BluntWeaponHeldPrereq` already exists (weapon evolution Blunt). **Unverified:** how it looks and times with clubs and two-handed hammers.

## 2. Charging and the charge bar

- **Charged hold:** if the held weapon's `ChargeTime` stat is above 0, `MeleeChargedHoldEvents.OnEnter` fills the weapon's `WeaponCharge` pool at 100 / ChargeTime per second.
- **The bar:** the melee crosshair has a `chargeBar` widget. It's shown when the weapon has a `WeaponCharge` pool (`statPoolsSystem.IsStatPoolAdded`).
- **Who has a pool today:**
  - chainswords and stun batons: `BaseStatPools.TechMeleeCharge` (decays 15/s after 2 s);
  - Gorilla Arms: `StrongArmsCharge`;
  - Mantis Blades: `MantisBladesCharge`.
- **Blunt bases have none.** Some one-hand blunt presets reference `TechMeleeCharge` (check which before adding a pool).
- **`weaponObject.IsCharged()`** is the game's own "fully charged" test.
- **For a charged mode:** our own `StatPool` record (`enumName = "WeaponCharge"`, fast decay), added to the held blunt weapon at runtime only while the mode is on. The leap is then gated on `IsCharged()`. The native bar appears by itself.

## 3. The perk system

- **Perk IDs are a fixed built-in enum** (`gamedataNewPerkType`, 194 values). Every value has a live perk in the 2.5 database: there are no cut or spare IDs. A record with an unknown `enumName` can't be bought, because all ownership logic is keyed by the enum (`PlayerDevelopmentData.m_attributesData[].unlockedPerks`).
- **The perk screen uses one generic layout.** Each slot (`gamedataNewPerkSlotType`, 63 slots) has a container. A page shows the slots its attribute has perks for and hides the rest (`BuildPerkTree`).
- **Wires are pre-authored per slot pair** in the widget (`NewPerksWireConnection`). They show when the target slot's perk requires the source slot's perk.
- **Free slots on the Body page:**
  - `Right_Perk_3_3`, `Right_Perk_3_4`: sub-perk slots under **Quake** (Body 15). Reflexes uses them, so the wires from the milestone exist.
  - `Inbetween_Right_2`: the tier-2 bridge slot. **It's the slot Flash and Thunderclap uses on the Reflexes page.**
  - the whole centre column at tier 2, `Left_Perk_2_2`, `Central_Perk_3_3`, `Master_Perk_4`.
- **Requirements across attributes:**
  - unlocking and buying scan every attribute (`FindNewPerk`), so a Body perk requiring Dash would work;
  - selling a parent only checks children in the same attribute (`CheckIfAllNewPerkParentSold`), so Dash could be refunded while the child is owned;
  - the screen looks required perks up among the current page's perks only (`GetCachedPerkItemLogicController`), so a foreign requirement gives a null there.
- **Node looks** (`NewPerksPerkItemLogicController.UpdateState`): RequirementNotMet (shows the needed attribute level), Locked (lock icon), Default, PartiallyInvested, Bought, FullyInvested.
- **Tooltip** (`NewPerkTooltipController`): a state line (Locked / Not purchased / Purchased) and an "unlock info" line (`m_unlockInfoWrapper`, `m_unlockPointsText`, `m_unlockPointsDesc`).
- **Clicks** go through `NewPerksScreenLogicController.OnNewPerkClickEvent` (buy and sell requests by perk type).

**A real new perk is possible with Perk Addition Framework** (PAF, Nexus 22758, v1.0.1 for 2.5; source read 2026-11-22, `github.com/JonnesTT/Cyberpunk_PerkAdditionFramework`, no licence file):
- **How:** a `ScriptableService` calls Codeware's `Reflection.GetEnum(n"gamedataNewPerkType").AddConstant(enumName, n)` for every `NewPerk` record whose `enumName` isn't in the enum yet, then `TweakDBManager.UpdateRecord`. The record must be named `NewPerks.<enumName>`.
- **Result:** the perk is a genuine one. It sits in an existing empty slot, and buying, refunding, the lock look, the tooltip and the wires are all native.
- **Respec:** its `perk_reset.reds` wraps `PlayerDevelopmentData.ResetNewPerks` and `OnRestored`, because vanilla only loops over the original enum range.
- **To check before relying on it:** the added IDs are numbered in record order at each launch. Confirm that a saved perk still maps to the same perk after the mod list changes (the other PAF mods tell users to refund before uninstalling).
- **Without PAF**, the fallback is a "virtual" perk: our own saved flag and our own buy, refund and respec handling, shown in a hidden slot container. Much more work.

## 4. Blunt perks today (Body tree, right branch)

| Slot | Perk | Tier |
|---|---|---|
| `Right_Milestone_2` | Wrecking Ball | Body 9 |
| `Right_Perk_2_1` … `2_4` | Fly Swatter, Kinetic Absorption, Clapback, Breakthrough | Body 9 |
| `Right_Milestone_3` | Quake | Body 15 |
| `Right_Perk_3_1`, `3_2` | Epicenter, Aftershock | Body 15 |
| `Inbetween_Right_3` | Ripple Effect (needs Calm Mind + Aftershock) | Body 15 |
| `Master_Perk_5` | Finisher: Savage Sling | Body 20 |

Reflexes, for the bridge: Dash = `Reflexes_Central_Milestone_2` (Reflexes 9); its sub-perks are Mad Dash, Can't Touch This, Mean Streak, Steady Grip.

## 5. Design direction (to confirm with the user)

**One core, four unlock rules.** The effect is a single gameplay package (flags while a blunt weapon is held). A small script system decides whether V has it, from the Mod Settings choice:

| # | Unlock rule | Work |
|---|---|---|
| 1 | Always | trivial |
| 2 | Owning an existing perk | light |
| 3 | A new sub-perk under Quake (`Right_Perk_3_3`) | light with PAF: one TweakXL record |
| 4 | A new bridge perk that needs Dash | light-to-medium with PAF: the record, plus the cross-tree rule (lock without Dash, refund when Dash is sold) and the page's handling of a foreign requirement |

**The bridge look (option 4), three levels:**
- **A. Lock and requirement line:** native Locked state on the node until Dash is owned; the tooltip's own unlock line reads "Requires Dash (Reflexes)". Light.
- **B. A plus a small Reflexes badge** on the node. Light.
- **C. A wire to a "ghost" Dash marker** in the empty centre column, using the game's own wire, mirrored by a marker on the Reflexes page. Medium; most of the cost is visual tuning.

**Two attack modes:**
- **Quick:** vanilla behaviour (hold past 0.2 s, release).
- **Charged:** the bar must be full first.

**Per-weapon tuning** that blades don't need: leap range for blunt, and the strong-attack start time for slow hammers.

## 6. First step before any building

**An in-game feasibility test (5 minutes).** With a bat or hammer drawn, run in the CET console:

```lua
Game.GetStatsSystem():AddModifier(GetPlayer():GetEntityID(), RPGManager.CreateStatModifier(gamedataStatType.CanMeleeLeap, gameStatModifierType.Additive, 1)) Game.GetStatsSystem():AddModifier(GetPlayer():GetEntityID(), RPGManager.CreateStatModifier(gamedataStatType.CanMeleeLeapInAir, gameStatModifierType.Additive, 1))
```

Then hold and release a strong attack at an enemy 3–10 m away. Try a one-handed club, a two-handed club and a hammer. The modifier lasts until the save is reloaded.

## 7. Implementation practices to follow

- **Data first:** the effect as a TweakXL `GameplayLogicPackage` that copies the vanilla perk's structure. Scripts only decide when it applies.
- **Wrap, never replace** (`@wrapMethod`), and call the original first. Touch as few functions as possible: `MeleeLeapDecisions.EnterCondition` (charged gate, blunt range) and `MeleeLeapEvents.OnEnter` (hammer timing) at most.
- **No edits to vanilla records or `.inkwidget` files.** UI changes are injected at runtime (Codeware), so other UI mods don't clash.
- **Ownership of a virtual perk** as a quest fact (survives uninstall harmlessly), with refunds on perk reset and attribute respec.
- **Settings** through Mod Settings with safe defaults; the mod works without it.
- **Check against installed mods:** Better Stealth and RPO touch takedowns, not the leap; nothing installed wraps `MeleeLeapDecisions` today (re-check at build time with `MOD-SHEET.xlsx`, Script hooks).
- **Verify every assumption in game first** (knowledge base rule), then offline compile, then test.

## 8. Existing mods (survey 2026-11-22; Nexus pages read, no files downloaded)

**The same feature already exists:**
- **More Melees More Fun** (Nexus 14910, v2.0.1 for 2.5): "Leap Attack works with any melee weapon" and only needs Mad Dash. Part of a larger perk-extension mod with Mod Settings; needs "More Guns More Fun - Core".
- **Air Leap - Enhanced Leaping** (25888, works on 2.5): leap with any melee weapon, also mid-air, with distance and duration multipliers.
  - It uses `@replaceMethod(MeleeLeapDecisions)`, which **broke Gorilla Arms quick finishers**. A user fixed it by wrapping instead and passing finisher cases straight to the original. Test that case in ours.
  - Other reports: a crash when a Gorilla Arms leap lands; the leap misses moving targets; obstacles interrupt it.
- **Leap With Any Melee Weapon** (inside 15162): a smaller version by the same author.
- **Better Melee** (2456, pre-2.0): a useful list of leap bugs (minimum leap range larger than heavy-attack range, swing passing over crouched targets).

**None of them** has a Body-tree perk, a bridge perk, a blunt-only scope or a charged mode with the native bar. That's what this mod would add.

**Body slots already taken by PAF mods** (avoid them):
- Running Man (26611): `Left_Milestone_1` and `Left_Perk_1_x`.
- HMG Carry Body Perk (27649): `Left_Perk_2_2`.

Our candidates (`Inbetween_Right_2`, `Right_Perk_3_3`, `Right_Perk_3_4`) are free. PAF logs a warning when two mods use one slot.

**Mods likely to interact** (none installed here):
- **Dash Fix** (16272): rewrites Mad Dash and the dash auto-aim.
- **Melee Attacks Fixes And Enhancements** (16921) and **Melee Attack Variety** (32817): change jump, sprint, crouch and strong attacks.

**Charge bars elsewhere:** no mod reuses the vanilla melee bar. Katana Pack 2 (36164), Fortified Ankles Charge Indicator (39122, CET) and Nitrous (20675, Codeware) draw their own. HUD overhauls such as Project E3 restyle the vanilla crosshair bar, so ours would follow the user's HUD automatically.

**Not verified:** the internals of More Melees More Fun and Air Leap (nothing was downloaded).

## 9. The perk screen's real geometry and lines (read from the game's widget, 2026-11-22)

Source: `base\gameplay\guiullscreen\perks
ew_perks.inkwidget`, unbundled with WolvenKit 10 and converted to JSON.

- **A milestone cluster** is a 632 × 332 box. The milestone sits in the middle; its four sub-perk slots sit in the corners:
  - `_1` bottom-right, `_2` bottom-left, `_3` top-right, `_4` top-left.
- **On the right (blunt) branch the left side faces the centre.** So Kinetic Absorption (`Right_Perk_2_2`) is the lower inner perk and **Breakthrough (`Right_Perk_2_4`) is the upper inner perk**.
- **A bridge slot** sits between two columns, **level with the upper sub-perk row**. `Inbetween_Right_2` is therefore right beside Breakthrough.
- **Pre-drawn lines into `Inbetween_Right_2`:** only from `Right_Perk_2_2` (Kinetic Absorption's slot) and `Central_Perk_2_1` (the centre column's lower-right slot, where Mad Dash sits on the Reflexes page). Both climb diagonally. Nothing comes from `Right_Perk_2_4`.
- **Bridge slots have no outgoing lines.**
- **Other pre-drawn lines that matter:**
  - `Central_Milestone_2` → `Central_Perk_2_1` … `2_4`;
  - `Right_Milestone_3` → `Right_Perk_3_3` and `3_4`;
  - sub-perk pairs `_1` ↔ `_3` and `_2` ↔ `_4`.
- **Any pre-drawn line can be switched on by our own code** (a method added to `NewPerksPerkContainerLogicController` can reach its line list). A line between two slots that have none must be drawn by us.
- **Body's centre column is empty at tier 2**: `Central_Milestone_2` and `Central_Perk_2_1` … `2_4` are all free.
- **Sub-perks always have one level in vanilla** (134 of 134). A two-level sub-perk is an untested UI path.

## 10. Perks checked for the design

- **Breakthrough:** "−X% enemy Armor for Y sec after hitting them with a Strong Attack." It's the blunt branch's Strong Attack perk. Data: an `AddStatusEffectToAttackEffector` with the condition `Perks.IsHitStrongAttack`, applied while `Prereqs.BluntWeaponHeldPrereq` holds.
- **Wrecking Ball:** level 1 is −15% stamina cost for Baton, Fists, One-Hand Blunt, Strong Arms (Gorilla Arms), Two-Hand Blunt and Two-Hand Hammer. That list is what "blunt" means to the game. Level 2 unlocks the sprint-and-block shoulder charge ("barrel into enemies… a chance to knock them down").
- **Mad Dash, verified:** its data package is empty; the effect is in script (`DodgeEvents.OnEnter`).
  - A dash aimed at a hostile within range becomes a dash *to* them. Range: 5 m, **doubled to 10 m with Mad Dash**.
  - The travel time is 0.05–0.25 s, **capped at 0.25 s**. So a 10 m dash takes the same time as a 5 m one: up to twice as fast. The user's impression is correct, as a side effect of range, not a speed stat.
- **The leap uses the same formula:** 0.25–0.5 s over 2–15 m, capped. A longer leap for our upgrade perk would be faster on average for the same reason.
  - The cap distance is a shared setting. Raising it in data would also speed up blade leaps, so the longer leap has to be handled in our own wrapper, for our case only.

## 11. EMP on crit

- **Yinglong:** `Effectors.TriggerAttackOnTargetEffect`, 6.6% chance on ranged hits, attack `Attacks.YinglongEMP` (a `BaseEMPExplosion`): 3 m radius, status `CommonEmpGrenade`, damage = the weapon's own Electrical damage × 10.
- **A closer precedent:** a Phantom Liberty axe triggers `Attacks.VBAxeEMP` on **critical thrown hits** (conditions: `CriticalHit`, target not defeated). Radius 3 m, the weapon's Electrical damage × 1.33.
- **Both scale from the weapon's Electrical damage.** A physical bat has none, so ours needs its own attack record that takes a share of the weapon's **physical** damage as Electrical.
- **The explosion can hurt the player** (`playerIncomingDamageMultiplier` 0.6–0.9). At melee range ours must set it to 0.
- **`Perks.IsHitACritical`** already exists as a condition.

## 12. Knock-away, stagger and swing direction

- **Every melee attack record has `attackDirection`** (`UpToDown`, `RightToLeft`, `LeftToRight`, `Center`…) and `hitReactionSeverityMin/Max` (0–3).
- **How the enemy's reaction is chosen** (`HitReactionComponent.GetReactionType`): Twitch → Impact → Stagger → Knockdown by severity. It's blocked by melee-resistance, knockdown immunity, a too-large level gap, and the player being exhausted. "Massive" enemies only twitch.
- **`hitFlag.ForceKnockdown`** raises the severity to 3. `AddHitFlagToAttackEffector` adds a flag from data alone.
- **The game's own "send flying" routine** is the Gorilla Arms one-punch (`ProcessOnePunchAttackHitImpact`): `CreateForceRagdollEvent`, then `CreateRagdollApplyImpulseEvent(hitPosition, direction × impulse, 1.0)` with an upward part.
  - RPO replaces both of those global functions, so its push settings apply to anything that uses them.
- **Best extension point: our own effector class** (like `ModifyDamageWithLeapedDistance`): a small script class named in a data record, run only when its hit conditions pass. It needs no wrapper on the hit-reaction code, which RPO and Relentless both already wrap.
- **Direction from the swing:** read `attackDirection` from the hit's attack record, turn it into a push relative to V's facing, and blend it with the V-to-target direction.
- **Still to verify in the build phase:** the cleanest way to guarantee a Stagger when the launch doesn't happen (raise the hit's minimum severity, or apply the stagger status).

## 13. Charge feedback the game already has

- The crosshair bar (with a percentage text at each end).
- Charged-hold starts a controller rumble loop and the trigger effect `te_wea_melee_charge`.
- Ready-made effector classes include `playFXEffector`, `setTimeDilationEffector`, `applyShaderEffector` and `triggerAttackByRandomChanceEffector`.
- A stat-pool listener can tell us the moment the charge reaches 100%.

## 14. Vanilla numbers to tune against (read 2026-11-22)

**Charge:**
- Charged hold starts after 0.2 s of holding (`HoldEnterDuration`).
- Vanilla melee charge times: stun batons **0.5 s, 0.75 s and 1.0 s** (three variants), chainsword **1.2 s**.
- Stun batons and Gorilla Arms already have their own charge pools. A charged mode should reuse theirs, not add one.
- **The damage system already rewards charge** (`damageSystem.script`): damage × (1 + `ChargeMultiplier` × charge × 1.33). Melee `ChargeMultiplier` is 0.25, so a full charge is **+33%**, and a partial charge proportionally less. Any blunt weapon given a charge pool gets this automatically.

**Strong attacks:**
- All strong attacks deal ×1.5.
- The hit lands this long after the swing starts: one-handed blunt 0.29 s, two-handed blunt 0.29 s, **hammer 0.5 s**.
- The leap hands over to the swing 0.3 s before arrival. So one- and two-handed hits land on arrival, and a **hammer's lands about 0.2 s late** unless we start it earlier.
- Hit severity (0–3): one-handed 0–2, two-handed 1–3, hammer 2–3. Hammers already always stagger and can knock down.

**The blade leap:** range 2–15 m; travel 0.25–0.5 s; stamina 15 (20 in the air); damage bonus up to +50% at 20 m leaped (so +37.5% at the 15 m limit).

**Blunt perks:** Fly Swatter −40% ranged damage while blocking; Kinetic Absorption +10% stamina and +30% damage for 5 s; Clapback +100% knockdown chance on defensive attacks (10 s cooldown); **Breakthrough −40% armour for 7 s**; Aftershock +30 stamina; Ripple Effect +15% health.

**EMP precedents:** Yinglong 6.6% chance per hit, 3 m, its Electrical damage × 10 (tiny per-bullet damage). The Phantom Liberty axe: on crit thrown hits, 3 m, Electrical × 1.33. The EMP status (`CommonEmpGrenade`) adds an extra hit on mechanical enemies, netrunners and exoskeleton users.

**Enemy classes:** archetypes `HeavyMeleeT2/T3` and `HeavyRangedT2/T3` are the "heavy" enemies. Rarities include `Boss` and `MaxTac`. `IsMassive()` enemies only twitch.

**Dash to an enemy:** 5 m (10 m with Mad Dash), at most 0.25 s.

