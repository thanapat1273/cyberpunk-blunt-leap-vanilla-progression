-- Blunt Leap: wall-kill test mode (CET console). Needs the test add-on
-- (addons/TestTools, r6/scripts/BluntLeapTest installed) and Blunt Leap from
-- 2026-11-24 on.
--
-- Recreates "thrown with a little health left, killed by the wall": while
-- it is on, every fully charged leap hit on an enemy that can be thrown
--   - throws it (no stagger or small-push roll; alerted or not),
--   - with the force given below (%; 5 to 300; your setting is not changed),
--   - and cannot kill it: the hit takes at most half of its health, and
--     0.05 s later it is left with 1 health point, so the impact with a
--     wall or the ground kills it.
-- Each thrown enemy's death then shows on screen, for example
--   "Battering Ram: #01089 died from its impact (wall or ground), kill
--    credited to V. Loot check: ON"
-- It is not saved, and loading a save turns it off.
--
-- Turn on (force 150%; change the number as you like):
Game.GetScriptableSystemsContainer():Get("BluntLeapTestSystem"):SetWallKillTest(true, 150)

-- Turn off:
Game.GetScriptableSystemsContainer():Get("BluntLeapTestSystem"):SetWallKillTest(false, 0)
