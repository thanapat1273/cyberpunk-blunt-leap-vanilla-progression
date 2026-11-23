# Blunt Leap: first in-game test

Everything below is untested. The scripts compile against the game; nothing has run in it yet. This list is meant for one sitting.

## Before starting

1. **Perk Addition Framework** (Nexus 22758): installed 2026-11-22, version 1.0.1.
2. **Blunt Leap**: installed 2026-11-22 (`r6/scripts/BluntLeap/`, `r6/tweaks/BluntLeap/`, `archive/pc/mod/BluntLeap.archive`).
3. In Mod Settings, Battering Ram, General: turn **Write a log** on for this test. Lines start with `[Blunt Leap]` and go to the CET game log (`bin/x64/plugins/cyber_engine_tweaks/gamelog.log`, also shown in the CET console).
4. Have at hand: a one-handed blunt weapon, a bat, a hammer, a stun baton, Gorilla Arms if you use them, and a save with spare perk points, Body 9 and Reflexes 9.
5. **Make a manual save first.** Perk IDs added by the framework are a known risk (test 6).

If the game stops at launch with a script error, send me `r6/logs/redscript_rCURRENT.log` and stop there.

## 1. Launch and menus

| # | Do | Expect |
|---|---|---|
| 1.1 | Start the game, load a save | No error pop-up |
| 1.2 | Open Mod Settings | "Battering Ram" with five groups (General, Battering Ram (the leap), Leap swing and reach, Charge, Thunder Breaker (full charge)) and 40 settings |
| 1.3 | Open the Body perk page | Two new nodes on the row of Breakthrough: one right beside it (Blunt Leap), one further left (Stronger Leap). Two short lines join the three. A small Dash marker sits above Blunt Leap |
| 1.4 | Hover both nodes | Name, description with numbers, no missing-text keys |
| 1.5 | Look at both new nodes | Blunt Leap shows the bat icon, Stronger Leap the charged fist; both sharp and the same size as their neighbours |

## 2. The perks (unlock rule "Perks, the first needs Dash", the default)

| # | Do | Expect |
|---|---|---|
| 2.1 | Without Breakthrough | Blunt Leap is locked |
| 2.2 | With Breakthrough, without Dash level 2 | Blunt Leap is locked; tooltip says "Requires Dash (Reflexes 9) at level 2"; clicking does nothing |
| 2.3 | Buy Dash to level 2, reopen Body | Blunt Leap can be bought; the Dash marker lights up |
| 2.4 | Buy Blunt Leap | 1 point spent; the line from Breakthrough lights up; Stronger Leap becomes available |
| 2.5 | Buy Stronger Leap | 1 point spent; second line lights up |
| 2.6 | Try to sell Breakthrough | Refused while Blunt Leap is owned |
| 2.7 | Sell one level of Dash | Both our perks are refunded (2 points back); on the Body page Blunt Leap is locked again |
| 2.8 | Buy everything back, then use the full perk reset | All points back, no stuck perk |

## 3. The leap (Blunt Leap owned)

Hold the strong attack at an enemy 3 to 15 m away and release.

| # | Weapon | Expect |
|---|---|---|
| 3.1 | One-handed blunt | V leaps and the hit lands on arrival |
| 3.2 | Bat | Same |
| 3.3 | Hammer | Same; the hit should land on arrival, not after it. If it lands late or early, note it (setting: Swing start: hammer) |
| 3.4 | Fists | Same; the punch lands as V arrives, not before (setting: Swing start: fists, 0.21 s), and reaches the enemy (setting: Minimum leap reach, 3.0 m, for the leap's punch only). **2026-11-23: timing fixed, but misses were still frequent (reach too short); reach bonus added, check again** |
| 3.4b | Fists, normal punches after the leap | The reach bonus is gone: normal punches have their usual reach |
| 3.5 | Any, while in the air | Leap works (setting: Leap in mid-air) |
| 3.6 | A blade without the blade perk | No leap: blades are unchanged |
| 3.7 | Gorilla Arms | Leap works, the punch lands on arrival and reaches (Swing start: Gorilla Arms; Minimum leap reach); quick finishers still work; no crash on landing |
| 3.8 | Enemy closer than 2 m, or further than 15 m | Normal strong attack |
| 3.9 | Leap swing and reach group: give one type a bigger reach bonus or a different swing start, leap with that type and with another | Only that type changes |
| 3.10 | Write a log on. Leap with fists, a one-handed weapon, a hammer, a two-handed weapon, a stun baton | "Leap reach" lines: fists 1.5 + 1.5 = 3 m, one-handed and hammer 2.0 + 1.0 = 3 m, two-handed 2.5 + 0.5 = 3 m; no line for the stun baton (4.0 m) |

## 4. Charge

With Stronger Leap owned, or "Always charged" on, draw the weapon again first.

| # | Do | Expect |
|---|---|---|
| 4.1 | Hold a strong attack with a bat | The game's charge bar fills at the crosshair in about 1 s |
| 4.2 | Reach full charge | Bar pulses once, a short sound, a rumble pulse |
| 4.3 | Release partly charged, Stronger Leap owned, "Always charged" off | Normal leap |
| 4.4 | Turn "Always charged" on, redraw, release partly charged | Normal strong attack, no leap |
| 4.5 | Same, fully charged | Leap |
| 4.6 | Stun baton | Its own charge bar and timing, unchanged |
| 4.7 | After any attack | The bar is empty again |

## 5. Stronger leap (fully charged)

| # | Do | Expect |
|---|---|---|
| 5.1 | Fully charged leap at 16 to 22 m | V leaps the longer distance, quickly |
| 5.2 | Fully charged leap, normal enemy, several tries | Most times the enemy is thrown; otherwise it staggers. A short slow-motion beat on the hit |
| 5.3 | Watch the throw with side swings | The enemy goes the way the weapon swings |
| 5.4 | Heavy enemy (big gun or hammer types) | Thrown less often |
| 5.5 | Boss or MaxTac | Never thrown |
| 5.6 | A crit on a fully charged leap | EMP burst at the enemy; V takes no damage from it |
| 5.7 | With RPO and Relentless installed | A thrown enemy lands and gets up normally; no double throw |
| 5.8 | Send an enemy flying, then kill it before it gets up (or let the fall kill it) | Its body shows the loot prompt as usual. With "Write a log" on: "Thrown NPC down: N NonInteractable taken off" |

## 6. Saving

| # | Do | Expect |
|---|---|---|
| 6.1 | Own both perks, save, quit, start again, load | Both perks still owned, leap still works |
| 6.2 | Change the unlock rule to "No perks: leap and stronger leap", load the save | Both perks refunded, the two nodes gone from the Body page, leap and stronger leap work |
| 6.3 | Change back to the default, load | Nodes are back, nothing owned |

## 7. Second build (2026-11-22): what to check again

This build fixes the four findings from the first play test and adds the round 3 perk-screen look.

| # | Do | Expect |
|---|---|---|
| 7.1 | Charge bar off. Draw a bat, block, aim, sprint, block again | The bar never shows |
| 7.2 | Charge bar off. Switch between two blunt weapons several times, blocking in between | The bar never shows |
| 7.3 | Charge bar on. Hold a strong attack to full, release at an enemy, then hold again only briefly | The second hold starts from empty; a short hold gives a normal leap, not a stronger one |
| 7.4 | Charge bar on. Charge to full, then block before releasing | The bar empties |
| 7.5 | Charge to full, switch weapons, switch back | The bar is empty |
| 7.6 | Fully charged leap | Enemy thrown about 5 times less far than before (send-flying force 20%) |
| 7.7 | Body page, Dash not at level 2 | Blunt Leap red like Stronger Leap; on hover the lock shows; a click gives "perks locked" and the Dash box and its wire flash red |
| 7.8 | Body page, Dash at level 2 | Blunt Leap blue; the Dash box gold |
| 7.9 | Look at the three wires | Five lines each, pads at both ends a little off the middle's level, like the game's own; grey-red, blue or gold by state |
| 7.10 | Buy Breakthrough while the Body page is open, Dash missing | Blunt Leap stays red (this is the case that turned it blue before) |

## 8. Names, texts and the Dash card (2026-11-22)

| # | Do | Expect |
|---|---|---|
| 8.0 | Open the perk screen, then every attribute page, Body last | No crash (the previous build crashed here; fixed 2026-11-22) |
| 8.1 | Hover both new perks | Names BATTERING RAM and THUNDER BREAKER (not BLUNTLEAP-PERK-...); descriptions in the game's style, numbers filled in |
| 8.2 | In Mod Settings turn "Always charged" on, load the save, hover Battering Ram | Its description now says "fully charged Strong Attacks" |
| 8.3 | Turn EMP off, load, hover Thunder Breaker | The EMP sentence is gone |
| 8.4 | Hover the Dash box | The icon grows a little and a light sweeps across; Dash's own perk card opens beside it, with no Acquire hint, and under Dash's levels the line "Battering Ram needs Dash at level 2 to unlock. Get it in the Reflexes tree (Reflexes 9): ..." |
| 8.5 | Move off the Dash box | The card closes, the box settles back |
| 8.6 | Mod Settings | Groups named "Battering Ram (the leap)" and "Thunder Breaker (full charge)" |
| 8.7 | Hover Battering Ram and Thunder Breaker | Each card plays its video (the leap; the charged hit, throw and EMP) and loops it. **Passed 2026-11-22** |
| 8.8 | Read Thunder Breaker's description | "...send the enemy flying (80% chance, 30% against heavy enemies) or stagger them otherwise." |

## 9. Charge speed under Sandevistan (2026-11-22; Full passed with the second build)

Setting: Mod Settings, Battering Ram, Charge, "Charge speed under Sandevistan" (default Full). Use a bat; its charge takes about 1 s without Sandevistan. With "Write a log" on, each hold writes a "Charge (...)" line with what the mod sees (setting, Sandevistan on or off, the slow-down), and "rate set to" when it changes the speed. After testing, send me the `[Blunt Leap] Charge` lines from `bin/x64/plugins/cyber_engine_tweaks/gamelog.log`.

| # | Do | Expect |
|---|---|---|
| 9.1 | Vanilla. Charge without, then with Sandevistan | With Sandevistan the bar fills much more slowly (as every melee charge in the game) |
| 9.2 | Partial. Same | With Sandevistan it fills faster than Vanilla and slower than without Sandevistan: with a 0.55 slow-down, about 1.3 times the normal time (Vanilla 1.8) |
| 9.3 | Full. Same | About 1 s either way |
| 9.4 | Full. Start holding, then start Sandevistan halfway | The bar keeps what it had and goes on at the normal speed; the same when Sandevistan ends mid-charge |
| 9.5 | Full, Sandevistan on. A stun baton, a katana | Their own charges are unchanged (they still slow down) |
| 9.6 | Full, Sandevistan on. Charge to full and leap | Sound, flash and Thunder Breaker work as without Sandevistan |

## 10. Gorilla Arms charge (2026-11-23; passed the same day)

Thunder Breaker owned. With "Write a log" on, the log shows "Gorilla Arms charge started, full in ... s" and "Gorilla Arms fully charged".

| # | Do | Expect |
|---|---|---|
| 10.1 | Hold a strong attack with Gorilla Arms for about 1 s | Full-charge sound and rumble after 0.75 s (setting: Charge time: Gorilla Arms). No bar |
| 10.2 | Release at an enemy after the sound | A Thunder Breaker leap (log: "Stronger leap started"): longer reach, throw or stagger, EMP on a crit |
| 10.3 | Release before the sound | A normal leap ("no charge") |
| 10.4 | With the relic perk for Gorilla Arms | Its own charge and charged punch work as before, untouched by the hold |

## 11. Throw research and fixes (2026-11-23)

The research build (log only) was followed the same day by the fixes C, B and A (SPEC, "Throw consistency"). The test is normal play; Claude reads the log. Keep "Write a log" on. Each hit of a Thunder Breaker leap now writes a line like:

`Hit #1 +0.42 s, Character.xyz #12345, threshold 50, Wea_TwoHandedClub: sent flying, force 240, side -1, lift 1`

(hit number and time since the leap started, the enemy and a short id, its knockdown threshold, the weapon, then what happened). Also "Stronger leap ended at +t s" when Thunder Breaker ends with the leap's attack.

| # | Do | Why |
|---|---|---|
| 11.1 | Your usual blunt weapon: 5 fully charged leaps into a single enemy | One enemy hit twice by one swing? |
| 11.2 | The same: 5 fully charged leaps into 2 or 3 enemies standing close together | One swing hitting two enemies? |
| 11.3 | Gorilla Arms: 5 fully charged leaps, each followed at once by 2 or 3 quick punches | Do the follow-up punches throw too? |
| 11.4 | If drones are around: a fully charged leap at a drone | Which enemies have threshold -1 |

Then tell Claude; the log says the rest.

## Things to tell me

- Anything in the lists that did not match.
- How the hammer timing, the throw force and the hit stop feel; all three are settings.
- Whether the sound at full charge fits.
- The log lines around anything odd.
