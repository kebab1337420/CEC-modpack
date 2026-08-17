dofile(ModPath .. "lua/core.lua")

local CMCG = _G.CustomMapCrashGuard

-- Native Gui tree instrumentation and guards.
--
-- The crash this mod exists for is an access violation at PAYDAY2.exe+0xa8f666:
--
--     mov rbx, [rcx + 0x110]   ; children vector begin
--     mov rdi, [rcx + 0x118]   ; children vector end   (2 entries)
--     mov rcx, [rbx]           ; first child pointer
--     mov rax, [rcx]           ; its vtable          -> garbage
--     call [rax + 0x78]        ; per-frame update    -> fault
--
-- The caller walks the Gui's workspace list at [gui + 0x70 .. 0x78) and takes
-- each workspace's root panel at +0x68. So: a live workspace still in the Gui
-- list owns a root panel whose first child has been freed while the parent's
-- children vector still points at it.
--
-- In Diesel a userdata's metatable *is* its method table (the engine's own code
-- does getmetatable(SystemInfo).is_vr), so the native Gui, Workspace and Panel
-- classes can be wrapped from Lua. That is what happens below: every object
-- that enters or leaves the tree is logged, and the three ways to leave a
-- dangling pointer behind are refused.

if CMCG.gui_wired then
	return
end

local function key_of(obj)
	local ok, k = pcall(function()
		return obj:key()
	end)

	if ok and k then
		return tostring(k)
	end

	return tostring(obj)
end

CMCG.key_of = key_of

-- Objects handed back to the engine. Keyed by engine key, so a second userdata
-- wrapper for the same native object is still recognised.
CMCG.dead = CMCG.dead or {}
-- Workspaces the Gui still owns.
CMCG.live_workspaces = CMCG.live_workspaces or {}

local function patch(mt, name, wrapper)
	if not mt then
		return false
	end

	local original = mt[name]

	if type(original) ~= "function" then
		return false
	end

	mt[name] = wrapper(original)

	return true
end

-- Reaching the metatables ---------------------------------------------------

local function metatables()
	if not _G.Overlay then
		return nil
	end

	local ok, gui = pcall(function()
		return Overlay:gui()
	end)

	if not ok or not gui then
		return nil
	end

	local gui_mt = getmetatable(gui)

	if type(gui_mt) ~= "table" then
		return nil
	end

	-- A throwaway workspace is the only way to reach the Workspace and Panel
	-- metatables without waiting for the game to make one.
	local ok_ws, ws = pcall(function()
		return gui:create_scaled_screen_workspace(10, 10, 10, 10, 10)
	end)

	if not ok_ws or not ws then
		return {gui = gui_mt}
	end

	local ws_mt = getmetatable(ws)
	local panel_mt

	local ok_panel, panel = pcall(function()
		return ws:panel()
	end)

	if ok_panel and panel then
		panel_mt = getmetatable(panel)
	end

	pcall(function()
		gui:destroy_workspace(ws)
	end)

	return {
		gui = gui_mt,
		workspace = type(ws_mt) == "table" and ws_mt or nil,
		panel = type(panel_mt) == "table" and panel_mt or nil
	}
end

-- Tree dump ----------------------------------------------------------------

-- Walks what Lua can see of a panel, the same vector the engine walks. Anything
-- that throws is a broken node and gets named.
local function dump(obj, depth, out, prefix)
	depth = depth or 0

	if depth > 6 then
		return
	end

	local ok_children, children = pcall(function()
		return obj:children()
	end)

	if not ok_children or type(children) ~= "table" then
		return
	end

	for i, child in ipairs(children) do
		local k = key_of(child)
		local ok_name, name = pcall(function()
			return child:name()
		end)
		local ok_vis, vis = pcall(function()
			return child:visible()
		end)
		local ok_alive = pcall(function()
			local _ = child:layer()
			local _ = child:parent()
		end)

		out[#out + 1] = string.format(
			"%s[%d] %s name=%s vis=%s%s%s",
			prefix,
			i,
			k,
			ok_name and tostring(name) or "?",
			ok_vis and tostring(vis) or "?",
			ok_alive and "" or " <<< UNREADABLE",
			CMCG.dead[k] and " <<< ALREADY DESTROYED" or ""
		)

		dump(child, depth + 1, out, prefix .. "  ")
	end
end

-- Dumps every workspace this mod knows about, root panel first. Called every
-- frame for the first seconds of a level, so the tail of the log is the state
-- of the tree on the frame that faulted.
function CMCG:dump_tree(tag)
	local out = {}
	local count = 0

	for k, ws in pairs(self.live_workspaces) do
		count = count + 1

		local ok_panel, panel = pcall(function()
			return ws:panel()
		end)

		if not ok_panel or not panel then
			out[#out + 1] = string.format("ws %s <<< ROOT PANEL UNREADABLE", k)
		else
			out[#out + 1] = string.format("ws %s root=%s", k, key_of(panel))

			dump(panel, 0, out, "    ")
		end
	end

	self:write("tree %s: %d workspace(s)", tostring(tag), count)

	for _, line in ipairs(out) do
		self:write("  %s", line)
	end
end

-- Wiring -------------------------------------------------------------------

function CMCG:wire_gui()
	if self.gui_wired then
		return true
	end

	local mts = metatables()

	if not mts or not mts.gui then
		return false
	end

	local wired = {}

	-- Gui: workspace creation and destruction. Every workspace the engine hands
	-- out is tracked here, which is the list the faulting loop walks.
	for _, name in ipairs({
		"create_scaled_screen_workspace",
		"create_screen_workspace",
		"create_world_workspace",
		"create_linked_workspace",
		"create_object_workspace"
	}) do
		if patch(mts.gui, name, function(original)
			return function(gui, ...)
				CMCG:write("gui > %s", name)

				local ws = original(gui, ...)
				local k = key_of(ws)

				CMCG.live_workspaces[k] = ws
				CMCG.dead[k] = nil

				CMCG:write("gui + %s -> ws %s | %s", name, k, CMCG:stack(3))

				return ws
			end
		end) then
			wired[#wired + 1] = name
		end
	end

	if patch(mts.gui, "destroy_workspace", function(original)
		return function(gui, ws, ...)
			if ws == nil then
				CMCG:write("gui ! destroy_workspace(nil) dropped | %s", CMCG:stack(3))

				return
			end

			local k = key_of(ws)

			if CMCG.dead[k] then
				CMCG:write("gui ! destroy_workspace(%s) already destroyed, dropped | %s", k, CMCG:stack(3))

				return
			end

			CMCG:write("gui - destroy_workspace %s | %s", k, CMCG:stack(3))

			CMCG.dead[k] = true
			CMCG.live_workspaces[k] = nil

			return original(gui, ws, ...)
		end
	end) then
		wired[#wired + 1] = "destroy_workspace"
	end

	-- Panel: everything that adds or drops a node. The additions are logged
	-- only at debug volume; the removals are what matter.
	if mts.panel then
		for _, name in ipairs({"panel", "rect", "bitmap", "text", "gui", "video", "polyline"}) do
			if patch(mts.panel, name, function(original)
				return function(panel, ...)
					local child = original(panel, ...)

					if child ~= nil then
						CMCG.dead[key_of(child)] = nil
					end

					return child
				end
			end) then
				wired[#wired + 1] = "panel:" .. name
			end
		end

		-- remove() frees the object. Three ways this leaves the engine walking
		-- freed memory, all refused here:
		--   nil            -- nothing to free, engine may still deref
		--   already dead   -- double free
		--   wrong parent   -- frees the object but the real parent's children
		--                     vector keeps pointing at it. This is exactly the
		--                     dangling first child the fault site trips over.
		if patch(mts.panel, "remove", function(original)
			return function(panel, child, ...)
				if child == nil then
					CMCG:write("panel ! remove(nil) dropped | %s", CMCG:stack(3))

					return
				end

				local k = key_of(child)
				local pk = key_of(panel)

				if CMCG.dead[k] then
					CMCG:write("panel ! remove(%s) already destroyed, dropped | %s", k, CMCG:stack(3))

					return
				end

				local ok_parent, parent = pcall(function()
					return child:parent()
				end)

				if ok_parent and parent ~= nil then
					local real = key_of(parent)

					if real ~= pk then
						CMCG:write(
							"panel !! remove(%s) from %s but real parent is %s -- DROPPED, this would dangle | %s",
							k,
							pk,
							real,
							CMCG:stack(3)
						)

						return
					end
				end

				CMCG:write("panel - remove %s from %s | %s", k, pk, CMCG:stack(3))

				CMCG.dead[k] = true

				return original(panel, child, ...)
			end
		end) then
			wired[#wired + 1] = "panel:remove"
		end

		if patch(mts.panel, "clear", function(original)
			return function(panel, ...)
				local pk = key_of(panel)
				local names = {}

				local ok, children = pcall(function()
					return panel:children()
				end)

				if ok and type(children) == "table" then
					for _, child in ipairs(children) do
						local k = key_of(child)

						CMCG.dead[k] = true
						names[#names + 1] = k
					end
				end

				CMCG:write("panel - clear %s (%d children: %s) | %s", pk, #names, table.concat(names, ","), CMCG:stack(3))

				return original(panel, ...)
			end
		end) then
			wired[#wired + 1] = "panel:clear"
		end
	end

	if mts.workspace then
		if patch(mts.workspace, "panel", function(original)
			return function(ws, ...)
				return original(ws, ...)
			end
		end) then
			wired[#wired + 1] = "workspace:panel"
		end
	end

	self.gui_wired = true

	self:write("gui wired (%d): %s", #wired, table.concat(wired, " "))
	self:write(
		"gui metatables: gui=%s workspace=%s panel=%s",
		tostring(mts.gui ~= nil),
		tostring(mts.workspace ~= nil),
		tostring(mts.panel ~= nil)
	)

	return true
end

CMCG:wire_gui()
