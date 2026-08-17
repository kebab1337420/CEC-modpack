-- CEC Mod Conflict Checker
--
-- Reports the two ways mods in this pack step on each other:
--
--   1. two mods hooking the same engine file. That is legal and usually fine,
--      but when a mod stops working it is nearly always because another one
--      replaced the same function instead of chaining onto it, so the list is
--      the first thing to look at.
--   2. two mod_overrides folders shipping the same asset path. Here only one
--      file wins and the loser is silently ignored, which is a real conflict.
--
-- Output goes to the BLT log and to cec_conflicts.txt in the save directory. A
-- notification is raised only when something was found, so a clean pack stays
-- quiet.

if CECConflictChecker then
	return
end

CECConflictChecker = {}

CECConflictChecker.report_name = "cec_conflicts.txt"
CECConflictChecker.overrides_dir = "assets/mod_overrides/"

-- Depth and file caps: mod_overrides can hold tens of thousands of files in a
-- big pack and this runs on the main thread while the menu is coming up.
CECConflictChecker.max_depth = 8
CECConflictChecker.max_files = 20000

function CECConflictChecker:_write_dir()
	local path = rawget(_G, "SavePath")
	if type(path) == "string" and path ~= "" then
		return path
	end
	return ModPath
end

-- hook_id -> list of mod names, for one of the two hook tables.
function CECConflictChecker:_hook_owners(getter)
	local owners = {}
	local mods = BLT and BLT.Mods and BLT.Mods:Mods() or {}

	for _, mod in ipairs(mods) do
		local ok, hooks, name = pcall(function()
			return mod[getter](mod), mod:GetName()
		end)
		if ok and type(hooks) == "table" then
			for _, hook_id in ipairs(hooks) do
				-- "*" is the wildcard hook: it matches every file by design and
				-- says nothing about a conflict.
				if hook_id ~= "*" then
					owners[hook_id] = owners[hook_id] or {}
					table.insert(owners[hook_id], name)
				end
			end
		end
	end

	return owners
end

function CECConflictChecker:_shared_hooks(getter)
	local shared = {}

	for hook_id, names in pairs(self:_hook_owners(getter)) do
		if #names > 1 then
			table.sort(names)
			table.insert(shared, { hook_id = hook_id, mods = names })
		end
	end

	table.sort(shared, function(a, b)
		return a.hook_id < b.hook_id
	end)

	return shared
end

-- Relative asset paths inside one mod_overrides folder.
function CECConflictChecker:_collect_assets(root, prefix, depth, out, counter)
	if depth > self.max_depth or counter.n >= self.max_files then
		return
	end

	local ok, files = pcall(function()
		return file.GetFiles(root)
	end)
	if ok and type(files) == "table" then
		for _, name in ipairs(files) do
			counter.n = counter.n + 1
			if counter.n >= self.max_files then
				return
			end
			table.insert(out, prefix .. name)
		end
	end

	local ok_dirs, dirs = pcall(function()
		return file.GetDirectories(root)
	end)
	if ok_dirs and type(dirs) == "table" then
		for _, name in ipairs(dirs) do
			self:_collect_assets(root .. name .. "/", prefix .. name .. "/", depth + 1, out, counter)
		end
	end
end

function CECConflictChecker:_shared_assets()
	local owners = {}
	local counter = { n = 0 }

	local ok, folders = pcall(function()
		return file.GetDirectories(self.overrides_dir)
	end)
	if not ok or type(folders) ~= "table" then
		return {}
	end

	for _, folder in ipairs(folders) do
		local assets = {}
		self:_collect_assets(self.overrides_dir .. folder .. "/", "", 1, assets, counter)
		for _, asset in ipairs(assets) do
			owners[asset] = owners[asset] or {}
			table.insert(owners[asset], folder)
		end
	end

	local shared = {}
	for asset, folders_using in pairs(owners) do
		if #folders_using > 1 then
			table.sort(folders_using)
			table.insert(shared, { asset = asset, mods = folders_using })
		end
	end

	table.sort(shared, function(a, b)
		return a.asset < b.asset
	end)

	return shared
end

function CECConflictChecker:_broken_mods()
	local broken = {}
	local mods = BLT and BLT.Mods and BLT.Mods:Mods() or {}

	for _, mod in ipairs(mods) do
		pcall(function()
			local errors = mod:Errors()
			if errors then
				table.insert(broken, mod:GetName() .. ": " .. table.concat(errors, ", "))
			end
		end)
	end

	table.sort(broken)
	return broken
end

function CECConflictChecker:Scan()
	return {
		post_hooks = self:_shared_hooks("GetHooks"),
		pre_hooks = self:_shared_hooks("GetPreHooks"),
		assets = self:_shared_assets(),
		broken = self:_broken_mods()
	}
end

function CECConflictChecker:_format(result)
	local out = {}
	local function add(text)
		table.insert(out, text or "")
	end

	add("=== CEC mod conflict report ===")
	add("date: " .. tostring(os.date("%Y-%m-%d %H:%M:%S")))
	add("")

	add("--- mods failing to load (" .. #result.broken .. ") ---")
	for _, line in ipairs(result.broken) do
		add("  " .. line)
	end
	add("")

	local function hook_section(title, list)
		add("--- " .. title .. " (" .. #list .. ") ---")
		for _, entry in ipairs(list) do
			add("  " .. entry.hook_id .. "  <-  " .. table.concat(entry.mods, ", "))
		end
		add("")
	end

	hook_section("engine files hooked by several mods (post)", result.post_hooks)
	hook_section("engine files hooked by several mods (pre)", result.pre_hooks)

	add("--- mod_overrides assets claimed by several mods (" .. #result.assets .. ") ---")
	add("  these are real conflicts: only one file is loaded.")
	for _, entry in ipairs(result.assets) do
		add("  " .. entry.asset .. "  <-  " .. table.concat(entry.mods, ", "))
	end

	return table.concat(out, "\n")
end

function CECConflictChecker:Run()
	if self._done then
		return
	end
	self._done = true

	local ok, result = pcall(function()
		return self:Scan()
	end)
	if not ok then
		log("[CEC Mod Conflict Checker] scan failed: " .. tostring(result))
		return
	end

	local path = self:_write_dir() .. self.report_name
	pcall(function()
		local handle = io.open(path, "w")
		if handle then
			handle:write(self:_format(result))
			handle:close()
		end
	end)

	log(string.format("[CEC Mod Conflict Checker] %d broken mods, %d shared hooks, %d asset clashes -> %s",
		#result.broken, #result.post_hooks + #result.pre_hooks, #result.assets, path))

	-- Only the asset clashes and the load failures are worth interrupting the
	-- user for; shared hooks are informational.
	local urgent = #result.assets + #result.broken
	if urgent > 0 and BLT and BLT.Notifications then
		pcall(function()
			BLT.Notifications:add_notification({
				title = "Mod conflicts detected",
				text = string.format("%d broken mods, %d asset clashes.\nDetails: %s",
					#result.broken, #result.assets, path),
				priority = 90,
				color = Color(0.95, 0.6, 0.1)
			})
		end)
	end
end
