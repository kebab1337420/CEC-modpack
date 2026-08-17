dofile(ModPath .. "lua/core.lua")

local CMCG = _G.CustomMapCrashGuard

-- Heartbeat. The crash leaves no Lua stack, so the only thing that says "the
-- game was still running here" is a line per half second with the state it was
-- in. The gap between the last heartbeat and the crash dump timestamp is the
-- window the fault happened in.
local next_beat = 0
local beat = 0

local mod_path = ModPath

-- The viewport and mission traces need core modules that may not be imported
-- when their own hook runs. Both files are cheap and re-entrant, so they are
-- retried until they take.
local function wire_late_traces()
	if not CMCG.viewport_wired then
		pcall(dofile, mod_path .. "lua/viewport.lua")
	end

	if not CMCG.mission_wired then
		pcall(dofile, mod_path .. "lua/mission.lua")
	end

	if not CMCG.gui_wired then
		pcall(dofile, mod_path .. "lua/gui.lua")
	end
end

wire_late_traces()

-- The fault happens on or just after the first update tick of the level, while
-- the state machine is still "empty". So the first ticks are logged one by one
-- with a full dump of the Gui tree, and only then does the heartbeat drop to
-- twice a second.
-- Three ticks is enough: tick 1 is the one the fault lands on and the one that
-- quarantines the broken workspaces, ticks 2 and 3 say whether the tree came back
-- clean. Thirty full dumps of a level with 500 gui props is minutes of disk.
local VERBOSE_BEATS = 3

Hooks:Add("GameSetupUpdate", "CustomMapCrashGuardHeartbeat", function(t, dt)
	wire_late_traces()

	if beat < VERBOSE_BEATS then
		beat = beat + 1

		CMCG:write("beat %d (verbose) dt=%.4f", beat, dt or 0)

		if CMCG.dump_tree then
			pcall(CMCG.dump_tree, CMCG, "beat " .. beat)
		end

		next_beat = t + 0.5

		return
	end

	if t < next_beat then
		return
	end

	next_beat = t + 0.5
	beat = beat + 1

	local state = "?"

	if _G.game_state_machine and game_state_machine.current_state_name then
		local ok, name = pcall(game_state_machine.current_state_name, game_state_machine)
		state = ok and tostring(name) or "?"
	end

	local player = "no"

	if managers and managers.player and managers.player.player_unit then
		local ok, unit = pcall(managers.player.player_unit, managers.player)
		player = (ok and alive(unit)) and "yes" or "no"
	end

	CMCG:write("beat %d state=%s player=%s dt=%.3f", beat, state, player, dt or 0)
end)

Hooks:Add("GameSetupPauseUpdate", "CustomMapCrashGuardPausedHeartbeat", function(t, dt)
	CMCG:write("paused update t=%.2f", t or 0)
end)

Hooks:Add("BaseNetworkSessionOnLoadComplete", "CustomMapCrashGuardLoadComplete", function()
	CMCG:write("session load complete")
end)

Hooks:PostHook(GameSetup, "load_level", "CustomMapCrashGuardLoadLevel", function(self, level, mission, world_setting, level_class_name, level_id)
	CMCG:write("load_level level=%s mission=%s level_id=%s", tostring(level), tostring(mission), tostring(level_id))
end)

Hooks:PostHook(GameSetup, "init_finalize", "CustomMapCrashGuardInitFinalize", function(self)
	CMCG:write("GameSetup:init_finalize done")

	-- Earliest point at which the whole world is built and no update tick has run
	-- yet, so this is the last chance to take a broken workspace out of the Gui's
	-- list before the engine walks it. The heartbeat dump on tick 1 is a second
	-- chance, not the first one.
	if CMCG.dump_tree then
		pcall(CMCG.dump_tree, CMCG, "init_finalize")
	end
end)

if GameSetup.close then
	Hooks:PreHook(GameSetup, "close", "CustomMapCrashGuardClose", function(self)
		CMCG:write("GameSetup:close")
	end)
end
