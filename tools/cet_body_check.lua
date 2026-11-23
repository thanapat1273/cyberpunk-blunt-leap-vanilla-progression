-- Blunt Leap: what is on the body under the crosshair (CET console, one line).
--
-- Aim at a body that shows no loot prompt, open the CET overlay, paste the
-- line below into the Console and press Enter. The result is printed in the
-- console and written to bin/x64/plugins/cyber_engine_tweaks/scripting.log,
-- starting with "[BL body]": the body's ID (its last 5 digits match the
-- "#nnnnn" in the mod's log), its record, whether it has NonInteractable,
-- whether it is dead / knocked out, whether the game thinks it has loot,
-- and every status effect on it. Reads only; changes nothing.

local o=Game.GetTargetingSystem():GetLookAtObject(Game.GetPlayer(),false,false); local function q(f) local ok,r=pcall(f); if ok then return tostring(r) end; return "?" end; if not o then print("[BL body] nothing under the crosshair") else local fx={}; pcall(function() for _,e in ipairs(Game.GetStatusEffectSystem():GetAppliedEffects(o:GetEntityID())) do table.insert(fx, TDBID.ToStringDEBUG(e:GetRecord():GetID())) end end); print("[BL body] id "..q(function() return o:GetEntityID().hash end).." "..q(function() return TDBID.ToStringDEBUG(o:GetRecordID()) end).." | NonInteractable "..q(function() return StatusEffectSystem.ObjectHasStatusEffect(o,TweakDBID.new("BaseStatusEffect.NonInteractable")) end).." | dead "..q(function() return o:IsDead() end).." | incapacitated "..q(function() return o:IsIncapacitated() end).." | defeated "..q(function() return ScriptedPuppet.IsDefeated(o) end).." | active "..q(function() return ScriptedPuppet.IsActive(o) end).." | has loot "..q(function() return ScriptedPuppet.HasLootableItems(o) end).." | effects: "..table.concat(fx,", ")) end
