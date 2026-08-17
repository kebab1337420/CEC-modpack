dofile(ModPath .. "core.lua")

-- The timer restarts with the level, not with the session, so the log is reset
-- here rather than in the HUD setup, which also runs on respawn.
Hooks:Add("BaseNetworkSessionOnLoadComplete", "CECTimeline_Reset", function()
	CECTimeline:Reset()
end)

if not rawget(_G, "PlayerDamage") then
	log("[CEC Heist Timeline] PlayerDamage not found, down events inactive")
	return
end

if rawget(PlayerDamage, "on_downed") then
	Hooks:PostHook(PlayerDamage, "on_downed", "CECTimeline_Downed", function(self)
		CECTimeline:Add("Chute")
	end)
end
