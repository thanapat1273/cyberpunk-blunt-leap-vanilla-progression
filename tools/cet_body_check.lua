-- Blunt Leap: what is on the body under the crosshair (CET console, one line).
--
-- Aim at a body that shows no loot prompt, open the CET overlay, paste the
-- line below into the Console and press Enter. The result is printed in the
-- console (and written to bin/x64/plugins/cyber_engine_tweaks/scripting.log
-- when CET saves it), starting with "[BL body]":
--   - the body's ID (its last 5 digits match the "#nnnnn" in the mod's log)
--     and record;
--   - NonInteractable, dead / knocked out / active, its AI high-level state
--     (the body's interactions need Dead or Unconscious there), whether it
--     has loot, and every status effect on it;
--   - where the game thinks the body is: how far that point is from you and
--     from the point you aim at (on the body), how fast it is moving, and
--     whether it is ragdolling. The loot prompt hangs on that point;
--   - "loot check run now": the game's own loot-prompt check, run again on
--     the spot (needs Blunt Leap from 2026-11-24 on). Look whether the
--     prompt appears after it.
-- Changes nothing else.

local p=Game.GetPlayer(); local ts=Game.GetTargetingSystem(); local o=ts:GetLookAtObject(p,false,false); local function q(f) local ok,r=pcall(f); if ok then return tostring(r) end; return "?" end; local function d(a,b) return string.format("%.1f", math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)) end; if not o then print("[BL body] nothing under the crosshair") else local fx={}; pcall(function() for _,e in ipairs(Game.GetStatusEffectSystem():GetAppliedEffects(o:GetEntityID())) do table.insert(fx, TDBID.ToStringDEBUG(e:GetRecord():GetID())) end end); local root=o:GetWorldPosition(); print("[BL body] id "..q(function() return o:GetEntityID().hash end).." "..q(function() return TDBID.ToStringDEBUG(o:GetRecordID()) end).." | NonInteractable "..q(function() return StatusEffectSystem.ObjectHasStatusEffect(o,TweakDBID.new("BaseStatusEffect.NonInteractable")) end).." | dead "..q(function() return o:IsDead() end).." | incapacitated "..q(function() return o:IsIncapacitated() end).." | defeated "..q(function() return ScriptedPuppet.IsDefeated(o) end).." | active "..q(function() return ScriptedPuppet.IsActive(o) end).." | AI state "..q(function() return o:GetHighLevelStateFromBlackboard() end).." | has loot "..q(function() return ScriptedPuppet.HasLootableItems(o) end).." | its position: "..q(function() return d(p:GetWorldPosition(), root) end).." m from you, "..q(function() return d(ts:GetLookAtPosition(p,false,false), root) end).." m from where you aim | moving "..q(function() local w=o:GetVelocity(); return string.format("%.2f", math.sqrt(w.x^2+w.y^2+w.z^2)) end).." m/s | ragdolling "..q(function() return o:IsRagdolling() end).." | loot check run now: "..q(function() return o:BluntLeapRefreshLoot() end).." | effects: "..table.concat(fx,", ")) end
