# Blunt Leap: first in-game test

Everything below is untested. The scripts compile against the game; nothing has run in it yet. This list is meant for one sitting.

## Before starting

1. **Perk Addition Framework** (Nexus 22758): installed 2026-11-22, version 1.0.1.
2. **Blunt Leap**: installed 2026-11-22 (`r6/scripts/BluntLeap/`, `r6/tweaks/BluntLeap/`, `archive/pc/mod/BluntLeap.archive`).
3. In Mod Settings, Blunt Leap, General: turn **Write a log** on for this test. Lines start with `[Blunt Leap]` and go to the CET game log (`bin/x64/plugins/cyber_engine_tweaks/gamelog.log`, also shown in the CET console).
4. Have at hand: a one-handed blunt weapon, a bat, a hammer, a stun baton, Gorilla Arms if you use them, and a save with spare perk points, Body 9 and Reflexes 9.
5. **Make a manual save first.** Perk IDs added by the framework are a known risk (test 6).

If the game stops at launch with a script error, send me `r6/logs/redscript_rCURRENT.log` and stop there.

## 1. Launch and menus

| # | Do | Expect |
|---|---|---|
| 1.1 | Start the game, load a save | No error pop-up |
| 1.2 | Open Mod Settings | "Blunt Leap" with four groups (General, Leap, Charge, Stronger leap) and 28 settings |
| 1.3 | Open the Body perk page | Two new nodes on the row of Breakthrough: one right beside it (Blunt Leap), one further left (Stronger Leap). Two short lines join the three. A small Dash marker sits above Blunt Leap |
| 1.4 | Hover both nodes | Name, description with numbers, no missing-text keys |
| 1.5 | Look at the Blunt Leap node | It shows the bat icon, sharp and the same size as its neighbours. (Stronger Leap still shows a placeholder icon) |

## 2. The perks (unlock rule "Perks, the first needs Dash", the default)

| # | Do | Expect |
|---|---|---|
| 2.1 | Without Breakthrough | Blunt Leap is locked |
| 2.2 | With Breakthrough, without Dash level 2 | Blunt Leap is locked; tooltip says "Requires Dash (Reflexes) at level 2"; clicking does nothing |
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
| 3.3 | Hammer | Same; the hit should land on arrival, not after it. If it lands late or early, note it (setting: Hammer swing start) |
| 3.4 | Fists | Same |
| 3.5 | Any, while in the air | Leap works (setting: Leap in mid-air) |
| 3.6 | A blade without the blade perk | No leap: blades are unchanged |
| 3.7 | Gorilla Arms | Leap works; quick finishers still work; no crash on landing |
| 3.8 | Enemy closer than 2 m, or further than 15 m | Normal strong attack |

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

## 6. Saving

| # | Do | Expect |
|---|---|---|
| 6.1 | Own both perks, save, quit, start again, load | Both perks still owned, leap still works |
| 6.2 | Change the unlock rule to "No perks: leap and stronger leap", load the save | Both perks refunded, the two nodes gone from the Body page, leap and stronger leap work |
| 6.3 | Change back to the default, load | Nodes are back, nothing owned |

## Things to tell me

- Anything in the lists that did not match.
- How the hammer timing, the throw force and the hit stop feel; all three are settings.
- Whether the sound at full charge fits.
- The log lines around anything odd.
