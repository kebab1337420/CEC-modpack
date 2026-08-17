dofile(ModPath .. "lua/core.lua")

local CMCG = _G.CustomMapCrashGuard

-- Mission elements. A custom map that dies a fixed number of seconds after the
-- world is built is almost always dying on something its own mission script
-- ran. Every executed element is written to the file, so the last line before
-- the crash names the element -- id, class and editor name -- that did it.

-- Wired once, re-run by gamesetup.lua until the core module is imported.
if CMCG.mission_wired then
	return
end

local element_class = _G.MissionScriptElement

if not element_class and _G.core then
	local ok, mod = pcall(core.import, core, "CoreMissionScriptElement")
	element_class = ok and mod and mod.MissionScriptElement or nil
end

if not element_class then
	return
end

CMCG.mission_wired = true

-- _values.class is not set on every element, so the class is resolved from the
-- instance's metatable against the global class tables. Built once, on the first
-- element that needs it.
local class_names = nil

local function class_of(self)
	local mt = getmetatable(self)

	if type(mt) ~= "table" then
		return "?"
	end

	if not class_names then
		class_names = {}

		for name, value in pairs(_G) do
			if type(value) == "table" and type(name) == "string" then
				class_names[value] = name
			end
		end
	end

	return class_names[mt] or "?"
end

local function describe(self)
	local values = self._values or {}
	local name = values.editor_name or (self.editor_name and self:editor_name()) or "?"
	local id = values.id or (self.id and self:id()) or "?"

	return string.format("%s id=%s name=%s", tostring(values.class or class_of(self)), tostring(id), tostring(name))
end

local on_executed = element_class.on_executed

if on_executed then
	function element_class:on_executed(instigator, ...)
		CMCG:write("element > %s", describe(self))

		return on_executed(self, instigator, ...)
	end
end

-- on_executed only covers the element that fires; the ones that do their work
-- in on_script_activated (spawners, vehicles, unit setups) run once at level
-- start and are exactly the ones that hand the engine a broken object.
local on_script_activated = element_class.on_script_activated

if on_script_activated then
	function element_class:on_script_activated(...)
		CMCG:write("element * activate %s", describe(self))

		return on_script_activated(self, ...)
	end
end
