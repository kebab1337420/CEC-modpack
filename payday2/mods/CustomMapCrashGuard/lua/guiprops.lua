dofile(ModPath .. "lua/core.lua")

local CMCG = _G.CustomMapCrashGuard

-- Gui prop units: which unit asked for which object, and whether that object
-- exists.
--
-- CoreEditableGui and DigitalGui both do
--
--     self:add_workspace(self._unit:get_object(Idstring(self._gui_object)))
--
-- and neither checks the result. get_object returns nil when the unit's model has
-- no object under that name, which happens on any map whose placed units no
-- longer match the models their saved data was written against. The workspace is
-- then linked to nothing and the engine faults the first frame it walks it.
--
-- The refusal itself lives in gui.lua, on create_object_workspace, so it covers
-- every gui prop class. This file only names the culprits: unit name and object
-- name, which is what it takes to repair the map itself rather than paper over it.

local function trace_add_workspace(class, class_name)
	if type(class) ~= "table" then
		return false
	end

	local original = class.add_workspace

	if type(original) ~= "function" then
		return false
	end

	function class:add_workspace(gui_object, ...)
		local unit_name = "?"

		pcall(function()
			unit_name = tostring(self._unit:name())
		end)

		local usable = false

		pcall(function()
			usable = gui_object ~= nil and alive(gui_object)
		end)

		if not usable then
			CMCG:write(
				"prop !! %s unit=%s wants object %q -- MISSING, workspace would link to nothing",
				class_name,
				unit_name,
				tostring(self._gui_object)
			)
		end

		return original(self, gui_object, ...)
	end

	return true
end

if not CMCG.props_wired then
	local wired = {}

	if trace_add_workspace(_G.CoreEditableGui, "CoreEditableGui") then
		wired[#wired + 1] = "CoreEditableGui"
	end

	if trace_add_workspace(_G.EditableGui, "EditableGui") then
		wired[#wired + 1] = "EditableGui"
	end

	if trace_add_workspace(_G.DigitalGui, "DigitalGui") then
		wired[#wired + 1] = "DigitalGui"
	end

	if #wired > 0 then
		CMCG.props_wired = true

		CMCG:write("props wired: %s", table.concat(wired, " "))
	end
end
