-- CEC Crash Reporter
--
-- Collects everything a bug report needs into a single text file, so the user
-- only has to paste one file instead of hunting for logs, mod versions and the
-- engine crash dump separately.
--
-- Two triggers:
--   * automatically, when the previous session did not shut down cleanly. A
--     sentinel file is written when the main menu comes up and deleted when the
--     game is quit through the menu; finding it at startup means the process
--     died in between.
--   * manually, through the keybind declared in mod.txt.
--
-- Every engine call is wrapped in pcall: this mod must never be the reason a
-- crash report cannot be produced.

if CECCrashReporter then
	return
end

CECCrashReporter = {}

CECCrashReporter.report_name = "cec_crash_report.txt"
CECCrashReporter.sentinel_name = "cec_session_open.txt"
CECCrashReporter.logs_dir = "mods/logs/"

-- Where writable files live. SavePath is provided by SuperBLT and points at the
-- user's save directory, which is writable even for a Steam install sitting in
-- Program Files. ModPath is only a fallback for odd setups.
function CECCrashReporter:_write_dir()
	local path = rawget(_G, "SavePath")
	if type(path) == "string" and path ~= "" then
		return path
	end
	return ModPath
end

function CECCrashReporter:_read_file(path, max_bytes)
	local handle = io.open(path, "r")
	if not handle then
		return nil
	end

	local content
	if max_bytes then
		-- Crash dumps end with the interesting part, so keep the tail rather
		-- than the head when the file is too big to embed whole.
		local all = handle:read("*all") or ""
		content = #all > max_bytes and ("...(truncated)...\n" .. all:sub(#all - max_bytes)) or all
	else
		content = handle:read("*all")
	end
	handle:close()

	return content
end

function CECCrashReporter:_delete_file(path)
	local fs = rawget(_G, "SystemFS")
	if fs and fs.delete_file then
		pcall(function()
			fs:delete_file(path)
		end)
		return
	end
	pcall(os.remove, path)
end

-- Newest file in mods/logs/. SuperBLT writes one log per session with the date
-- and time in the name, so a plain string sort gives chronological order.
function CECCrashReporter:_latest_log()
	local ok, files = pcall(function()
		return file.GetFiles(self.logs_dir)
	end)
	if not ok or type(files) ~= "table" then
		return nil
	end

	local newest
	for _, name in ipairs(files) do
		if name:match("%.txt$") and (not newest or name > newest) then
			newest = name
		end
	end

	return newest and (self.logs_dir .. newest) or nil
end

function CECCrashReporter:_mod_lines()
	local lines = {}
	local mods = BLT and BLT.Mods and BLT.Mods:Mods() or {}

	for _, mod in ipairs(mods) do
		local ok, line = pcall(function()
			local state = mod:IsEnabled() and "on " or "off"
			local errors = mod:Errors()
			local suffix = ""
			if errors then
				suffix = "  ERRORS: " .. table.concat(errors, ", ")
			end
			return string.format("  [%s] %s (%s) by %s%s", state, mod:GetName(),
				mod:GetVersion() or "?", mod:GetAuthor() or "?", suffix)
		end)
		table.insert(lines, ok and line or "  [???] <unreadable mod entry>")
	end

	table.sort(lines)
	return lines
end

function CECCrashReporter:BuildReport(reason)
	local out = {}
	local function add(text)
		table.insert(out, text or "")
	end

	add("=== CEC modpack crash report ===")
	add("reason: " .. tostring(reason))
	add("date: " .. tostring(os.date("%Y-%m-%d %H:%M:%S")))
	-- Both accessors exist in every supported build, but a report must still be
	-- produced on the one that does not have them.
	local function safe(fn)
		local ok, value = pcall(fn)
		return ok and tostring(value) or "unknown"
	end

	add("blt version: " .. safe(function()
		return BLT:GetVersion()
	end))
	add("game version: " .. safe(function()
		return Application:version()
	end))
	add("")

	add("--- mods ---")
	for _, line in ipairs(self:_mod_lines()) do
		add(line)
	end
	add("")

	-- crash.txt is written by the engine next to the executable when it dies on
	-- an unhandled fault. It is absent after a clean run.
	local crash = self:_read_file("crash.txt", 20000)
	add("--- crash.txt ---")
	add(crash and crash or "(no crash.txt)")
	add("")

	local log_path = self:_latest_log()
	add("--- " .. tostring(log_path or "no blt log") .. " ---")
	add(log_path and (self:_read_file(log_path, 60000) or "(unreadable)") or "")

	return table.concat(out, "\n")
end

function CECCrashReporter:WriteReport(reason)
	local path = self:_write_dir() .. self.report_name
	local ok, err = pcall(function()
		local handle = io.open(path, "w")
		if not handle then
			error("cannot open " .. path)
		end
		handle:write(self:BuildReport(reason))
		handle:close()
	end)

	if not ok then
		log("[CEC Crash Reporter] failed to write report: " .. tostring(err))
		return nil
	end

	log("[CEC Crash Reporter] report written to " .. path)
	return path
end

function CECCrashReporter:Notify(path, headline)
	if not (BLT and BLT.Notifications) then
		return
	end

	pcall(function()
		BLT.Notifications:add_notification({
			title = "Crash report ready",
			text = tostring(headline) .. "\nReport: " .. tostring(path),
			priority = 100,
			color = Color(0.85, 0.12, 0.12)
		})
	end)
end

-- Called once the main menu exists. Any earlier and there is no notification
-- gui to talk to.
function CECCrashReporter:OnMenuReady()
	if self._menu_done then
		return
	end
	self._menu_done = true

	local sentinel = self:_write_dir() .. self.sentinel_name

	if self:_read_file(sentinel) then
		local path = self:WriteReport("previous session did not exit cleanly")
		if path then
			self:Notify(path, "The last session ended unexpectedly.")
		end
	end

	pcall(function()
		local handle = io.open(sentinel, "w")
		if handle then
			handle:write(tostring(os.date("%Y-%m-%d %H:%M:%S")))
			handle:close()
		end
	end)
end

function CECCrashReporter:OnCleanExit()
	self:_delete_file(self:_write_dir() .. self.sentinel_name)
end
