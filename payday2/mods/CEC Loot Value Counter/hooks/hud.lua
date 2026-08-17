dofile(ModPath .. "core.lua")

if rawget(_G, "HUDManager") then
	if rawget(HUDManager, "_setup_player_info_hud_pd2") then
		Hooks:PostHook(HUDManager, "_setup_player_info_hud_pd2", "CECLootCounter_Setup", function(self)
			-- Same panel the objective and heist timer elements use, so the
			-- counter is hidden and shown along with the rest of the HUD.
			if not self:alive(PlayerBase.PLAYER_INFO_HUD_PD2) then
				return
			end

			CECLootCounter:Create(managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2))
		end)
	end

	if rawget(HUDManager, "update") then
		Hooks:PostHook(HUDManager, "update", "CECLootCounter_Update", function(self, t, dt)
			CECLootCounter:Update(t)
		end)
	end
else
	log("[CEC Loot Value Counter] HUDManager not found, mod inactive")
end
