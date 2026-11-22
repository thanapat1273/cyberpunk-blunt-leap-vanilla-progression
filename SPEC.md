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
- **Stun batons and Gorilla Arms** already have a charge and keep it.
- **Full-charge damage bonus:** the game's own rule for charged melee weapons, +33% at full charge and proportionally less below. Kept.

## 5. Settings and defaults (all in Mod Settings)

**Blunt leap**

| Setting | Default |
|---|---|
| Leap range | 15 m |
| Mid-air leap | On |
| Distance damage bonus | up to +50% at 20 m |
| Hammer swing start | 0.5 s before arrival (others 0.3 s) |

**Charge**

| Setting | Default |
|---|---|
| Charge time: fists | 0.5 s |
| Charge time: one-handed blunt | 0.75 s |
| Charge time: two-handed blunt | 1.0 s |
| Charge time: hammer | 1.2 s |
| Full-charge damage bonus | +33% (scalable) |
| Charge bar | On |
| Sound at full charge | On |
| Bar flash at full charge | On |
| Rumble pulse at full charge | On |
| Screen-edge pulse at full charge | Off (subtle, strong) |

**Stronger leap**

| Setting | Default |
|---|---|
| Extra range | +50% |
| EMP on crit | **On** (the user wants a switch: it doesn't feel quite vanilla) |
| EMP radius | 3 m |
| EMP damage | 100% of the weapon's base hit, as Electrical. **Not scaled by the crit**, charge or distance. Never hurts V |
| Launch chance | 80% |
| Launch chance, Heavy archetypes | 30% |
| Launch force | 20% (100% matches the Gorilla Arms knockout punch) |
| Push follows the swing | On |
| Stagger when not launched | Always |
| Hit stop on landing | 0.1 s |

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

### Not built

- **Screen-edge pulse at full charge** (default Off in §5): no suitable game effect picked yet.

### Deviations from §1–§6

- **Leap range setting** goes from 5 to 15 m (the game's own range); the stronger leap's extra range is applied on top of it.
- **Unlock rule changes apply at the next save load**, not only at a game restart.
- **If Perk Addition Framework is missing**, the mod grants leap and stronger leap without perks and hides the nodes, instead of doing nothing.
- **Stun batons** get their charge back at leap start, like the blunt weapons charged by this mod. **Gorilla Arms** do not (their charged punch is a separate attack of the game's), so their leap hit gets no charged bonus; the stronger leap's effects still apply to them.
- **"Always charged", "Charge bar" and the charge bonus** take effect the next time the weapon is drawn.
- **A hit that kills** gets no extra throw from us: the game (and RPO) handle the body.
