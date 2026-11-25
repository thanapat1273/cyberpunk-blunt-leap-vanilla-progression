# Blunt Leap: the agreed design (spec)

- **Status (2026-11-22):** design agreed with the user; all three build steps are written and compile; the first build was play-tested and the second build is installed. Perk names: **Battering Ram** and **Thunder Breaker**.
- **Code:** `github.com/thanapat1273/cyberpunk-blunt-leap-vanilla-progression`
- **Where things come from:** the user's own words are in [`DESIGN-NOTES.md`](DESIGN-NOTES.md) (decisions D1–D39; kept locally, not in the repository). The game facts are in [`RESEARCH.md`](RESEARCH.md).
- **If this file and the notes disagree, the notes win.** Fix this file.

---

## 1. What the mod does

V can do the leap attack with every weapon type on the game's blunt list: stun batons, fists, one-handed blunt, Gorilla Arms, two-handed blunt and hammers.

It adds two perks to the Body tree:

| Perk (working name) | Cost | What it gives |
|---|---|---|
| **Battering Ram** ("Blunt leap" in older notes) | 1 perk point | The blade leap, for blunt weapons: releasing a held strong attack at an enemy 2–15 m away leaps to them. Works in mid-air. Up to +50% damage with distance. |
| **Thunder Breaker** ("Stronger leap" in older notes) | 1 perk point | On a **fully charged** leap: +50% range (22.5 m) and faster travel; an EMP burst on a crit; a strong chance to send the enemy flying, or else a guaranteed stagger. |

## 2. Where the perks sit (Layout 1)

- **Blunt leap:** the tier-2 bridge slot (`Inbetween_Right_2`), level with Breakthrough and right beside it.
- **Stronger leap:** the centre column's upper-right slot (`Central_Perk_2_3`), on Blunt leap's other side.
- **Lines:** two short ones drawn by the mod (Breakthrough to Blunt leap, Blunt leap to Stronger leap).
- **Vanilla perks keep their places.**
- **Requirements:** Blunt leap needs Breakthrough and, by default, Dash at level 2. Stronger leap needs Blunt leap.
- **The Dash requirement's look (D30–D33):** the game's locked look and the tooltip line, plus a small Dash box (the game's perk box at 60%) under Blunt leap, joined by the game's own wire. Switchable in settings ("Dash marker").

## 3. Unlock rule (one setting, applies at the next game start)

| Choice | Needs Dash 2 | Needs the perks | Result |
|---|---|---|---|
| **a** (default) | yes | yes | Whatever the owned perks give |
| **b** | no | yes | Whatever the owned perks give |
| **c** | no | no | Leap and stronger leap, always. Perk nodes hidden |
| **d** | no | no | Leap only, always. Perk nodes hidden |

- **Automatic refund:** at load, any point spent on a perk whose rule is no longer met is refunded. Examples: switching back to (a) without Dash; switching to (c) or (d).

## 4. Charge behaviour

One setting: **"Always charged" mode**, **off by default**. Off: any heavy attack leaps, as with blades, and a full charge does the stronger leap. On: only a full charge leaps.

| "Always charged" | Stronger leap | Partial charge | Full charge | Bar |
|---|---|---|---|---|
| On | not owned | normal strong attack | leap | shown |
| On | owned | normal strong attack | stronger leap | shown |
| Off | not owned | leap | leap | none |
| Off | owned | leap | stronger leap | shown |

- **The bar** is the game's own melee crosshair bar. Blunt weapons get their own charge pool; the chainsword's isn't touched.
- **Stun batons** already have a charge and keep it. **Gorilla Arms** do not charge by holding in the game; this mod gives them a timed charge of their own (D51, below).
- **Full-charge damage bonus:** the game's own rule for charged melee weapons, +33% at full charge and proportionally less below. Kept.

## 5. Settings and defaults (all in Mod Settings)

Layout since 2026-11-24 (D76): 46 options in 9 groups, in this order. An option marked "shown while X" is hidden while the switch X is off (`ModSettings.dependency`). Variable names never change, so saved values carry over.

**1. General**: Enabled (On); Unlock rule (Perks; Battering Ram needs Dash); Dash box on the perk screen (On).

**2. Features** (the on/off switches)

| Setting | Default |
|---|---|
| Leap in mid-air | On |
| Leap only when fully charged (was "Always charged") | Off |
| Charge bar | On |
| EMP on a crit | On |
| Send flying (new, D76) | On |
| Stagger when not sent flying | On |
| Push follows the swing direction | On |
| Non-lethal throws (new, D77) | Off |

**3. Battering Ram: Leap**: Leap range 15 m; Distance damage bonus up to +50% at 20 m; Minimum leap reach 3.0 m.

**4. Charge**: Full-charge damage bonus +33%; Charge speed under Sandevistan Full; Charge time: fists 0.5 s, Gorilla Arms 0.75 s, one-handed 0.75 s, two-handed 1.0 s, hammers 1.2 s; Full charge: sound On, rumble On, bar flash On (shown while Charge bar).

**5. Thunder Breaker**: Extra range +50%; Hit stop 0.15 s.

**6. Thunder Breaker: Send flying** (shown while Send flying, except the last): chance in combat 80%, on heavy enemies 30%, force 20%; chance unalerted 80%, on heavy enemies 30%, force 20%; Small push at an idle spot 6% (shown while Stagger when not sent flying).

**7. Thunder Breaker: EMP** (shown while EMP on a crit): Radius 3 m; Damage 100% of the weapon's hit, as Electrical, not scaled by the crit, charge or distance; never hurts V.

**8. Advanced: swing and reach per weapon**: Swing start: fists 0.21 s, Gorilla Arms 0.21 s, one-handed 0.3 s, two-handed 0.3 s, hammers 0.5 s; Reach bonus 0 m for each.

**9. Troubleshooting**: Write a log (Off).

- **Never launched:** bosses, MaxTac and "massive" enemies.
- **Why the EMP doesn't scale with the crit:** a fully charged crit leap already stacks strong attack ×1.5, full charge +33%, distance up to +50% and the crit itself, roughly four times a normal strong attack.

## 6. How it's built (outline)

| Part | How | Notes |
|---|---|---|
| The leap ability | A TweakXL gameplay package: `CanMeleeLeap` and `CanMeleeLeapInAir` while `Prereqs.BluntWeaponHeldPrereq` holds | Copies the vanilla perk's structure |
| The two perks | TweakXL `NewPerk` records in free slots, made real by **Perk Addition Framework** | Native buying, refunding, lock look and tooltip |
| Unlock rule and refunds | A small redscript system: reads the setting at load, applies or removes the package, refunds unmet perks | Wraps as little as possible |
| Dash requirement | Scripted cross-tree rule: lock without Dash 2; refund if Dash is sold | The game doesn't link perks across pages |
| The two lines | Runtime UI (Codeware) on the perk screen | No `.inkwidget` edits |
| Charge pool and bar | Our own `StatPool` record (type `WeaponCharge`, fast decay), added to the held blunt weapon at runtime | The native bar appears by itself |
| Charged gate, longer leap, hammer timing | `@wrapMethod` on `MeleeLeapDecisions.EnterCondition` and `MeleeLeapEvents.OnEnter`, original called first | Never `@replaceMethod`: that broke Gorilla Arms finishers in another mod |
| EMP on crit | Data: `TriggerAttackOnTargetEffect` with a crit condition and our own EMP attack record | |
| Launch, stagger, swing direction | Our own effector class, run by hit conditions | No wrapper on the hit-reaction code that RPO and Relentless wrap |
| Full-charge feedback | A stat-pool listener at 100%: sound, bar flash, rumble, optional screen pulse | |
| Settings | Mod Settings (works without it, on defaults) | |

**Requirements:** RED4ext, redscript, TweakXL, Codeware, Perk Addition Framework (new); Mod Settings optional. All but the framework are installed.

## 7. Before and during the build: things to verify in game

1. **The feel test** (`RESEARCH.md` §6): the leap with a one-handed club, a bat and a hammer.
2. **Perk Addition Framework:** a bought perk survives a change in the mod list (its added IDs are numbered at each launch).
3. **Gorilla Arms:** quick finishers still work, and a leap landing doesn't crash (both broke in a similar mod).
4. **Stun batons and Gorilla Arms** with their own charge under each charge rule.
5. **The stagger guarantee:** which mechanism works (raise the hit's minimum severity, or apply the stagger status).
6. **With RPO and Relentless installed:** a launched enemy behaves well; no double impulses.
7. **Sounds and the screen pulse:** auditioned from the game's existing ones.
8. **Mouse and controller** on the perk screen with the two drawn lines.

## 8. Still open

- Which Dash-requirement look to keep (§2), decided in testing.
- **The Blunt leap icon is done** (D25, version 3): `art/blunt-leap-icon.png`, packed into `archive/pc/mod/BluntLeap.archive` by `tools/pack_icons.sh` and used by the perk (`UIIcon.BluntLeap_Leap`).
- **The Stronger leap icon is done** (D29): `art/stronger-leap-icon.png`, the game's In Charge icon with its bullet replaced by Kinetic Absorption's fist (built by `tools/make_stronger_icon.py`), in the same archive and used by the perk (`UIIcon.BluntLeap_Stronger`).
- Neither icon has been seen in game yet.

## 9. Build steps

| Step | Contents | State |
|---|---|---|
| 1 | Leap on all blunt weapons, range and hammer timing, distance bonus, charge pool and bar, "Always charged" mode, settings | written; compiles; **not yet tested in game** |
| 2 | Stronger leap's effects: longer and faster leap, EMP on crit, send flying or stagger with swing direction, hit stop, full-charge feedback, scalable charge bonus | written; compiles; **not yet tested in game** |
| 3 | The two perks (Perk Addition Framework), unlock rule a–d, refunds, Dash requirement, the two lines, texts, both perk icons | written; compiles; **not yet tested in game** |

Per the user's decision (D27) all three steps are tested together, in one go. The test list is in [`TESTING.md`](TESTING.md).

### What is built

| Part | File | Hooks |
|---|---|---|
| Data: leap ability, air leap, distance bonus, charge pool, impact effector, EMP attack, the two perks | `r6/tweaks/BluntLeap/BluntLeap.yaml` | 22 entries; 21 new records under `BluntLeap.`, `NewPerks.BluntLeap_` and `UIIcon.BluntLeap_`, and one append to `NewPerks.BodyAttributeData.perks` |
| Settings (28) | `BluntLeap_Settings.reds` | none |
| System: unlock rule, ownership, packages, refunds, charge, full-charge sound and rumble | `BluntLeap_System.reds` | none |
| Leap: range and "Always charged" gate, long leap, distance leaped, hammer timing, charge carried through the leap | `BluntLeap_Leap.reds` | wraps `MeleeLeapDecisions.EnterCondition`, `MeleeLeapEvents.OnEnter` |
| Charge: pool in time, bar shown or hidden, bar flash, charge emptied at draw, hold start, hold end and attack end | `BluntLeap_Charge.reds` | wraps `CrosshairGameController_Melee.OnPreIntro` and `UpdateResourceValue`, `MeleeChargedHoldEvents.OnEnter`, `OnExit`, `OnForcedExit`, `MeleeAttackGenericEvents.ConsumeWeaponCharge`, `OnExit`, `OnForcedExit` |
| Stronger leap's hit: EMP, send flying, stagger, hit stop | `BluntLeap_Impact.reds` | none: an effector class named in a data record |
| Perks: Dash requirement, refunds, ownership changes, tooltip line | `BluntLeap_Perks.reds` | wraps `PlayerDevelopmentData.UnlockNewPerk`, `IsNewPerkUnlocked`, `CanNewPerkBeBought`, `BuyNewPerk`, `SellNewPerk`, `ForceSellNewPerk`, `ResetNewPerks`; `PerkDisplayTooltipController.UpdateRequirements` |
| Perk screen: hidden nodes, the locked look, the three wires, the Dash box | `BluntLeap_PerkScreen.reds` | wraps `NewPerksScreenLogicController.AttachSlotControllers`, `BuildPerkTree`, `ReevaluatePerkAvailability`, `OnNewPerkUnlocked`, `OnNewPerkBought`, `OnNewPerkSold`, `IndicateUnmaxedPerksInPath`, `StopPathToTargetPerkAnimations` |
| Texts (English) | `BluntLeap_Texts.reds` | none: Codeware localization |
| The two perk icons: a 256 x 116 texture (each icon in its own 128 px cell) and a two-part atlas | `archive/pc/mod/BluntLeap.archive` | none; two new files under `bluntleap\gui\icons\` |

Every wrapper calls the original first. Nothing is replaced. Finisher leaps and non-blunt weapons pass through untouched.

### How the main pieces work

- **Who has what.** The system reads the unlock rule once per loaded save. With rule (a) or (b) it asks the game whether the two perks are bought; with (c) or (d) it grants without perks. It then applies or removes four data packages on the player.
- **The Dash requirement** is scripted, not a listed perk requirement: the perk screen cannot handle a required perk from another page. Without Dash at level 2 the Blunt leap node shows as locked, cannot be bought, and its tooltip says "Requires Dash (Reflexes 9) at level 2".
- **Refunds.** 1.5 s after a save loads, and whenever Dash is sold: if the rule uses no perks, or Dash is required and missing, both perks are sold by force and their points come back.
- **The long leap.** When the game refuses a leap, our wrapper allows it if the weapon is blunt, fully charged, the stronger leap is owned and an enemy is within the longer range. The leap itself repeats the game's own leap steps with that range.
- **The stronger hit.** A fully charged leap arms a 2 s window. The effector runs on the player's strong melee hits at the `ProcessHitReaction` stage: the crit is known and the enemy has not picked its reaction yet.
  - EMP on a crit, once per leap: the Yinglong explosion with our own damage value and no damage to V.
  - Send flying: `ForceKnockdown` plus the game's ragdoll and impulse events, sized like the Gorilla Arms knockout punch. The direction follows the attack record's swing direction.
  - Otherwise the hit's minimum severity is raised to 2 (stagger).
- **Texts** come from Codeware's localization; the perk records name them by plain text key.

### Second build (2026-11-22)

**Fixes from the first play test (message 16):**

- **Send-flying force:** default 20% (was 100%: far too strong).
- **The charge bar showed although switched off.** The game's crosshair shows the bar again on every stance change (block, aim, sprint) whenever it once decided to show it. Now the bar is switched off at that decision, so stance changes cannot bring it back.
- **The charge got stuck at full, and every leap became a stronger leap.** Two causes:
  - A weapon keeps its entity when it is holstered and drawn again. The first build only remembered the last weapon drawn, so after a switch it lost track of its own charge and stopped emptying it.
  - The game never empties a weapon's charge itself: it clears the player's pool instead, and turns the fallback decay off whenever a charge starts.
  - **Now:** whether a charge is ours is read from the weapon itself (a blunt weapon whose record has no charge pool), and our modifiers are remembered per weapon. Ours is emptied when the weapon is drawn, when a hold starts, when a hold ends without an attack, and when the attack ends however it ends. A leap still carries its charge through.

**Perk screen, round 3 (D30–D33):**

- **Locked look:** while Dash is missing, Blunt leap is never put on the game's list of unlocked perks (new wrapper on `PlayerDevelopmentData.UnlockNewPerk`), and the screen forces the game's `Locked` state when it builds the page, re-checks it, or gets an "unlocked" message. A click on it flashes the Dash box and its wire red (`LockedHighlight`) until the pointer leaves.
- **Wires:** the game's own wire pictures (`perks_new.inkatlas`: `wire_CPerk1_1_to_CPerk1_3` across, `wire_CPerk2_1_to_CPerk2_3` down), stretched in the middle only (nine-slice, 16 px kept at each end), so the pads and the jogs at both ends keep the game's shape. Each spans the gap between two box edges exactly (161.5 px across, 48 px down). Tinted by the game's `PerkWire.wireColor` style with the game's rule.
- **Dash box:** the game's perk-box pictures (`Perk_Cell_*`) with `PerkCellBase.*` style bindings, at 60%, centred 48 px under Blunt leap; `Locked` without Dash, `Bought` with it. Not clickable.
- Mockup: `notes/2026-11-22-proposal-perk-screen-v3.png` (local).

### Names, texts and the Dash card (2026-11-22, D37–D39)

**Names:** **Battering Ram** (the leap perk) and **Thunder Breaker** (the full-charge perk). The game shows them in capitals.

**Descriptions** (default settings; the numbers follow the settings):

> **BATTERING RAM**
> When performing Strong Attacks with Blunt Weapons, you now **automatically leap** to enemies within range.
>
> These **Leap Attacks** can also be performed from midair, and deal additional damage that scales with the distance of the leap (max. +50%).

> **THUNDER BREAKER**
> Holding a Strong Attack with Blunt Weapons now charges it up.
>
> A **fully charged Leap Attack** reaches **+50% farther** and lands faster. Its hit can **send the enemy flying** (80% chance, 30% against heavy enemies) or stagger them otherwise.
>
> Crit Hits also release an **EMP blast** around the target.

- **Models:** Flash and Thunderclap (the game's blade leap) and the Gorilla Arms charged attack.
- **Variants:** settings that change what a perk does switch the description to a matching variant:
  - Battering Ram: "Always charged" ("fully charged Strong Attacks"), mid-air off, distance bonus 0 (8 variants);
  - Thunder Breaker: EMP off, stagger off (4 variants).
  - The system points the perk record at the matching key and writes the numbers, only when a setting changed (`BluntLeapSystem.UpdatePerkTexts`).

**The Dash box's card:**
- Hovering the box plays the game's perk-box hover: the icon grows 8% and a faint light sweeps across.
- It opens Dash's own perk card (the same card as on the Reflexes page: name, video, both levels, its state), placed beside the box the way the game places a perk's card.
- **Where our lines go:** the game's current perk card has no requirement row (its unlock-info fields point at nothing), so "Requires Dash" and the Dash card's line go into the card's unused text block under the level descriptions, re-tinted to the description colour (the game tints that block black).
- The card shows no buy or sell hints, and adds one line (D40): "Battering Ram needs Dash at level 2 to unlock. Get it in the Reflexes tree (Reflexes 9): the leap is a Dash that ends in a heavy hit." The 9 is read from the game's data.
- Hooks: two `cb func`s on `NewPerksScreenLogicController` (box hover), two methods added to `NewPerksCategoriesGameController` (show and hide the card), a field on `NewPerkDisplayData` (marks the card), and a wrapper on `PerkDisplayTooltipController.UpdateTooltipHints`.

### Crash fix: the perk screen (2026-11-22)

**What happened:** after the names-and-card build, opening any perk page crashed the game (twice, same address).

**Cause** (from the two crash dumps):
- Both crashes stop in the game's weak-reference assignment (`Cyberpunk2077+0x18a5a4`), writing into an address of 0.
- The stack still held the arguments of the first Dash-box layer call (`cell_outer_bg`, `Perk_Cell_outer_bg`, `PerkCellBase.backgroundColorOuter`).
- That build had made `BluntLeap_BoxLayer` return its layer as a `wref<inkImage>` made from a `ref`. Four of its six calls ignored the result. When a call's result is ignored, the game has no slot to write the weak reference into, so it writes to 0.
- No other function in the mod returns a weak reference that a caller ignores.

**Fix:**
- `BluntLeap_BoxLayer` returns nothing again (as in the second build, which opened the page fine). The icon and sweep layers are looked up by name afterwards, with null checks.
- The two card-line wrappers also check that the card's text block exists before using it.

### Perk texts and the Dash card, fixed (2026-11-22, after the first look in game)

**Seen in game:** both perk cards showed the bare keys (`BLUNTLEAP-PERK-LEAP-NAME`, `BluntLeap-Perk-Leap-Desc-NAB`, `BluntLeap-Perk-NeedsDash`). The Dash box's card showed Dash's own text with an Acquire hint and no line of ours.

**Causes:**
- **Texts:** the game reads a perk's name and description with `GetLocalizedText(record.Loc_name_key())` (`PlayerDevelopmentDataManager.GetNewPerkDisplayData`). That lookup does not find keys added through Codeware's localization: it returned the key itself.
- **Dash card:** the card rebuilds the perk's display data while it draws (`UpdateVideo` calls `RefreshRuntimeData`, which makes a fresh `NewPerkDisplayData` from the perk type). Our mark sat on the old display data, so it was gone before the hints and the requirement line were drawn.

**Fix:**
- `BluntLeapText.Get(game, key)` (in `BluntLeap_Texts.reds`) reads our texts through Codeware's `LocalizationSystem.GetText`, and if that has nothing, straight from our English package. It never returns the bare key for a key we define.
- A wrapper on `GetNewPerkDisplayData` replaces the name and description of our two perks with those texts. It uses the keys in the perk records, so the description variant for the current settings shows.
- The card lines use `BluntLeapText.Get` too.
- The Dash-box mark moved to the card's own data (`NewPerkTooltipData`), which the card does not rebuild.

### Perk card videos (2026-11-22, D41)

- **Source:** the user's in-game recordings. Battering Ram uses seconds 7 to 18, Thunder Breaker seconds 14 to 25 (11 s each). The recordings are not in the repository.
- **Format:** the same as the game's perk videos (`base\movies\tutorials\700x394\perk_*.bk2`): 700 x 394, 30 fps, no sound, about 1,000,000 bytes per second (11 MB each).
- **Bink 1, not Bink 2:** the free RAD Video Tools only writes Bink 1 (its Bink 2 encoder needs a licence). The game's player (`bin/x64/bink2w64.dll`, 2020.09) checks for the Bink 1 headers `BIKf` to `BIKk` as well as Bink 2 up to `KB2j`; RAD writes `BIKk`. **Playback in game is not confirmed yet.**
- **Quality:** encoded back to frames, the videos match the cut frames at about 39.5 dB PSNR. They are as sharp as the game's own perk videos, which are also 700 x 394. On a 1440p screen the card shows the video about 500 px wide, so it is shown smaller than it is.
- **Built by:** `tools/make_videos.py` (ffmpeg cuts and scales; RAD encodes) into `art/video/`. `tools/pack_icons.sh` packs them uncompressed into the archive under `bluntleap\movies\`. The perk records name them in `binkPath`.

### Charge speed under Sandevistan (2026-11-22, D43)

- **What happens in the game:** a held melee charge fills the weapon's `WeaponCharge` pool at 100 / `ChargeTime` points per second (`MeleeChargedHoldEvents.OnEnter`, `StartPool`). The pool fills in world time, so Sandevistan slows it. This is true of every melee charge in the game (katanas, blunt, Gorilla Arms, Mantis Blades, stun baton), so ours behaves like the game's.
- **The game's only catch-up** is for gun fire rate (`CalcCycleTimeDeltaFactor`): under Sandevistan, 1 / dilation times 0.5 to 0.9 (`ProportionalClampF(1.0, 2.0, cycleTime, 0.5, 0.9)`).
- **Setting** (Charge group): "Charge speed under Sandevistan", default **Full** (Vanilla until 2026-11-22, D44).
  - Vanilla: unchanged.
  - Partial: halfway between Vanilla and Full (D52). With slow-down d, the charge fills at d of its normal real-time speed under Vanilla and 1 under Full; Partial gives (1 + d) / 2. It first used the game's gun catch-up (1 / d times 0.5 to 0.9); with milder Sandevistans that came out slower than Vanilla (with a 0.55 slow-down: 2.0 times the charge time against Vanilla's 1.8).
  - Full: 1 / dilation, the same real time as without Sandevistan.
- **How (first build; its update wrapper turned out never to run and was removed, see the second test below):** the hold state has no update of its own and uses the empty `MeleeEventsTransition.OnUpdate`. A wrapper on it acts only for `MeleeChargedHoldEvents` and only for a weapon whose charge is ours. Each frame it works out the wanted fill rate. Only when that differs from the pool's current rate does it change the pool's Regeneration modifier (`GetModifier`, `valuePerSec`, `RequestSettingModifier`). The charge built up so far is kept, so Sandevistan starting or ending mid-charge only changes the speed.
- Weapons with a charge of their own (stun batons, Gorilla Arms, blades) are not touched.
- **First test (2026-11-22): no effect.** All three values felt the same, and the log had no "Charge rate" line, so the rate was never changed. Not known yet which step failed. The second build:
  - reads the slow-down more robustly. Sandevistan exempts the player from it (`SetIgnoreTimeDilationOnLocalPlayerZero`), so the time system's figure may show none. If so, it uses the player's Sandevistan time scale (`TimeDilationSandevistanTimeScale`, the figure `SandevistanEvents` sets). It counts Sandevistan as on by its time reason, or by its status effect while any slow-down is on;
  - has a second way in: the charge's own pool listener, each time the charge grows, in case the hold state's update is never called;
  - with "Write a log" on, writes what it sees once per hold and whenever the slow-down changes ("Charge (hold update)" or "Charge (charge grew)").
- **Second test (2026-11-22): Full works.** The log showed:
  - every line came from the pool listener ("charge grew"), none from the hold state's update. The game never calls the empty `MeleeEventsTransition.OnUpdate` that `MeleeChargedHoldEvents` inherits, so the first build's wrapper never ran. It has been removed; the listener is the only way in.
  - `GetActiveTimeDilation()` does give Sandevistan's world slow-down (0.55 with the user's Sandevistan, the same as its `TimeDilationSandevistanTimeScale`). The fallback to the time scale is kept but was not needed.
  - The rate follows Sandevistan's ease in and out (about 178 to 182 per second for a bat during the ease).

### Fists swing start (2026-11-22, D45)

- **Seen in game:** fist leaps landed their punch just before reaching the enemy.
- **Cause** (game data): the leap starts the strong attack `attackStartupDuration` (0.3 s) before arrival. Each weapon's strong attack hits a fixed time after it starts (`attackEffectDelay`):

  | Weapon | Hit after | Hit lands |
  |---|---|---|
  | Katana | 0.25 s | 0.05 s before arrival (the game's tuning) |
  | Knife (the game starts it 0.1 s before) | 0.08 s | 0.02 s before arrival |
  | **Fists, Gorilla Arms** (`StrongArmsStrongAttack` inherits `FistsStrongAttack`) | **0.19 s** | **0.11 s before arrival: short** |
  | One-handed blunt, two-handed blunt | 0.29 s | about on arrival |
  | Stun baton | 0.31 s | about on arrival |
  | Hammer | 0.5 s | on arrival with "Hammer swing start" 0.5 s |
- **Fix:** a "Fists swing start" setting (default 0.21 s: the 0.19 s hit plus the game's 0.02 s margin for knives) moves `LeapExitTime` the same way the hammer setting does, for fists and Gorilla Arms. Other blunt weapons keep the game's timing.

### Fists leap reach bonus (2026-11-23, D46)

- **Seen in game:** with the swing start fixed, fist leaps still missed often: the reach is too short.
- **How a melee hit's reach works:** the hit is a box swept in front of V, as long as the weapon's `Range` stat (`MeleeAttackGenericEvents.CreateMeleeAttack`). Player weapons: fists and Gorilla Arms 1.5 m, knife 1.5, one-handed blunt and hammer 2.0, two-handed blunt 2.5, katana 3.0. The leap stops 0.9 m from the target's centre.
- **Fix:** while a fist or Gorilla Arms leap runs and until its punch ends, the weapon gets +`fistLeapReach` m of `Range` (setting "Fists leap reach bonus", default 1.0 m: fists reach like a two-handed bat).
  - `Range` is also used by an attack's move-to-target, which could put V farther away; the game skips that move when the attack follows a leap, so the bonus only lengthens the punch.
  - Taken off when the attack ends (`MeleeAttackGenericEvents.OnExit` / `OnForcedExit`), when the leap ends without its attack (`MeleeLeapEvents.OnExit` not going on to the strong attack, `OnForcedExit`), when a weapon is drawn, and on loading a save.

### Leap swing and reach for every blunt type (2026-11-23, D47)

The swing start and the reach bonus are now two settings for each blunt weapon type, in their own Mod Settings group, "Leap swing and reach":

| Type (game item type) | Strong attack hits after | Range in the game | Swing start default | Reach bonus default |
|---|---|---|---|---|
| Fists (`Wea_Fists`) | 0.19 s | 1.5 m | 0.21 s | +1.0 m |
| Gorilla Arms (`Cyb_StrongArms`) | 0.19 s | 1.5 m | 0.21 s | +1.0 m |
| One-handed (`Wea_OneHandedClub`; stun batons are this type) | 0.29 s (stun baton 0.31 s) | 2.0 m (stun baton 4.0 m) | 0.3 s (the game's) | 0 |
| Two-handed (`Wea_TwoHandedClub`) | 0.29 s | 2.5 m | 0.3 s (the game's) | 0 |
| Hammer (`Wea_Hammer`) | 0.5 s | 2.0 m | 0.5 s | 0 |

- The variable names `hammerLead`, `fistLead` and `fistLeapReach` are kept, so saved values carry over. Gorilla Arms used the fist values before; they now have their own (same defaults).
- `BluntLeapSystem.SwingStartFor` and `LeapReachFor` pick the value by item type; the leap applies both for every type (a swing start of 0.3 s and a bonus of 0 change nothing).
- 38 settings in all, in five groups.

### Minimum leap reach (2026-11-23, D48)

- **Wanted:** the attack that ends a leap should reach at least 2.5 m with any blunt weapon.
- **Below that in the game:** fists and Gorilla Arms 1.5 m, one-handed blunt weapons and hammers 2.0 m. Two-handed weapons reach 2.5 m, stun batons 4.0 m.
- **How:** a setting "Minimum leap reach" (2.5 m). At the start of a leap the weapon's current `Range` is read, and the bonus is the larger of the type's own "Reach bonus" and what is missing to the minimum. So a weapon whose own Range differs from its type's is covered too. The per-type bonuses now default to 0. The fist +1.0 m of D46 now comes from the minimum.
- Results with the defaults: fists and Gorilla Arms 1.5 + 1.0, one-handed and hammers 2.0 + 0.5, two-handed and stun batons unchanged. With "Write a log" on, each leap writes "Leap reach <own> + <bonus> = <total> m".
- 39 settings.
- **Raised to 3.0 m the same day (D49),** a katana's reach. With the defaults: fists and Gorilla Arms 1.5 + 1.5, one-handed and hammers 2.0 + 1.0, two-handed 2.5 + 0.5; stun batons (4.0 m) unchanged.

### Gorilla Arms charge (2026-11-23, D51)

- **Seen in game:** with Gorilla Arms no charge bar, no full-charge sound, and the log showed every leap as "no charge": Thunder Breaker never fired.
- **Why:** the design assumed Gorilla Arms charge by holding, like stun batons. They do not. They have no `ChargeTime`, so `GetChargeValuePerSec` returns -1 and holding fills nothing. Their `WeaponCharge` pool (`StrongArmsCharge`) has no fill rate and belongs to the Phantom Liberty relic perk. At 100 the game plays the relic "charged" effect and sound and arms the relic punch (`WeaponObject.OnUpdateWeaponCharge`).
- **Fix:** a timed charge kept by the mod, never touching that pool:
  - a strong attack held with Gorilla Arms (they go through `MeleeChargedHoldEvents` like every weapon) starts a timer of "Charge time: Gorilla Arms" (default 0.75 s), only when a charge is wanted (Thunder Breaker owned, or "Always charged");
  - when it runs out: the full-charge sound and rumble, and the charge counts as full;
  - the leap decisions read the charge through `BluntLeapSystem.LeapCharge`: the timed charge (full or nothing) for Gorilla Arms, the pool for everything else. A full one gives Thunder Breaker, and "Always charged" waits for it;
  - it ends with the hold (`OnExit` / `OnForcedExit`, after the leap has read it), when a weapon is drawn, and on loading a save;
  - under Sandevistan it follows "Charge speed under Sandevistan": Vanilla runs in world time, Full in real time, Partial in real time times 2 / (1 + d).
- **No bar:** the game's bar shows a pool, and the timed charge is not one.
- 40 settings.

### Thrown enemies left bodies that could not be looted (2026-11-23, D53)

- **Seen in game:** many enemies that were sent flying dropped loot, but no loot prompt came up.
- **Cause** (game scripts):
  - when a ragdoll starts while an NPC is alive, the game puts the status effect `BaseStatusEffect.NonInteractable` on it (`NPCPuppet.OnRagdollEnabledEvent`);
  - it has no time limit and can stack (up to 200);
  - the game takes it off in one place only: the AI task `DoClearActiveStatusEffect` at the end of the ragdoll recovery, when the NPC gets up.
  - The game rarely ragdolls a living NPC, but sending an enemy flying always does. If the enemy dies before getting up, the recovery never runs, the effect stays, and the body and its loot show no prompt.
- **Fix:** the NPCs this mod sends flying are remembered (`BluntLeapSystem.NoteThrown`, at most 64). A wrapper on `NPCPuppet.OnIncapacitated` (death or knockout; the game processes the loot there) takes every `NonInteractable` stack off them (`ClearThrownBody`). Other NPCs, and the game's other uses of the effect (takedowns), are not touched.
- **Not fixed:** bodies already lying in a save from before the fix. The fix works from the throw on.
- **Second case (2026-11-24, D63):** two bodies without a prompt again. Log: both were thrown by the hit that took them down (a Tyger Claw thrown a second time while still lying from the first throw, and one thrown and knocked out by the same hit); "Thrown NPC down" ran at that moment.
  - **Cause:** `OnRagdollEnabledEvent` adds the effect when `ScriptedPuppet.IsAlive` is true, which only means "not dead". Blunt weapons knock out instead of killing, so a knocked-out NPC counts as alive. The mod forces the ragdoll 0.01 s after the hit; when that hit had already knocked the NPC out, the effect was cleared first and then put back by the ragdoll, with no recovery to come.
  - **Fix:** a wrapper on `NPCPuppet.OnRagdollEnabledEvent`: when the NPC is one this mod threw and is already down (`IsIncapacitated`, or not `ScriptedPuppet.IsActive`), the effect is taken off right after the game adds it. Thrown NPCs stay in the list after going down (still at most 64), so a later ragdoll is covered too. One second after each clearing, the body is checked again: the effect is taken off once more if it is back (log "still had NonInteractable 1 s after going down"), or the log says it is lootable.
  - The removal is one call for up to 200 stacks (it was a loop of 200 single calls, because the removal takes effect a moment later).
  - **Tested in game (2026-11-24):** two fights at 100% throw chance; all bodies lootable (user). Log: one knocked-out Tyger Claw (#01943), lying for over a minute, was moved by a new ragdoll; the user saw its body unlootable for a moment, then lootable. The ragdoll check found no effect yet (the game adds it a moment after the ragdoll starts), and the 1 s check took it off ("still had NonInteractable 1 s after going down"). Several other thrown NPCs went down with the effect on and were cleared at once.
  - **So:** the body is now checked 0.1 s and 1 s after each clearing. The 0.1 s check logs only when it takes the effect off; the 1 s check also logs "lootable".
- **Third case: the loot prompt was never set (2026-11-24, D66).**
  - **Seen in game:** one Tyger Claw body per fight without a loot prompt, in several attempts of the same fight, while the mod's checks all said "no NonInteractable". The user: the enemy was sent flying with health left, hit a wall, and died.
  - **CET check of that body** (`tools/cet_body_check.lua`): dead, incapacitated, not defeated, not active, has loot, no NonInteractable, no status effects at all. Nothing blocked it: the prompt was simply off.
  - **Cause (game scripts):** `ScriptedPuppet.OnIncapacitated` sets the prompt once, 2 s after the NPC first goes down (`EnableLootInteractionWithDelay`, `items.dropSettings.delayBeforeEnablingLootPickUp` = 2): `UpdateLootInteraction` turns the 'Loot' interaction on only if the NPC no longer counts as active and its inventory can be opened. Any later call (death: `OnDied` calls `OnIncapacitated` again) stops early, because the NPC "already went down". The log showed thrown NPCs going down at the throw with a little health left (#01088: 2.7 of 204) and dying afterwards. When the one check came out "no", nothing set the prompt again.
  - **Fix:** for NPCs this mod threw, the game's own check (`UpdateLootInteraction`, with the cached "active" state refreshed) runs again 2.5 s after they go down and 2.5 s after they die (a wrapper on `ScriptedPuppet.OnDied`). It still gives the prompt only under the game's own conditions. Log: "N s after going down: loot prompt set again, on/off (dead true/false)".
  - **Not the cause, at least not always (same night):** with this build, #01089 was thrown, went down and died in the same second, and its 2.5 s check logged "loot prompt set again, on (dead true)". Yet the body had no prompt, and the CET check gave the same picture as before (dead, not active, has loot, no NonInteractable, no effects). So the game's loot setting was on and something else kept the prompt from the player. Both such bodies had hit a wall hard. Next suspect, to be measured: the point the game puts the body at (where the prompt hangs) is not where the body is seen.
  - **Position ruled out:** on #01089 the CET check gave its game position 1.0 m from the player and 0.5 m from the aim point, not moving, ragdolling, and the loot check run on the spot said "on". The loot icon over it had gone from the screen but stayed on the minimap. **No interaction at all was offered, not even "Pick up body"**: the whole interaction of the body is blocked, not only the loot. No dismemberment on it, no weapon dropped nearby.
  - **What the stuck bodies share:** they were alive when the throw's ragdoll started, so the game started its AI ragdoll behaviour (`TriggerRagdollBehavior`) and added NonInteractable, and they died during the throw (hitting a wall). Bodies that died otherwise, or were already down at the ragdoll, are fine.
  - **Test steps** (`tools/cet_unstick.lua`, calls `ScriptedPuppet.BluntLeapUnstick(step)` on the body under the crosshair), to find which one brings the prompt back: 1 the 'Loot' layer on directly; 2 the interaction component off and on; 3 the end of the AI ragdoll behaviour (`TriggerRagdollBehaviorEnd`); 4 NonInteractable added and taken off the game's way (a `RemoveStatusEffectEvent`), in case a count kept by the game is off. Stuck bodies are easier to get with a higher "Send flying: force" (up to 300%) on enemies with little health near a wall.
  - **The test steps did not help** (none of the four brought a prompt back; removed again). The stuck body was #01089 again, from the same biker group as #01090. **Killed with a gun, #01089 was never stuck.** The user's idea: kills the game does not credit to V (cars and the like) leave bodies that cannot be looted.
- **Fourth case, the cause: kills not credited to V (2026-11-24, D69).**
  - **Game scripts:** a ragdolling body's impacts are an attack (`NPCPuppet.OnStartRagdollDamageEvent`, `Attacks.RagdollImpact`) whose instigator is the ragdoll's instigator (`GetRagdollInstigator`: `m_ragdollInstigator`, or the instigator of an UncontrolledMovement status), **or the NPC itself if there is none**. The game sets it from the ragdoll's start (`RagdollNotifyEnabledEvent.instigator`), from vehicle hits, and from UncontrolledMovement effects. The mod's forced ragdoll (`CreateForceRagdollEvent`) names no instigator, so a thrown NPC killed by the wall or the fall killed itself: a kill not credited to V. Such bodies offer no interaction at all (as the user knows from cars); how the game decides that is in native code (`ProcessLoot`), but the facts fit: every stuck body died from its own impact, gun kills never stuck.
  - **Fix:** the mod makes V the ragdoll's instigator when it throws (`NPCPuppet.BluntLeapCreditRagdoll`, sets `m_ragdollInstigator` just before the forced ragdoll), as the game's own ragdolls from V's attacks do. Kills by the wall or the fall after a throw are credited to V, like any kill V causes. The death line in the log (and the on-screen message, and the CET list) says "kill credited to V" or "kill NOT credited to V".
  - The earlier fixes stay: NonInteractable (cases 1 and 2) was seen on bodies in the log, and running the game's loot check again after death is the game's own check.
  - **Telling a wall death apart:** "kill credited to V" alone does not say how it died. The mod notes each thrown NPC's ragdoll impacts (a wrapper on `NPCPuppet.OnStartRagdollDamageEvent`, where the game makes the impact an attack); a death within 1 s of one reads "died from its impact (wall or ground)".
  - **Wall-kill test mode** (now in the test add-on: `addons/TestTools/cet/cet_wall_kill_test.lua`, `BluntLeapTestSystem.SetWallKillTest(on, force)`): while on, every fully charged leap hit on a throwable enemy throws it (alerted or not, no stagger or small-push roll) with the given force (5 to 300%), and 0.05 s after the hit it is left with 1 health point, so the impact kills it. (The hit's own damage cannot be cut at the stage the mod runs: the game deals damage earlier, in `DamageSystem.Process`.) Each such death is shown on screen even with the log off. Not saved; off after a load.
- **Fifth case, the real cause: a kill by the ragdoll impact itself (2026-11-24, D71).**
  - **Test mode result:** every enemy killed by its impact had "kill credited to V", and **none of the bodies could be looted**. So the credit (D69) was not the deciding factor.
  - **Known game bug:** kills by impacts (cars, the knockback of the Guts shotgun) leave bodies with no loot and no carry; the Nexus mod "Impact Kill Looting Fix" (game 1.11, an archive) fixes it for vehicles. In the game scripts, `DamageSystem.ProcessRagdollHit` (and `ProcessVehicleHit`) set the damage of a hard impact (11 m/s or more, or a high fall) to the NPC's full health and call `SetMyKiller` and `MarkForDeath`; softer impacts get damage from a curve. Which native step then leaves the body without interactions is not visible in scripts.
  - **Workaround (29bda79, removed again the same night):** a wrapper on `DamageSystem.ProcessRagdollHit` cancelled a lethal impact on a thrown NPC and took its health 0.05 s later. The user found the bodies lootable but one enemy did not die from a hard wall hit; the log showed several such enemies living on for 5 to 30 s (the health removal did not kill). Replaced by the fix of the cause below.
- **The cause, and its fix (2026-11-24, D72).**
  - **Found in a side session:** the Nexus mod "Impact Kill Looting Fix" (28099) changes, in two interaction descriptor files (.inter, path hashes 14aaf0e8ff593689 in basegame_4_gamedata and 93e4d654e569d34b in basegame_1_engine), only one thing: the condition class `NPCIncapacitatedPrereq` becomes `PuppetIncapacitatedPrereq`, on the NPC body interaction layers (loot, carry, takedowns).
  - **Game scripts (prereqs.script):** `NPCIncapacitatedPrereq.IsFulfilled` holds only if the NPC's AI high-level state (PuppetState blackboard, `GetHighLevelStateFromBlackboard`) is Unconscious or Dead, or `ScriptedPuppet.IsDefeated`, or nanowire-hacked. `PuppetIncapacitatedPrereq` holds if `IsIncapacitated()`. So an NPC that dies without its AI state becoming Dead (killed by a ragdoll impact, a car) has a body with no interaction at all. This fits every CET check (dead, not active, has loot, no NonInteractable, no prompt).
  - **Research:** the class name appears in exactly those two files (scan of the CR2W headers of every file in basegame_1_engine, _2_mainmenu, _3_nightcity, _4_animation, _4_appearance, _4_gamedata, memoryresident_1, ep1_1_nightcity, ep1_2_gamedata: about 342,000 files; a third vanilla file already uses `PuppetIncapacitatedPrereq`), not in TweakDB (tweakdb.bin and tweakdb_ep1.bin; the search finds other prereq class names there), and no script calls it. None of the installed mods' archives or scripts uses either class; Impact Kill Looting Fix is not installed.
  - **A wrapper on the condition is not possible:** `NPCIncapacitatedPrereq.IsFulfilled` overrides a native function and keeps the native, unmangled name (`IsFulfilled`; NativeDB). redscript's `@wrapMethod` and `@replaceMethod` match the mangled name and report "this signature does not match any existing method" for every qualifier tried, while a plain call to it compiles.
  - **First test of the fix (same night):** a few bodies still stuck, and the log had no "set to Dead" line at all: one second after every death the state was already Dead or Unconscious. **CET body check of four stuck bodies: AI state "Relaxed"** (dead, not active, has loot, no NonInteractable, no effects). So the game sets the state back to Relaxed some time after the death, which confirms the cause.
  - **So the state is watched:** after a death, besides the check a second later, a listener on the NPC's PuppetState `HighLevel` value (`BluntLeapDeadStateWatcher`, at most 64, the oldest unregistered) sets it back to Dead 0.05 s after the game changes it to anything but Dead or Unconscious. `tools/cet_set_dead.lua` sets the body under the crosshair to Dead by hand, to confirm on a stuck body that the options then appear.
  - **Confirmed in game (2026-11-24, wall-kill test mode):** the user found every body lootable. Log, for each wall kill: "died from its impact (wall or ground), kill credited to V", "1 s after its death: AI state Dead", then 1 to 2.5 s after the death "the game changed its state: AI state Relaxed, set to Dead". So the game itself sets a body killed by its ragdoll impact back to Relaxed shortly after the death; the listener catches it every time.
  - **Fix:** the state the condition reads is set right. A second after any NPC dies (`ScriptedPuppet.OnDied`, all NPCs, not only thrown ones), if its AI high-level state is still neither Dead nor Unconscious, it is set to Dead on the PuppetState blackboard (`BluntLeapSystem.EnsureDeadState`). Ordinary deaths are Dead by then and untouched. Log: "NPC #nnnnn died but its AI state was X a second later: set to Dead". Wall impacts kill as in vanilla again.
  - **With Impact Kill Looting Fix installed too:** its two files use `PuppetIncapacitatedPrereq`, which does not read the blackboard, so the condition holds there at once; this mod's write is then simply not needed. No double effect, no load-order question (an archive against a script); both together are harmless.
  - Kept: V as the throw ragdoll's instigator (kills by the wall are V's kills), the NonInteractable clearing, the loot re-check, and the debug tools (death messages, CET list, body check with the AI state now, wall-kill test mode).
  - **Test tools moved out of the mod (2026-11-24, D74):** the release has none of them. The on-screen death messages, the wall-kill test mode, the CET list of thrown deaths and the "Game hit" log lines are in an optional add-on, `addons/TestTools` (installs as `r6/scripts/BluntLeapTest`, with its own README and zip). Redscript cannot `@addMethod`/`@wrapMethod` a class the mod defines itself (the compiler fails with "constant pool error: definition not found", even for one trivial added method), so the mod calls a do-nothing listener (`BluntLeapTestListener`) at four points (throw chance, throw force, a throw, a thrown death); the add-on's own system (`BluntLeapTestSystem`) registers its listener (`BluntLeapTestTools`) when a save loads. The mod's normal log lines ("Write a log", off by default) stay. `tools/cet_body_check.lua` and `tools/cet_set_dead.lua` work without the add-on.
  - (Before that move) **Tools for the next one:** with "Write a log" on, each thrown enemy's death shows a message on screen ("thrown enemy #nnnnn died. Game loot check: ON/OFF"), and `tools/cet_thrown_deaths.lua` lists the last 10. `tools/cet_body_check.lua` now also gives the body's game position against where the player stands and aims, its speed, whether it is ragdolling, and runs the loot check again on the spot.

### Throw consistency (2026-11-23, D54 to D56)

Found from the log (207 Thunder Breaker leaps at force 20%) and the game's data and scripts; the user chose what to change.

- **C, enemies that cannot be knocked down (D54):** the game marks them with a knockdown threshold of 0 or less, and its own knockdown checks require more than 0. Those are drones, big drones and mechs (-1), border patrol drones (0), some bosses (-1), and any enemy while Berserk or "Unstoppable" is on (x0). No ordinary enemy has -1 by default. The force formula used the -1 as an amount and gave force 36: the 1 m pushes. Now such enemies are never thrown: they take the stagger path, like bosses, and the game handles them.
- **B, Thunder Breaker ends with the leap's attack (D55):** most weapons already ended it when the game consumes the weapon charge, 0.1 s after the hit window (`ConsumeWeaponCharge`). Gorilla Arms consume theirs on every frame of the swing, so they kept the 2 s timer, and quick follow-up punches could throw too. Now it also ends when the attack that follows the leap ends (`MeleeAttackGenericEvents.OnExit` / `OnForcedExit`), and when a leap ends without an attack.
- **A, one throw per enemy per leap (D56):** a swing that hit one enemy twice pushed it twice, the likely 20 to 50 m flights. Now a second hit on an enemy already sent flying by this leap adds nothing (`BluntLeapSystem.TakeThrow`); several enemies hit by one swing all still fly.
- **D, kept as it is:** the push goes in at the hit point, which makes each throw different, and the upward or downward lift follows the swing.
- The research log stays: each Thunder Breaker hit writes its number, time, target, threshold, weapon and result; a blocked second push writes "already sent flying by this leap".

### Enemies damaged by the EMP blast are staggered (2026-11-23, D57)

- **Asked:** an enemy the swing misses but that still takes damage from the leap should be staggered, if the game lets it be (blocking, Berserk and so on).
- **What can damage it:** every enemy the swing hits already goes through the hit effector (thrown, or a stagger is asked for). The only other damage from a Thunder Breaker leap is the EMP blast on a crit (3 m around the target). The effector's conditions take strong melee hits only, so EMP damage got no reaction from the mod: the Yinglong EMP it copies has hit reaction strength 1 to 2, usually a twitch.
- **Fix:** the EMP's hit reaction strength is 2 to 2 (data file, and `Refresh` sets the minimum to 1 when "Stagger when not sent flying" is off). The game decides as for any hit. Melee and ranged hits are staggered only without stagger resistance, with a stagger threshold above 0 (Berserk and similar set it to 0), without a large power difference, and not within the timeout after a recent stagger or knockdown. So the struck enemy, just thrown or staggered, gets only a twitch from its own EMP. The blast is a Ranged attack (its base `BaseEMPExplosion`), so the game's "strong explosion" knockdown does not apply, and it cannot be blocked.
- **Enemies neither hit by the swing nor inside the EMP take no damage from the leap,** so there is nothing for the game to react to: the game's hit area (a 25 cm box swept along the swing's arc, as long as the reach) decides who is hit.

### Unalerted enemies (2026-11-23, D58)

- **Seen in game:** the first fully charged hit on an unalerted enemy (after a reload) did damage but showed neither a throw nor a stagger. The log: the roll gave a stagger (the 20%) and the mod asked for one, but none showed. On other reloads the same first hit rolled a throw, and that worked.
- **Reading:** an enemy not in combat yet switches to combat when hit, and its AI does not play the stagger. The game's hit-reaction script has no special case for it. A throw forces a ragdoll, which works in any state.
- **Change:** an enemy that is not in combat yet (`NPCPuppet.IsInCombat` false at the hit) has its own settings:
  - "Send flying: chance, unalerted" (80%) and "... on heavy enemies, unalerted" (30%);
  - "Send flying: force, unalerted" (20%);
  - "Small push instead of stagger, unalerted: force" (4%): when the roll gives it a stagger, it gets a very small throw instead (0 asks for the stagger as before).
  - Enemies in combat keep "Send flying: chance / chance on heavy enemies / force, in combat" (renamed from "Send flying: ..."; variable names unchanged, so saved values carry over).
- The one-push-per-enemy rule and the exemptions (bosses, MaxTac, massive, cannot be knocked down) apply to the small push too.
- The diagnosis log ("Game hit" lines) shows "in combat" for every hit, so the reading can be checked.
- 44 settings.
- **Confirmed in game (diagnosis log):** the unalerted first enemy was "in combat false", with attitude Neutral, so the friendly rule was not the cause. The small push fired (force 48 at 4%). **Default raised to 6%** after testing (D59).

- **Corrected 2026-11-24 (D75): the reason is the idle spot, not "not in combat".** Game scripts: `HitReactionComponent` turns any hit reaction into a twitch (no stagger, no impact) and sends a combat-hit stimulus when the NPC is in a workspot and not in cover (`IsActorInWorkspot`, `AICoverHelper.GetCurrentCover`; it does not check combat). Vanilla, for any attack, a heavy attack too. Logs: 46 of 92 Thunder Breaker hits on unalerted enemies were on enemies at such a spot; the pipe-wrench scavenger of the first report was at one every time. So the small push now goes to enemies at an idle spot (alerted or not, `BluntLeapImpact.AtIdleSpot`), and other enemies get the stagger request as before. The setting's label is "Small push instead of stagger, at an idle spot: force" (variable `unalertedStaggerForce` unchanged). The "unalerted" throw chance and force stay as they are. Whether a stagger actually plays on an unalerted enemy just standing or walking is up to its AI (behaviour files, not scripts): to be confirmed in game (TESTING 5.11).

### Charge bar on load, and the first charge (2026-11-23, D60)

- **Seen in game:** after loading with a blunt weapon, the charge bar showed a fill (50 to 100%, maybe any). The first charge then waited 0.5 to 2 s before the bar started to fill.
- **Causes, as far as the code shows:**
  - our pool (`BluntLeap.ChargePool`) had no fill (regen) settings, so the engine's defaults applied. The game's own weapon charge pool sets them (`BaseStatPools.WeaponChargeRegen`: off until a hold, no start delay);
  - on load (and on draw) the mod requests the pool and empties it at once, but the pool is added a moment later, so the emptying did nothing. An empty or unchanged pool sends no change for the bar to follow, so a leftover fill could stay on screen.
- **Fix:**
  - the pool has the game's fill settings: disabled until a hold, start delay 0, 150 per second, no delay on change;
  - 0.5 s after a pool is added, `SettleCharge` empties it (unless a hold has started) and sets the crosshair's bar to the pool's real value. The crosshair controller is remembered when it appears. The log line "Charge pool settled: it held N%" shows what the pool held, to confirm the cause.

### Bar hidden until the charge is ready; first-charge timing log (2026-11-24, D61)

- **Seen in game after D60:** the leftover fill now clears about half a second after loading, but it is still seen until then. The first charge still feels slow to start.
- **Log:** every "Charge pool settled" line said the pool held **0%**. So the leftover fill is in the crosshair's bar, not in the charge. The fill settings of D60 made no difference the user could feel.
- **Change (bar):**
  - while a new pool is waiting to be settled (`SettlePending`), the crosshair keeps the bar hidden, with `m_displayChargeBar` false so the game's stance changes cannot show it;
  - `SettleCharge` runs 0.5 s after the request (the time that worked in game), then every 0.1 s until the pool exists (up to about 5 s). It empties the pool (unless a hold has started), then calls the crosshair's `BluntLeapBarReady`. That registers the game's bar listener now that the pool exists, sets the bar to the pool's real value and shows it;
  - the crosshair remembers whether it is on screen (intro to outro), so a bar is never shown for a weapon that was put away. A pool added with the weapon already in hand (settings changed) now gets its bar at once too.
- **Timing log for the first charge** (with "Write a log" on; times in game seconds, from the sim clock):
  - "Hold #n: charged hold started X s after the button hold began; pool N%, filling on/off, start delay, per s";
  - "Hold #n: charge first grew X s after the hold started", "charge full X s after", "bar first moved X s after";
  - "Crosshair: bar hidden until the charge is ready (it showed N%)", and bar changes outside a hold in the first 3 s after a pool request.
  These show whether the wait is in the button hold (the game's hold delay), in the charge, or in the bar. No fix for the wait is guessed before that.
- **Confirmed in game:** no leftover fill is seen any more (user, 2026-11-24).

### The slow first charge: the decay's start delay (2026-11-24, D62)

- **Timing log (first load after D61):** hold #1 started 0.21 s after the button (the game's normal hold delay); its charge **first grew 1.49 s after the hold started**, and was full at 2.48 s. Holds #2 to #4 grew **at once** (0 s) and were full at 0.99 to 1.00 s. The bar moved together with the charge each time, so the wait was in the charge.
- **Cause:** our pool's decay was on, with a **1.5 s start delay restarted by every change** (`delayOnChange`). At the start of a hold the mod empties the pool (a change), and the game's `StartPool` turns the fill on and the decay off. On the first hold after a load the decay's delay was still running and held the fill back for 1.5 s. The game's `StopPool` (hold end) never turns the decay back on, so every later hold had no decay and no wait. The decay therefore only ever acted on the first hold, and did nothing useful there: the mod empties the charge itself after every attack.
- **Fix:** the decay matches the game's own weapon charge (`BaseStatPools.WeaponChargeDecay`): off, no start delay, 300 per second, no delay on change. No script used the decay.
- **Confirmed in game (2026-11-24):** the user says the first charge fills at once. Log: hold #1 after a load grew at 0 s and was full at 0.99 s, like holds #2 and #3. The bar was hidden for 0.51 s after the load, then shown empty.

### Settings layout, Send flying switch, Non-lethal throws (2026-11-24, D76 and D77)

- **Layout (D76):** the 9 groups of section 5, chosen with the user. Models: the user's other mods with Mod Settings pages (Ragdoll Physics Overhaul has a "Toggles" group, Readable Shards hides options with `ModSettings.dependency`); the installed Mod Settings (0.2.27) supports `ModSettings.order` per option and `ModSettings.dependency "[Class.]prop[=value]"`. A switch cannot be shown twice (two copies would be two options), so the switches were moved to Features and the options that belong to them are hidden while they are off. Label changes: "Always charged" is "Leap only when fully charged" (what it does: without a full charge, a held strong attack is a normal one; it also gives blunt weapons their charge without Thunder Breaker); "Push follows the swing direction"; shorter labels inside the Send flying and EMP groups. The settings file is generated in that order (every variable name, type, default and range checked unchanged).
- **Send flying (D76):** a switch, On by default. Off: no throws; a rolled throw becomes the stagger or small push. Thunder Breaker's perk card has a variant without throws ("Its hit staggers the enemy", or no line when Stagger is off too): keys `BluntLeap-Perk-Stronger-Desc-<E|0><S|0><T|0>`.
- **Non-lethal throws (D77):** Off by default. On: for an NPC this mod threw in the last 10 s, the ragdoll impact (`DamageSystem.ProcessRagdollHit`, wrapped) gets the Nonlethal hit flag, and the "should die" mark this impact set (a hard impact: `MarkForDeath`) is taken off (`NPCPuppet.BluntLeapCancelDeathMark`). The game's `NPCPuppet.OnPotentialDeath` then knocks it out (Unconscious, or Defeated with Unconscious immunity) instead of killing it. V's own hits are not changed. Not yet tested in game.
- Proposed and not built (the user chose only Non-lethal throws): a switch for the all-NPC body fix, a throw height setting; hit-stop strength was not recommended.

### Charge time set, not added (2026-11-25, D78)

- **What went wrong:** the mod gave each blunt weapon its charge time as a fixed Additive `ChargeTime` modifier (+1.0 s for two-handed) when it first set the weapon up. When the game makes the weapon object anew without a load, the item's stats keep that modifier, but the entity has lost our charge pool, so the mod set the weapon up again and added another +1.0 s. Seen 2026-11-25: a bat at 1 s, then a second "Charge added" for it at 20:19:22 without a load, after which the log's rate base was 50 per second (2 s) instead of 100; the tooltip read "2 sec Charge Time". Not caused by the charge bar fixes (D61 onwards): the fixed modifier is older.
- **Now:** `SetChargeTime` reads the weapon's current `ChargeTime` and adds only the difference to the setting (nothing when it already matches). It runs when the weapon is set up, on every later draw and hold start, and when a setting changes, so a weapon that was doubled before is corrected on its next draw or hold (log: "Charge time was 2.00 s, set to 1.00 s"). A new object of a weapon we knew is only forgotten (`ForgetCharge`) and set up again; its stats are not touched. The full-charge bonus (`ChargeMultiplier`) is added only if the weapon does not already have the wanted value (`HasChargeBonus`). Giving a weapon back (mod off, leaving the rule) sets its charge time to 0 (blunt weapons have none in the game).
- **The tooltip line:** "X sec Charge Time" on a blunt weapon comes from this stat; the game shows it because the mod gives the weapon a charge time (the game's own blunt weapons have none). It shows the setting once the weapon has been drawn with the mod on.

### Not built

- **Screen-edge pulse at full charge** (default Off in §5): no suitable game effect picked yet.

### Deviations from §1–§6

- **Leap range setting** goes from 5 to 15 m (the game's own range); the stronger leap's extra range is applied on top of it.
- **Unlock rule changes apply at the next save load**, not only at a game restart.
- **If Perk Addition Framework is missing**, the mod grants leap and stronger leap without perks and hides the nodes, instead of doing nothing.
- **Stun batons** get their charge back at leap start, like the blunt weapons charged by this mod. **Gorilla Arms** do not (their charged punch is a separate attack of the game's), so their leap hit gets no charged bonus; the stronger leap's effects still apply to them.
- **"Always charged", "Charge bar" and the charge bonus** take effect the next time the weapon is drawn.
- **A hit that kills** gets no extra throw from us: the game (and RPO) handle the body.
