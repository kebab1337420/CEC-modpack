-- Maouno Downed Sound
-- Plays a custom sound through the SuperBLT XAudio API when the local player
-- goes down or gets sent to custody. Loaded by every hook script.

if MaounoDownedSound then
	return
end

MaounoDownedSound = {
	path = ModPath .. "sounds/maouno_downed.ogg",
	volume = 1,
	-- Both of these are OpenAL objects. They must never outlive the level they
	-- were created in: the game tears the audio engine down when a heist is
	-- restarted or left, and an OpenAL buffer or source still alive at that
	-- moment crashes the process with an access violation.
	_buffer = nil,
	_source = nil
}

-- SuperBLT only opens the OpenAL device once a mod asks for it. This has to
-- happen while the Lua state is loading, not in the middle of a heist, or
-- loading a buffer logs "blt.xaudio.setup() has not been called!" and fails
-- with an OpenAL error.
function MaounoDownedSound:_setup_xaudio()
	if not blt or not blt.xaudio or not blt.xaudio.setup then
		return false
	end

	if blt.xaudio.issetup and blt.xaudio.issetup() then
		return true
	end

	local ok, err = pcall(function()
		blt.xaudio.setup()
	end)

	if not ok then
		log("[MaounoDownedSound] blt.xaudio.setup() failed: " .. tostring(err))
		return false
	end

	return true
end

-- The clip is decoded on demand rather than kept around for the whole session,
-- so there is nothing to clean up when nothing is playing.
function MaounoDownedSound:_get_buffer()
	if self._buffer then
		return self._buffer
	end

	if not self:_setup_xaudio() then
		return nil
	end

	local ok, buffer = pcall(function()
		return XAudio.Buffer:new(self.path)
	end)

	if not ok or not buffer then
		log("[MaounoDownedSound] could not load " .. tostring(self.path) .. ": " .. tostring(buffer))
		return nil
	end

	self._buffer = buffer
	return buffer
end

function MaounoDownedSound:_stop_source()
	local source = self._source
	self._source = nil

	if not source then
		return
	end

	pcall(function()
		if not source:is_closed() then
			source:stop()
			source:close()
		end
	end)
end

-- Drop every OpenAL object this mod owns. Called on any level transition, and
-- safe to call repeatedly or when nothing was ever played.
function MaounoDownedSound:release()
	-- Order matters: a buffer must not be closed while a source still reads
	-- from it.
	self:_stop_source()

	local buffer = self._buffer
	self._buffer = nil

	if buffer then
		pcall(function()
			buffer:close(true)
		end)
	end
end

function MaounoDownedSound:play()
	if not XAudio then
		log("[MaounoDownedSound] XAudio is unavailable, SuperBLT is required")
		return
	end

	local buffer = self:_get_buffer()
	if not buffer then
		return
	end

	local ok, err = pcall(function()
		-- Going down and then landing in custody are two separate events that
		-- can happen back to back, so cut off whatever is still playing instead
		-- of stacking two copies of the clip on top of each other.
		self:_stop_source()

		-- A source created with a buffer starts playing right away and closes
		-- itself once it is done.
		local source = XAudio.Source:new(buffer)
		source:set_type(XAudio.Source.SOUND_EFFECT)
		source:set_volume(self.volume)
		-- Relative positioning keeps the sound glued to the listener, so it
		-- plays as a plain 2D sound at full volume wherever the player is.
		source:set_relative(true)
		source:set_position(0, 0, 0)

		self._source = source
	end)

	if not ok then
		log("[MaounoDownedSound] playback failed: " .. tostring(err))
		self._source = nil
	end
end

-- Open the audio device now, while the Lua state is still loading. The clip
-- itself is decoded the first time it is needed.
MaounoDownedSound:_setup_xaudio()

-- Every way out of a level: restarting it, loading another one, or going back
-- to the main menu. Each entry is hooked only if that class and function exist
-- in the current Lua state, since the menu state has none of them.
local teardown_points = {
	{ "Setup", "load_level" },
	{ "Setup", "unload_level" },
	{ "Setup", "load_start_menu" },
	{ "Setup", "restart_level" },
	{ "Setup", "quit_to_main_menu" },
	{ "Setup", "quit" },
	{ "GameSetup", "load_level" },
	{ "GameSetup", "unload_level" },
	{ "GameSetup", "load_start_menu" },
	{ "GameSetup", "restart_level" },
	{ "GameSetup", "quit_to_main_menu" },
	{ "GameSetup", "quit" }
}

-- Catch-all for whatever the setup list misses: leaving or restarting a heist
-- always parks the game in one of these states first. Other state changes are
-- ignored, otherwise going down would cut its own sound off.
local teardown_states = {
	empty = true,
	disconnected = true
}

MaounoDownedSound._installed_hooks = {}

-- The setup classes may not be loaded yet when this file first runs, so this is
-- called again from the setup hook script. Hooking the same function twice with
-- the same id would run the release twice, hence the bookkeeping.
function MaounoDownedSound:install_teardown_hooks()
	for _, point in ipairs(teardown_points) do
		local class_name, func_name = point[1], point[2]
		local key = class_name .. "." .. func_name
		local class = rawget(_G, class_name)

		if not self._installed_hooks[key] and class and rawget(class, func_name) then
			self._installed_hooks[key] = true

			Hooks:PreHook(class, func_name, "MaounoDownedSound_release_" .. key, function()
				MaounoDownedSound:release()
			end)
		end
	end

	local gsm = rawget(_G, "GameStateMachine")
	if not self._installed_hooks.game_state_machine and gsm and rawget(gsm, "change_state_by_name") then
		self._installed_hooks.game_state_machine = true

		Hooks:PreHook(gsm, "change_state_by_name", "MaounoDownedSound_release_state_change", function(_, state_name)
			if teardown_states[state_name] then
				MaounoDownedSound:release()
			end
		end)
	end
end

MaounoDownedSound:install_teardown_hooks()
