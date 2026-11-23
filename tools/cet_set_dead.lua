-- Blunt Leap: set the AI state of the body under the crosshair to Dead (CET
-- console, one line). For testing on a body with no loot or pick-up whose
-- body check (tools/cet_body_check.lua) shows an AI state other than Dead
-- or Unconscious. The body's interactions need Dead or Unconscious there
-- (NPCIncapacitatedPrereq); after this line the loot and pick-up options
-- should appear. 3 = gamedataNPCHighLevelState.Dead. Changes only that
-- body's AI state.

local o=Game.GetTargetingSystem():GetLookAtObject(Game.GetPlayer(),false,false); if o then local ok,err=pcall(function() o:GetPuppetStateBlackboard():SetInt(Game.GetAllBlackboardDefs().PuppetState.HighLevel, 3) end); print("[BL dead] #"..tostring(o:GetEntityID().hash).." set to Dead: "..tostring(ok).." "..tostring(err or "").." | AI state now "..tostring(o:GetHighLevelStateFromBlackboard())) else print("[BL dead] nothing under the crosshair") end
