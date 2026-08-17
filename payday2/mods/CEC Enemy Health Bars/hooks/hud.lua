dofile(ModPath .. "core.lua")

if rawget(_G, "HUDManager") then
	if rawget(HUDManager, "_setup_player_info_hud_pd2") then
		Hooks:PostHook(HUDManager, "_setup_player_info_hud_pd2", "CECEnemyBars_Setup", function(self)
			if not self:alive(PlayerBase.PLAYER_INFO_HUD_PD2) then
				return
			end

			CECEnemyBars:Create(managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2))
		end)
	end

	if rawget(HUDManager, "update") then
		Hooks:PostHook(HUDManager, "update", "CECEnemyBars_Update", function(self, t, dt)
			CECEnemyBars:Update(t)
		end)
	end
else
	log("[CEC Enemy Health Bars] HUDManager not found, mod inactive")
end
