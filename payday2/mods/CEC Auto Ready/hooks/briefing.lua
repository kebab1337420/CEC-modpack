dofile(ModPath .. "core.lua")

-- The mission briefing gui is the lobby: it exists exactly as long as the peers
-- are picking loadouts, and its update runs every frame, which makes it the
-- natural clock for both timers.
if rawget(_G, "MissionBriefingGui") then
	if rawget(MissionBriefingGui, "init") then
		Hooks:PostHook(MissionBriefingGui, "init", "CECAutoReady_Open", function()
			CECAutoReady:Reset()
		end)
	end

	if rawget(MissionBriefingGui, "update") then
		Hooks:PostHook(MissionBriefingGui, "update", "CECAutoReady_Update", function(self, t, dt)
			CECAutoReady:Update(self, dt)
		end)
	end
else
	log("[CEC Auto Ready] MissionBriefingGui not found, mod inactive")
end
