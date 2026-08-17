-- CEC Heist Timeline
--
-- A heist gives no history. The HUD says what is happening right now and the
-- end screen says what happened in total, but nothing in between tells you how
-- long the current assault has been running, when the alarm actually went off,
-- or in what order the bags went out. On a long loud job that is exactly the
-- information the crew argues about afterwards.
--
-- This keeps a timestamped log of the events that matter and draws the last
-- few lines on the HUD. Times are counted from the moment the level finished
-- loading, which is as close to "heist start" as the client can observe.
--
-- Read-only: every entry comes from a post hook that only looks at state the
-- game already computed. The log is local and is thrown away between heists.

if CECTimeline then
	return
end

CECTimeline = {}

CECTimeline.x = 24
CECTimeline.y = 300
CECTimeline.font_size = 18
CECTimeline.max_lines = 6

CECTimeline._entries = {}
CECTimeline._visible = true
CECTimeline._start_t = nil

function CECTimeline:_game_time()
	local ok, t = pcall(function()
		return TimerManager:game():time()
	end)

	return ok and t or nil
end

function CECTimeline:Reset()
	self._entries = {}
	self._start_t = self:_game_time()
	self._dirty = true

	self:Add("Debut du braquage")
end

-- Entries are appended and the oldest ones dropped, so the table never grows
-- past what can be drawn plus a small margin for the log dump.
function CECTimeline:Add(text)
	local now = self:_game_time()

	if not now then
		return
	end

	self._start_t = self._start_t or now

	local elapsed = math.max(now - self._start_t, 0)

	table.insert(self._entries, {
		stamp = string.format("%02d:%02d", math.floor(elapsed / 60), math.floor(elapsed % 60)),
		text = text
	})

	while #self._entries > self.max_lines do
		table.remove(self._entries, 1)
	end

	self._dirty = true

	log("[CEC Heist Timeline] " .. self._entries[#self._entries].stamp .. " " .. text)
end

function CECTimeline:Toggle()
	self._visible = not self._visible
	self._dirty = true

	if alive(self._text) then
		pcall(function()
			self._text:set_visible(self._visible)
		end)
	end
end

function CECTimeline:Create(hud)
	if not hud or not hud.panel then
		return
	end

	local existing = hud.panel:child("cec_heist_timeline")
	if existing then
		hud.panel:remove(existing)
	end

	local ok, text = pcall(function()
		return hud.panel:text({
			name = "cec_heist_timeline",
			text = "",
			font = tweak_data.hud.medium_font,
			font_size = self.font_size,
			color = Color(1, 0.85, 0.85, 0.85),
			align = "left",
			vertical = "top",
			halign = "left",
			valign = "top",
			word_wrap = false,
			wrap = false,
			layer = 1,
			x = self.x,
			y = self.y,
			w = 460,
			h = self.font_size * (self.max_lines + 1)
		})
	end)

	if not ok or not text then
		log("[CEC Heist Timeline] could not create the HUD text, mod inactive")
		return
	end

	pcall(function()
		text:set_visible(self._visible)
	end)

	self._text = text
	self._dirty = true
end

-- Rebuilt only when an entry was added or the panel was toggled: the lines are
-- static between events, so there is nothing to do most frames.
function CECTimeline:Update()
	if not self._dirty then
		return
	end

	local text = self._text

	if not alive(text) then
		self._text = nil

		return
	end

	self._dirty = false

	local lines = {}

	for _, entry in ipairs(self._entries) do
		table.insert(lines, entry.stamp .. "  " .. entry.text)
	end

	pcall(function()
		text:set_text(table.concat(lines, "\n"))
	end)
end
