-- Blunt Leap: test steps for a body with no interaction at all (CET console).
--
-- For a body that shows no loot prompt and no "Pick up body" although the
-- body check (tools/cet_body_check.lua) says it is dead, not active, has
-- loot and has no NonInteractable. Needs Blunt Leap from 2026-11-24 on.
--
-- Aim at the body, run the line with step 1, then look at the body: does a
-- prompt appear? If not, run it again with 2, then 3, then 4 (change the
-- number at the end). Note the first step after which a prompt appears.
--   1. the 'Loot' interaction layer turned on directly
--   2. the body's interaction component turned off and on again
--   3. the end of the AI ragdoll behaviour sent (as when a ragdoll settles)
--   4. NonInteractable added once and taken off the game's way 0.5 s later
--      (wait a second before looking)

local o=Game.GetTargetingSystem():GetLookAtObject(Game.GetPlayer(),false,false); if o then print("[BL unstick] #"..tostring(o:GetEntityID().hash).." "..o:BluntLeapUnstick(1)) else print("[BL unstick] nothing under the crosshair") end
