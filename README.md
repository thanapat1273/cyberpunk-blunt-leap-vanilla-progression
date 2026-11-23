# Blunt Leap (vanilla-style progression)

A Cyberpunk 2077 mod that lets V do the leap attack with blunt weapons: fists, one-handed and two-handed blunt weapons, hammers, stun batons and Gorilla Arms.

The goal is a mod that feels like part of the game: two new perks in the Body tree, **Battering Ram** and **Thunder Breaker**, the same leap blades already have, and every number adjustable in Mod Settings.

<img src="art/blunt-leap-icon-preview.png" width="250" alt="Blunt leap perk icon"> <img src="art/stronger-leap-icon-preview.png" width="250" alt="Stronger leap perk icon">

## Status

Version 1.2.1. Played and tested in game (2026-11-22 to 24): the leap with blunt weapons, the charge, both perks and the Dash requirement, the stronger leap (throw, stagger, EMP), the perk screen, the perk texts and the perk-card videos, looting thrown enemies, and the charge bar after loading. The test list is [TESTING.md](TESTING.md).

| Part | Contents |
|---|---|
| Battering Ram | Leap with every blunt weapon, leap range, hammer timing, distance damage bonus, a charge for blunt weapons with the game's own charge bar, "Always charged" mode |
| Thunder Breaker | Stronger leap on a full charge: longer and faster leap, EMP on a crit, send the enemy flying or stagger them, hit stop, full-charge sound, flash and rumble |
| Perks | Two perks in the Body tree with the game's look, icons, texts and videos; four unlock rules; the Dash requirement with a Dash box on the perk screen; automatic refunds |

Not confirmed in game yet: the "Partial" value of "Charge speed under Sandevistan" since its fix in 1.2.0.

The full design is in [SPEC.md](SPEC.md). The game facts behind it are in [RESEARCH.md](RESEARCH.md).

## Changes

**Next** (not released yet)
- Mod Settings has a new, clearer layout: General, then Features (all the on/off switches), then a group each for the leap, the charge, Thunder Breaker, sending flying and the EMP, then per-weapon fine tuning and troubleshooting. Options that only matter while a switch is on are hidden while it is off. "Always charged" is now called "Leap only when fully charged". Saved values carry over.
- New switch "Send flying": Off turns Thunder Breaker's throws off (the perk card says so too).
- New option "Non-lethal throws" (Off by default): an enemy you send flying that hits a wall or the ground hard is knocked out instead of killed.
- The small push that replaces a stagger now goes only to enemies at an idle spot (leaning on a wall, sitting, smoking, chatting, at a terminal), where the game never shows a stagger; it was given to every enemy not in combat yet. Unalerted enemies that are only standing or walking get the stagger again. The setting is now called "Small push instead of stagger, at an idle spot" and keeps its value.

**1.2.1** (2026-11-24)
- Fixed: enemies sent flying who died before getting up left bodies whose loot could not be picked up (no loot prompt). This includes enemies knocked out by the same hit that sends them flying, and enemies killed by hitting a wall or the ground after being thrown. The game can leave a body killed by an impact (also a car) with no loot and no pick-up, because it sets the body's AI state back from Dead to Relaxed a moment after the death; the mod watches each dead NPC's AI state and keeps it Dead, for every NPC.
- Sending flying is more consistent: an enemy is pushed at most once per leap (a swing that hit it twice could throw it 20 to 50 m), and enemies the game says cannot be knocked down (drones, mechs, Berserk) are no longer given a tiny push; they are left to the game.
- Thunder Breaker with Gorilla Arms now ends with the leap's punch, so quick follow-up punches no longer throw.
- Enemies damaged by Thunder Breaker's EMP blast are now staggered too (when the game allows it: not if they resist staggers or are Berserk).
- Unalerted enemies (not in combat yet) have their own throw chance and force, and when the roll gives them a stagger, which the game does not show on them, they get a very small push instead. All adjustable in Mod Settings.
- Fixed: after loading, the charge bar could show a leftover fill. The bar now stays hidden for a moment after loading until the charge is ready, then appears empty.
- Fixed: the first charge after loading waited about 1.5 s before it started to fill.

**1.2.0** (2026-11-23)
- Gorilla Arms now charge by holding a strong attack (setting "Charge time: Gorilla Arms", 0.75 s), with the full-charge sound and rumble, so their leaps can be Thunder Breaker leaps. Before, they never charged: their own charge belongs to the relic perk, which this mod does not touch. No charge bar for Gorilla Arms.
- Fixed: "Charge speed under Sandevistan: Partial" could be slower than Vanilla with milder Sandevistans. It is now halfway between Vanilla and Full.

**1.1.0** (2026-11-23)
- Fixed: fist and Gorilla Arms leap attacks landed their punch before reaching the enemy. Their swing now starts 0.21 s before landing (the game's 0.3 s suits blades).
- Leap attacks now reach at least 3 m with every blunt weapon (fists and Gorilla Arms reach 1.5 m in the game, one-handed weapons and hammers 2 m, two-handed 2.5 m). Only the attack that ends a leap; normal attacks are unchanged.
- New Mod Settings group "Leap swing and reach": a swing start and a reach bonus for each blunt type (fists, Gorilla Arms, one-handed including stun batons, two-handed, hammers), and the minimum leap reach. "Hammer swing start" moved there; a saved value carries over.

**1.0.0** (2026-11-22): first release.

## Requirements

- Cyberpunk 2077, patch 2.x (compile-checked against the current patch)
- RED4ext, redscript, TweakXL, Codeware
- Perk Addition Framework, for the two perks. Without it the mod grants the leap and the stronger leap without perks.
- Mod Settings (optional: without it the mod runs on its defaults)

## Install

With Vortex or Mod Organizer 2, install the zip from Nexus Mods. By hand, unzip it into the game folder (or copy the `r6` and `archive` folders from this repository). That adds two folders and one file, and changes no existing file:

- `r6/scripts/BluntLeap/`
- `r6/tweaks/BluntLeap/`
- `archive/pc/mod/BluntLeap.archive` (the two perk icons and the two perk-card videos)

To remove the mod: refund the two perks first (or switch the unlock rule to one without perks and load the save once), then delete those two folders and the archive.

## How it works

- The game decides a leap from one flag on the player, `CanMeleeLeap`. The blade perk grants it while a blade is held. This mod grants it while a blunt weapon is held, with the same kind of data package the perk uses.
- The scripts only wrap game functions and always call the original first. Nothing is replaced, no vanilla record is edited, and finisher leaps pass through untouched.
- Charging uses the game charge pool type, so the game fills it, draws its own bar and applies its own charged-damage rule.
- The two perks are real perks: Perk Addition Framework adds their IDs to the game, so buying, selling, respec and saving are the game's own. The one vanilla record touched is the Body page's perk list, which gets the two perks appended.
- The stronger leap's hit effects run from a small effector class named in a data record, at the stage where the crit is known and the enemy has not reacted yet. Sending an enemy flying uses the same two events as the Gorilla Arms knockout punch.

## Layout

| Path | What |
|---|---|
| `r6/scripts/BluntLeap/` | redscript: settings, the system, leap, charge, hit effects, perks, perk screen, texts |
| `r6/tweaks/BluntLeap/` | TweakXL records: the leap ability, the distance bonus, the charge pool, the hit effector, the EMP, the two perks |
| `TESTING.md` | the list for the first in-game test |
| `art/` | the two perk icons (PNG at the game size, previews; an SVG of the Blunt leap icon) |
| `art/video/` | the two perk-card videos (Bink, 700 x 394, 30 fps, from in-game recordings) |
| `archive/pc/mod/BluntLeap.archive` | the two perk icons and the two perk-card videos packed for the game |
| `tools/pack_icons.sh` | builds that archive from the two PNGs in `art/` and the two videos in `art/video/` |
| `tools/compile_check.sh` | compiles the scripts against a game install in a scratch folder |
| `tools/make_icon.py` | builds the Blunt leap icon from the game icon it is based on |
| `tools/make_stronger_icon.py` | builds the Stronger leap icon from the two game icons it is based on |
| `tools/make_videos.py` | cuts the in-game recordings and encodes them into the two perk-card videos |
| `tools/make_release.sh` | builds the zip for Nexus Mods (`dist/BatteringRam-<version>.zip`) from the last commit |
| `tools/render_perk_box.py` | renders a perk box (and its wires) at high resolution from the game's own UI textures and style values |
| `tools/cet_body_check.lua`, `tools/cet_set_dead.lua` | CET console lines for testing: what is on the body under the crosshair; set its AI state to Dead |
| `tools/scan_archive_names.py` | read-only scan of the game archives for class names (used to find every use of the body interaction condition) |
| `addons/TestTools/` | optional test add-on, not part of the release: on-screen death messages, the wall-kill test mode and a list of thrown deaths (CET), "Game hit" log lines. Its own README says how to install and remove it |

## Credits

- The perk icons are made from Cyberpunk 2077 perk icons by CD PROJEKT RED: Blunt leap is Flash and Thunderclap with its katana replaced by a baseball bat; Stronger leap is In Charge with its bullet replaced by the fist of Kinetic Absorption.
- This is an unofficial fan mod, not affiliated with or endorsed by CD PROJEKT RED.
