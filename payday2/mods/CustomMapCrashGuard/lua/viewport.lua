dofile(ModPath .. "lua/core.lua")

local CMCG = _G.CustomMapCrashGuard

-- Wired once. The classes below are core modules: they may not be imported yet
-- when this file first runs, so gamesetup.lua re-runs it until it takes.
if CMCG.viewport_wired then
	return
end

-- Viewports and their cameras.
--
-- The crash this mod was written for faults inside the viewport update loop:
-- the manager walks its viewports, and for a viewport whose camera reports a
-- change it walks a second list hanging off that viewport and calls a virtual
-- on each entry. One entry is freed memory. So every viewport that is created
-- or destroyed is traced, with the Lua code that asked for it, and a second
-- destroy on the same viewport is dropped.

local manager_class = _G.ViewportManager

if not manager_class and _G.core then
	local ok, mod = pcall(core.import, core, "CoreViewportManager")
	manager_class = ok and mod and mod.ViewportManager or nil
end

local viewport_class = nil

if _G.core then
	local ok, mod = pcall(core.import, core, "CoreViewport")
	viewport_class = ok and mod and mod.Viewport or nil
end

if manager_class then
	local new_vp = manager_class.new_vp

	if new_vp then
		function manager_class:new_vp(x, y, w, h, name, prio, ...)
			local vp = new_vp(self, x, y, w, h, name, prio, ...)

			CMCG:write("viewport + new_vp name=%s prio=%s -> %s | %s",
				tostring(name), tostring(prio), tostring(vp), CMCG:stack(3))

			return vp
		end
	end

	for _, fname in ipairs({"destroy_vp", "delete_vp", "remove_vp", "destroy_all_vp"}) do
		local original = manager_class[fname]

		if original then
			manager_class[fname] = function(self, vp, ...)
				CMCG:write("viewport - %s %s | %s", fname, tostring(vp), CMCG:stack(3))

				return original(self, vp, ...)
			end
		end
	end
	CMCG.viewport_wired = true
end

if viewport_class and viewport_class.destroy then
	local destroy = viewport_class.destroy
	local destroyed = {}

	function viewport_class:destroy(...)
		local key = tostring(self)

		if destroyed[key] then
			CMCG:write("viewport ! double destroy of %s%s | %s", key,
				CMCG.guards.double_destroy_viewport and " dropped" or "", CMCG:stack(3))

			if CMCG.guards.double_destroy_viewport then
				return
			end
		end

		destroyed[key] = true

		CMCG:write("viewport - destroy %s | %s", key, CMCG:stack(3))

		return destroy(self, ...)
	end
end
