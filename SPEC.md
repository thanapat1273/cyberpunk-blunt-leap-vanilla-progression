# Blunt Leap: the agreed design (spec)

- **Status (2026-11-22):** design agreed with the user; building started (step 1). Working names throughout.
- **Code:** `github.com/thanapat1273/cyberpunk-blunt-leap-vanilla-progression`
- **Where things come from:** the user's own words are in [`DESIGN-NOTES.md`](DESIGN-NOTES.md) (decisions D1–D23; kept locally, not in the repository). The game facts are in [`RESEARCH.md`](RESEARCH.md).
- **If this file and the notes disagree, the notes win.** Fix this file.

---

## 1. What the mod does

V can do the leap attack with every weapon type on the game's blunt list: stun batons, fists, one-handed blunt, Gorilla Arms, two-handed blunt and hammers.

It adds two perks to the Body tree:

| Perk (working name) | Cost | What it gives |
|---|---|---|
| **Blunt leap** | 1 perk point | The blade leap, for blunt weapons: releasing a held strong attack at an enemy 2–15 m away leaps to them. Works in mid-air. Up to +50% damage with distance. |
| **Stronger leap** | 1 perk point | On a **fully charged** leap: +50% range (22.5 m) and faster travel; an EMP burst on a crit; a strong chance to send the enemy flying, or else a guaranteed stagger. |

## 2. Where the perks sit (Layout 1)

- **Blunt leap:** the tier-2 bridge slot (`Inbetween_Right_2`), level with Breakthrough and right beside it.
- **Stronger leap:** the centre column's upper-right slot (`Central_Perk_2_3`), on Blunt leap's other side.
- **Lines:** two short ones drawn by the mod (Breakthrough to Blunt leap, Blunt leap to Stronger leap).
- **Vanilla perks keep their places.**
- **Requirements:** Blunt leap needs Breakthrough and, by default, Dash at level 2. Stronger leap needs Blunt leap.
- **The Dash requirement's look:** both versions get built (lock and requirement text; Dash marker with the game's diagonal line). The user picks one during testing.

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
| Launch force | 100% |
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
- Names for both perks.
- An icon for Stronger leap.
- **Blunt leap's icon** (`art/`, built by `tools/make_icon.py`): the game's Flash and Thunderclap icon with only the katana (blade and guard) replaced by a baseball bat; every other pixel is the game's. Katana removal done; the bat is a first draft, awaiting review.

## 9. Build steps

| Step | Contents | State |
|---|---|---|
| 1 | Leap on all blunt weapons (always allowed), range and hammer timing, distance bonus, charge pool and bar, "Always charged" mode, settings | written; compiles offline against the game and current mod list; **not yet tested in game** |
| 2 | Stronger leap's effects: longer and faster leap, EMP on crit, launch or stagger with swing direction, hit stop, full-charge feedback | |
| 3 | The two perks (Perk Addition Framework), unlock rule a–d, refunds, Dash requirement in both looks, the two lines, icons | |

### Step 1 as built

| Part | File | Hooks |
|---|---|---|
| Leap ability, air leap, distance bonus, charge pool (data) | `r6/tweaks/BluntLeap/BluntLeap.yaml` | none; 10 new records under `BluntLeap.` |
| Settings | `r6/scripts/BluntLeap/BluntLeap_Settings.reds` | none |
| System: applies the packages, prepares the charge | `BluntLeap_System.reds` | none |
| Range and "Always charged" gate; distance leaped; hammer timing; charge carried through the leap | `BluntLeap_Leap.reds` | wraps `MeleeLeapDecisions.EnterCondition`, `MeleeLeapEvents.OnEnter` |
| Charge pool in time, bar shown or hidden, charge emptied after the attack | `BluntLeap_Charge.reds` | wraps `CrosshairGameController_Melee.OnPreIntro`, `MeleeChargedHoldEvents.OnEnter`, `MeleeAttackGenericEvents.ConsumeWeaponCharge` |

**Not in step 1 yet (settings listed in §5):**

- **Leap range above 15 m.** The game's leap caps at 15 m internally; the setting goes from 5 to 15. Longer leaps come with step 2.
- **Scalable full-charge damage bonus** and the **full-charge feedback** (sound, flash, rumble, screen pulse): step 2.
- **Unlock rule, perks, refunds:** step 3. Until then the leap is always allowed while the mod is enabled.

**Known limits to check in game:**

- **Stun batons and Gorilla Arms** keep their own charge, and the game empties it when a leap starts (as it does for the chainsword on a blade leap). Their leap hit gets no charged bonus. Blunt weapons charged by this mod keep theirs.
- **"Always charged" and "Charge bar"** take effect the next time the weapon is drawn.
- Without the Stronger leap perk (step 2 and 3), charging exists only in "Always charged" mode, as §4 says.
