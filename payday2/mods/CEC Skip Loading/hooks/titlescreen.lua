dofile(ModPath .. "core.lua")

-- The title screen only leaves when get_start_pressed_controller_index returns
-- a controller. Wrapping it instead of driving the sign-in path by hand keeps
-- the whole vanilla sequence (user check, storage check, DLC warnings) intact.
if rawget(_G, "MenuTitlescreenState") and rawget(MenuTitlescreenState, "get_start_pressed_controller_index") then
	local vanilla = MenuTitlescreenState.get_start_pressed_controller_index

	function MenuTitlescreenState:get_start_pressed_controller_index(...)
		local index = vanilla(self, ...)
		if index then
			return index
		end

		return CECSkipLoading:AutoStartIndex(self)
	end
else
	log("[CEC Skip Loading] MenuTitlescreenState not found, title screen left untouched")
end
