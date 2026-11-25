# Perk icons: research notes

- **Status (2026-11-22):** both icons are chosen. Blunt leap: `art/blunt-leap-icon.png` (D25), built by `tools/make_icon.py`. Stronger leap: `art/stronger-leap-icon.png` (D29), built by `tools/make_stronger_icon.py` (trial D below).
- This file records how they were found and what else was considered.

## Facts from the game files

| Fact | Detail |
|---|---|
| Atlas | `base\gameplay\gui\common\icons\perks\perks_icons.inkatlas` (+ `.xbm`, 3736 x 1672). 193 icons |
| Spare icons | **None.** Every one of the 193 is used by a perk |
| Icon sizes | Sub-perk and bridge slots: 125 x 116. Milestones: 177 x 177. Master perks: 243 x 243 |
| Our two perks | Blunt leap (bridge slot) and Stronger leap (sub-perk slot) are both 125 x 116 |
| Pixel format | Brightness in all four channels (R=G=B=A) |
| Related perks | The game gives each perk its own picture, even inside a cluster (Dash, Mad Dash, Air Dash; Quake, Epicenter, Aftershock). A cluster shares a theme, not a figure |

## What already sits on the Body page, right branch (our neighbours)

| Perk | Picture | Atlas part |
|---|---|---|
| Wrecking Ball | A figure leaping with a hammer overhead, smashing an enemy down | `Body_Right_Milestone_2` |
| Breakthrough | A spiked club in a fist, close up | `brawling_area_05_perk1` |
| Fly Swatter | A gloved hand holding a wrapped bat, a spark at its tip | `brawling_area_04_perk1` |
| Kinetic Absorption | Gorilla Arms | `brawling_area_02_perk2` |
| Clapback | A head taking a punch | `brawling_area_09_perk1` |
| Quake | A fist driven into the ground | `brawling_area_08_perk1` |
| Epicenter | A figure landing, debris flying | `athletics_area_03_perk2` |
| Aftershock | A fist with a burst of debris | `Body_Right_Perk_3_2` |
| Ripple Effect | A man holding a sledgehammer | `Body_Inbetween_Right_3` |
| Finisher: Savage Sling | A body being thrown | `athletics_area_06_perk2` |

So "a bat with a spark" (Fly Swatter) and "a leaping smash" (Wrecking Ball) are already taken on this page.

## Lightning in the game's icon style

| Perk (Tech tree) | Picture | Atlas part |
|---|---|---|
| In Charge | A bullet with thin jagged arcs around it | `engineering_area_07_perk1` |
| Lightning Storm | Bold bolts striking a raised fist | `engineering_area_05_perk2` |
| Bolt, Shock Value, Chain Lightning | Guns with arcs | `engineering_area_07_perk3`, `engineering_area_08_perk1`, `engineering_trait` |

The style: thin, jagged, forked lines, one to two pixels wide at 125 px.

## Other poses that could take a bat (Reflexes page, so no look-alike next to our perks)

| Perk | Picture | Atlas part |
|---|---|---|
| Flash of Steel | A lunging figure, blade overhead, a star burst behind | `kenjutsu_area_03_perk2` |
| Going the Distance | A lunging figure with speed lines | `kenjutsu_area_01_perk2` |
| Opportunist | A crouched figure under a burst | `kenjutsu_area_09_perk1` |

## Options for Stronger leap

| Option | What it is | For | Against |
|---|---|---|---|
| **A. Charged bat** | The Blunt leap picture, with bold lightning forking off the barrel and the straight speed lines on that side removed | The pair is obvious: same move, charged. Smallest change; the rest stays the game's pixels | The two icons sit side by side, so the lightning must be bold enough to tell them apart at a glance |
| B. A different pose | Flash of Steel or Going the Distance, with the blade swapped for the bat, plus lightning | Clearly a different picture; shows "further and faster" | A second katana-to-bat job; reads less as a leap |
| C. The landing | An impact burst in the style of Epicenter or Aftershock, with a bat | Shows the knock-away | Those are neighbours on the same page; it would look like a copy |

Not suitable as a base: Fly Swatter (already a bat with a spark, two slots away) and Wrecking Ball (the neighbouring milestone, and larger art).

## Trial D, chosen (Message 12, chosen in Message 13): In Charge with a fist for the bullet

- **Base:** In Charge (`engineering_area_07_perk1`), with its lightning and its white trail kept.
- **Out:** the bullet (the capsule only).
- **In:** the middle fist of Kinetic Absorption (`brawling_area_02_perk2`), cut at the wrist, mirrored left to right so it points the way the bullet did, moved 12 px left and 3 px up along the same line.
- **Pixels:** copied, mirrored and moved by whole pixels only. Nothing is resized or turned.
- **Layering:** the fist is in front, with a 1 px dark rim, except at its back end, where In Charge's trail runs straight into the wrist.
- **Result:** reads as a charged punch with a streak behind it; clearly different from the Blunt leap icon at perk size. It shows no bat and no leap, and Kinetic Absorption (same page) has the same fist, facing the other way.
- **State:** chosen as the Stronger leap icon (D29). `tools/make_stronger_icon.py` rebuilds it pixel for pixel from the two game icons.
- Also tried: the whole forearm laid over the trail. Too busy.

## How the finished icon is delivered (from the development session, 2026-11-22)

- **File:** `art/stronger-leap-icon.png`, 125 x 116, the game's format (R=G=B=A), built by `tools/make_icon.py` like the Blunt leap icon.
- **Into the game:** the development session adds it as a second part of `bluntleap\gui\icons\blunt_leap_icons.inkatlas` (`tools/pack_icons.sh`) and points `NewPerks.BluntLeap_Stronger.perkIcon` at it. The texture is padded to a width divisible by 4.
- **Until then** the Stronger leap perk shows the Mad Dash icon (`UIIcon.Reflexes_Central_Perk_2_3`) as a placeholder.
- **Blunt leap's icon** is already in the build this way (commit 525b28e, part `blunt_leap`).
- **Design notes numbering:** continue from Message 12 / D28.

## One test made

Pasting In Charge's arcs around the bat of the Blunt leap icon: **too thin to notice at perk size**, and enlarging borrowed pixels blurs them. Lightning for option A has to be drawn fresh at icon size, the way the bat was (a shape rendered by `tools/make_icon.py`), not borrowed from another icon.
