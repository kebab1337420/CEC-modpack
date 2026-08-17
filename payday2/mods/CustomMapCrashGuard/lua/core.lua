-- Custom Map Crash Guard -- shared logger and guard switches.
--
-- Custom maps die on engine-side access violations with no Lua stack, and the
-- normal BLT log is buffered: the lines written in the last frames before the
-- fault are lost with the process. Every line here is written with an
-- open/append/close, so the file on disk is always complete up to the
-- instruction that faulted. The last line is the crash site, in Lua terms.
--
-- Loaded once, from every hook script of this mod.

if _G.CustomMapCrashGuard then
	return
end

local CMCG = {}
_G.CustomMapCrashGuard = CMCG

CMCG.VERSION = "2.3"

-- Guards that actually change behaviour. Trace-only by default except for the
-- ones that cannot make anything worse.
CMCG.guards = {
	-- Ignore destroy_workspace() on a workspace that was already handed back.
	-- A double destroy frees a workspace the Gui still has in its list.
	double_destroy_workspace = true,
	-- Ignore Viewport:destroy() called twice on the same viewport.
	double_destroy_viewport = true
}

local path = (_G.SavePath or "") .. "crashguard.log"
CMCG.path = path

local function now()
	if _G.Application and Application.time then
		local ok, t = pcall(Application.time, Application)
		if ok and t then
			return t
		end
	end

	return os.clock()
end

CMCG.now = now

-- A tree dump of a level full of gui props is tens of thousands of lines, and
-- one open/append/close per line takes minutes. During a dump the handle is kept
-- open and flushed per line instead: the file on disk is still complete up to
-- the faulting instruction, which is the only property that matters here.
function CMCG:open_batch()
	if self.batch then
		return
	end

	self.batch = io.open(path, "a")
end

function CMCG:close_batch()
	if not self.batch then
		return
	end

	pcall(function()
		self.batch:close()
	end)

	self.batch = nil
end

-- Every line is flushed by closing the file, or by an explicit flush inside a
-- batch. Slow on purpose.
function CMCG:write(fmt, ...)
	local line

	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, fmt, ...)
		line = ok and formatted or tostring(fmt)
	else
		line = tostring(fmt)
	end

	-- Application.time reads 0 for the whole of level load, so a sequence number
	-- carries the ordering instead.
	self.seq = (self.seq or 0) + 1

	line = string.format("[%6d %8.2f] %s", self.seq, now(), line)

	if self.batch then
		self.batch:write(line, "\n")
		self.batch:flush()
	else
		local f = io.open(path, "a")

		if f then
			f:write(line, "\n")
			f:close()
		end
	end

	if not self.batch then
		log("[CrashGuard] " .. line)
	end
end

function CMCG:stack(depth)
	local ok, stack = pcall(debug.traceback, "", depth or 3)

	if not ok or type(stack) ~= "string" then
		return "?"
	end

	local lines = {}

	for entry in stack:gmatch("[^\r\n]+") do
		entry = entry:gsub("^%s+", "")

		if entry ~= "stack traceback:" then
			lines[#lines + 1] = entry
		end

		if #lines >= 3 then
			break
		end
	end

	return table.concat(lines, " <- ")
end

-- New session: truncate, so the file only ever holds the run that is being
-- looked at.
local f = io.open(path, "w")

if f then
	f:write(string.format("=== Custom Map Crash Guard %s, new session ===\n", CMCG.VERSION))
	f:close()
end

CMCG:write("logger up, file %s", path)
