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
-- What each object is: "panel" for containers, otherwise the creator name. Only
-- panels may be asked for their children.
CMCG.kind = CMCG.kind or {}
-- Where each object came from, so a broken node names its creation site.
CMCG.origin = CMCG.origin or {}

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

-- Only the root panels matter -------------------------------------------------
--
-- The fault site reads the children vector of the object at workspace + 0x68,
-- which is the workspace's root panel, and calls the first child's virtual
-- method. So the broken parent is always a root panel, and the broken child is
-- always one of its direct children. There is no need to walk the tree deeply --
-- and no way to do it safely, because every Gui object shares one metatable, so
-- children() on a Bitmap or a Text reads +0x110/+0x118 on bytes that are not a
-- vector and faults exactly like the bug being hunted. Depth 0 only.
--
-- A child is a suspect when the structure says the engine would deref freed
-- memory:
--   * it does not answer its accessors at all
--   * this mod saw it removed or cleared, yet it is still in the vector
--   * its own parent() is not the panel that lists it -- a dangling entry
--
-- kind == nil is *not* a suspect: objects loaded from a .gui file are created
-- natively and were never seen by Lua.
local function inspect_root(panel, root, prefix)
	local ok_children, children = pcall(function()
		return panel:children()
	end)

	if not ok_children or type(children) ~= "table" then
		CMCG:write("%s<<< children() FAILED on root %s", prefix, root)

		return true
	end

	local suspect = false

	CMCG:write("%s%d child(ren)", prefix, #children)

	for i, child in ipairs(children) do
		-- Written before the child is touched, so if reading it faults the log
		-- already names the root panel and the index.
		CMCG:write("%s[%d] probing under root %s", prefix, i, root)

		local k = key_of(child)
		local kind = CMCG.kind[k]

		local ok_name, name = pcall(function()
			return child:name()
		end)
		local ok_vis, vis = pcall(function()
			return child:visible()
		end)
		local ok_layer = pcall(function()
			local _ = child:layer()
		end)

		local parent_key = "?"
		local ok_parent, parent = pcall(function()
			return child:parent()
		end)

		if ok_parent and parent ~= nil then
			parent_key = key_of(parent)
		end

		local dangling = ok_parent and parent ~= nil and parent_key ~= root
		local unreadable = not ok_name or not ok_vis or not ok_layer or not ok_parent

		if dangling or unreadable or CMCG.dead[k] then
			suspect = true
		end

		CMCG:write(
			"%s[%d] %s kind=%s name=%s vis=%s parent=%s%s%s%s",
			prefix,
			i,
			k,
			tostring(kind or "not-from-lua"),
			ok_name and tostring(name) or "?",
			ok_vis and tostring(vis) or "?",
			parent_key,
			unreadable and " <<< UNREADABLE" or "",
			CMCG.dead[k] and " <<< ALREADY DESTROYED" or "",
			dangling and " <<< DANGLING, parent does not match" or ""
		)

		if dangling or unreadable or CMCG.dead[k] then
			CMCG:write("%s     origin: %s", prefix, tostring(CMCG.origin[k] or "unknown"))
		end
	end

	return suspect
end

-- Walks every workspace this mod knows about and quarantines the broken ones.
--
-- Quarantine is the fix, not just a trace: a workspace whose root panel lists a
-- child the engine would deref is handed back with destroy_workspace, which takes
-- it out of the Gui's workspace list at [gui + 0x70 .. 0x78). The per-frame walk
-- then never reaches it. Losing one gui prop is the whole cost.
--
-- Called on the first update ticks of the level, before the frame the fault
-- normally lands on.
function CMCG:dump_tree(tag)
	local count = 0

	for _ in pairs(self.live_workspaces) do
		count = count + 1
	end

	self:write(
		"tree %s: %d workspace(s), object workspaces ok=%d refused=%d",
		tostring(tag),
		count,
		self.object_ws_ok or 0,
		self.object_ws_refused or 0
	)
	self:open_batch()

	local quarantine = {}

	for k, ws in pairs(self.live_workspaces) do
		local ok_panel, panel = pcall(function()
			return ws:panel()
		end)

		if not ok_panel or not panel then
			self:write("ws %s <<< ROOT PANEL UNREADABLE | origin: %s", k, tostring(self.origin[k] or "unknown"))

			quarantine[#quarantine + 1] = k
		else
			local root = key_of(panel)

			self.kind[root] = "panel"

			self:write("ws %s root=%s", k, root)

			if inspect_root(panel, root, "    ") then
				quarantine[#quarantine + 1] = k
			end
		end
	end

	self:close_batch()

	-- Collected first, destroyed after the walk: destroying inside the pairs loop
	-- would mutate live_workspaces while it is being iterated.
	for _, k in ipairs(quarantine) do
		local ws = self.live_workspaces[k]

		self:write("QUARANTINE ws %s | origin: %s", k, tostring(self.origin[k] or "unknown"))

		if ws ~= nil then
			-- Hidden first: if destroy_workspace itself is what faults, a hidden
			-- workspace is at least skipped by the render walk.
			pcall(function()
				ws:hide()
			end)

			local ok_gui, gui = pcall(function()
				return ws:gui()
			end)

			if ok_gui and gui ~= nil then
				local ok_destroy = pcall(function()
					gui:destroy_workspace(ws)
				end)

				self:write("QUARANTINE ws %s destroyed=%s", k, tostring(ok_destroy))
			else
				self:write("QUARANTINE ws %s has no reachable gui, left hidden", k)
			end

			self.live_workspaces[k] = nil
			self.dead[k] = true
		end
	end

	self:write("tree %s done, %d quarantined", tostring(tag), #quarantine)
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
				CMCG.kind[k] = "workspace"
				CMCG.origin[k] = name .. " | " .. CMCG:stack(4)

				CMCG:write("gui + %s -> ws %s | %s", name, k, CMCG:stack(3))

				return ws
			end
		end) then
			wired[#wired + 1] = name
		end
	end

	-- create_object_workspace links the workspace to an object of a unit, and the
	-- engine derefs that link every frame it walks the workspace. Every gui prop
	-- passes unit:get_object(Idstring(self._gui_object)), which returns nil when the
	-- unit's model has no object under that name -- and nothing in Lua fails when it
	-- does: the workspace is created, the panel and the .gui file load, the text is
	-- set, init returns. The null link only bites on the first frame the engine
	-- walks the workspace list, as an access violation with no Lua stack. Custom and
	-- dev maps hit this whenever a placed unit lost the gui object its saved data
	-- still names.
	--
	-- Refused here. A hidden screen workspace is handed back instead of nil, so the
	-- caller's ws:panel() and everything built on it keeps working and the prop is
	-- simply invisible.
	CMCG.object_ws_ok = CMCG.object_ws_ok or 0
	CMCG.object_ws_refused = CMCG.object_ws_refused or 0

	if patch(mts.gui, "create_object_workspace", function(original)
		return function(gui, w, h, object, offset, ...)
			local ok, usable = pcall(function()
				return object ~= nil and alive(object)
			end)

			if not ok or not usable then
				CMCG.object_ws_refused = CMCG.object_ws_refused + 1

				CMCG:write(
					"gui !! create_object_workspace on a dead object (%s) -- REFUSED, prop goes invisible | %s",
					tostring(object),
					CMCG:stack(3)
				)

				local ws = gui:create_scaled_screen_workspace(10, 10, 10, 10, 10)

				pcall(function()
					ws:hide()
				end)

				return ws
			end

			CMCG.object_ws_ok = CMCG.object_ws_ok + 1

			return original(gui, w, h, object, offset, ...)
		end
	end) then
		wired[#wired + 1] = "create_object_workspace:dead-object-guard"
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

	-- Panel: everything that adds or drops a node. Creation is not logged line by
	-- line -- there are thousands -- but every object is recorded with its kind
	-- and its creation site, which is what names a broken node later. Only the
	-- objects recorded as "panel" may be asked for their children.
	if mts.panel then
		-- Only panel() is known to produce something with a children vector.
		-- gui(), video() and the rest are treated as leaves: guessing wrong here
		-- means faulting on children() the way the last run did.
		local container = {
			panel = true
		}

		for _, name in ipairs({"panel", "rect", "bitmap", "text", "gui", "video", "polyline"}) do
			if patch(mts.panel, name, function(original)
				return function(panel, ...)
					local child = original(panel, ...)

					if child ~= nil then
						local k = key_of(child)

						CMCG.dead[k] = nil
						CMCG.kind[k] = container[name] and "panel" or name
						CMCG.origin[k] = string.format("%s on %s | %s", name, key_of(panel), CMCG:stack(4))
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
