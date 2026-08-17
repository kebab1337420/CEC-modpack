-- CEC Skip Loading
--
-- Cuts the dead time between double-clicking the game and reaching the main
-- menu. Two separate delays are removed:
--
--   * the bootup playlist. Vanilla queues an autosave warning, the ESRB card,
--     the Starbreeze logo, a legal text screen and finally the intro video.
--     Everything except the intro video is dropped, because the modpack ships
--     its own intro through "movies/game_intro" (see the Mao Intro mod) and
--     removing that entry would silently disable it.
--   * the "press any key" title screen. Once the savegames are loaded there is
--     nothing left to decide, so the first keyboard controller is reported as
--     having pressed start and the engine walks its own sign-in path from
--     there.
--
-- Set keep_intro to false to also drop the intro video, e.g. when Mao Intro is
-- disabled and the plain vanilla intro is not wanted either.

if CECSkipLoading then
	return
end

CECSkipLoading = {}

CECSkipLoading.keep_intro = true
CECSkipLoading.skip_titlescreen = true

-- Rebuilds the bootup playlist in place. Called after the vanilla setup has
-- filled it, so every entry that must survive is already there.
function CECSkipLoading:TrimBootupList(state)
	local list = state and state._play_data_list
	if type(list) ~= "table" then
		return
	end

	local kept = {}
	if self.keep_intro then
		for _, entry in ipairs(list) do
			if type(entry) == "table" and entry.video == "movies/game_intro" then
				table.insert(kept, entry)
			end
		end
	end

	-- The engine walks the list with an index and changes state when it runs
	-- out, so an empty list is a valid "go straight to the title screen".
	for index = #list, 1, -1 do
		list[index] = nil
	end
	for index, entry in ipairs(kept) do
		list[index] = entry
	end

	log(string.format("[CEC Skip Loading] bootup playlist trimmed to %d entry(ies)", #list))
end

-- Any key press skips whatever is still playing, including entries the vanilla
-- code flags as unskippable.
function CECSkipLoading:AllowSkipping()
	Global.override_bootup_can_skip = true
end

-- Answers the title screen's "did someone press start" poll. Returns nil while
-- the savegames are still loading or when a system dialog is up, so error
-- popups are not dismissed by the auto-confirm.
function CECSkipLoading:AutoStartIndex(state)
	if not self.skip_titlescreen or self._titlescreen_done then
		return nil
	end

	if state._waiting_for_loaded_savegames then
		return nil
	end

	local ok, active = pcall(function()
		return managers.system_menu:is_active()
	end)
	if ok and active then
		return nil
	end

	local index
	pcall(function()
		index = state:get_first_keyboard_controller_index()
	end)
	if not index then
		return nil
	end

	self._titlescreen_done = true
	log("[CEC Skip Loading] title screen auto-confirmed")

	return index
end
