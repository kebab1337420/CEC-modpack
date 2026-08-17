dofile(ModPath .. "lua/core.lua")

local CMCG = _G.CustomMapCrashGuard

-- GuiDataManager level of the same trace. The Gui level is in gui.lua; this one
-- is here because the manager names tell you *which kind* of workspace was asked
-- for and from where, which the Gui call alone does not.
--
-- Both ends of every call are logged: a crash inside the native
-- create_scaled_screen_workspace() call itself would never reach the post line,
-- so the pre line is what names it.

if CMCG.guidata_wired then
	return
end

if not _G.GuiDataManager then
	return
end

local created = {}
local counter = 0

-- The real set, from core/lib/managers/coreguidatamanager.lua. The names used
-- before did not all exist, so those wrappers were never installed.
local traced_creators = {
	"create_saferect_workspace",
	"create_fullscreen_workspace",
	"create_fullscreen_16_9_workspace",
	"create_corner_saferect_workspace",
	"create_1280_workspace",
	"create_corner_saferect_1280_workspace",
	"create_workspace",
	"create_16_9_workspace",
	"create_scaled_workspace"
}

local wired = {}

for _, name in ipairs(traced_creators) do
	local original = GuiDataManager[name]

	if type(original) == "function" then
		wired[#wired + 1] = name

		GuiDataManager[name] = function(self, ...)
			CMCG:write("workspace > %s starting | %s", name, CMCG:stack(3))

			local ws = original(self, ...)

			counter = counter + 1
			created[CMCG.key_of and CMCG.key_of(ws) or tostring(ws)] = true

			CMCG:write("workspace + %s -> %s (%d live)", name, tostring(ws), counter)

			return ws
		end
	end
end

local destroy_workspace = GuiDataManager.destroy_workspace

if type(destroy_workspace) == "function" then
	wired[#wired + 1] = "destroy_workspace"

	function GuiDataManager:destroy_workspace(ws, ...)
		if ws == nil then
			CMCG:write("workspace ! destroy(nil) dropped | %s", CMCG:stack(3))

			return
		end

		local key = CMCG.key_of and CMCG.key_of(ws) or tostring(ws)

		if CMCG.guards.double_destroy_workspace and created[key] == false then
			CMCG:write("workspace ! double destroy of %s dropped | %s", key, CMCG:stack(3))

			return
		end

		counter = counter - 1
		created[key] = false

		CMCG:write("workspace - destroy %s (%d live) | %s", key, counter, CMCG:stack(3))

		return destroy_workspace(self, ws, ...)
	end
end

CMCG.guidata_wired = true

CMCG:write("guidata wired (%d): %s", #wired, table.concat(wired, " "))
