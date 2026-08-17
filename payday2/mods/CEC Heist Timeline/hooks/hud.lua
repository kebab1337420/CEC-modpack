dofile(ModPath .. "core.lua")

if rawget(_G, "HUDManager") then
	if rawget(HUDManager, "_setup_player_info_hud_pd2") then
		Hooks:PostHook(HUDManager, "_setup_player_info_hud_pd2", "CECTimeline_Setup", function(self)
			if not self:alive(PlayerBase.PLAYER_INFO_HUD_PD2) then
				return
			end

			CECTimeline:Create(managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2))
		end)
	end

	if rawget(HUDManager, "update") then
		Hooks:PostHook(HUDManager, "update", "CECTimeline_Update", function()
			CECTimeline:Update()
		end)
	end
else
	log("[CEC Heist Timeline] HUDManager not found, mod inactive")
end
