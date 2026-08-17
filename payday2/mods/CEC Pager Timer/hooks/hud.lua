dofile(ModPath .. "core.lua")

if rawget(_G, "HUDManager") then
	if rawget(HUDManager, "_setup_player_info_hud_pd2") then
		Hooks:PostHook(HUDManager, "_setup_player_info_hud_pd2", "CECPagerTimer_Setup", function(self)
			if not self:alive(PlayerBase.PLAYER_INFO_HUD_PD2) then
				return
			end

			CECPagerTimer:Create(managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2))
		end)
	end

	if rawget(HUDManager, "update") then
		-- A pager countdown is only useful at frame resolution, so it is
		-- refreshed every frame instead of on an interval.
		Hooks:PostHook(HUDManager, "update", "CECPagerTimer_Update", function()
			CECPagerTimer:Update()
		end)
	end
else
	log("[CEC Pager Timer] HUDManager not found, mod inactive")
end
