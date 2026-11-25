-- Blunt Leap: the last thrown enemies that died (CET console, one line).
-- Needs the test add-on (addons/TestTools, r6/scripts/BluntLeapTest installed).
--
-- Needs Blunt Leap from 2026-11-24 on. (With "Write a log" on in Mod
-- Settings, each such death also shows a short message on screen, about
-- 2.5 s after it.) Open the CET overlay, paste the line below into the Console and
-- press Enter. It lists, newest first, up to 10 thrown enemies that died
-- since the save was loaded: their "#nnnnn" (as in the mod's log and in
-- tools/cet_body_check.lua), how long ago, how they died ("after going
-- down" means they had already gone down, for example with a little health
-- left, before they died), and what the game's loot check says for the body
-- now. Changes nothing else.

print(Game.GetScriptableSystemsContainer():Get("BluntLeapTestSystem"):ThrownDeathReport())
