-- CEC Pager Timer
--
-- Vanilla gives no timer for a ringing pager. The only cues are the radio voice
-- line and the corpse outline starting to flash on the last call, so learning
-- how long you actually have left is guesswork.
--
-- This shows, on the in-heist HUD, how long until the next pager event and
-- which call it is out of the total the dead guard was assigned. When the next
-- event is the one that raises the alarm, the line turns red and says so.
--
-- The countdown is not estimated from tweak data: the exact expiry time is read
-- from the delayed callback CopBrain scheduled, so what is displayed is the
-- real deadline including ECM re-rolls and difficulty differences.

if CECPagerTimer then
	return
end

CECPagerTimer = {}

CECPagerTimer.x = -24
CECPagerTimer.y = 210
CECPagerTimer.font_size = 22

-- Unit key -> { expire_t, call, total, alarm } for every pager currently ringing.
CECPagerTimer._active = {}

function CECPagerTimer:_game_time()
	local ok, t = pcall(function()
		return TimerManager:game():time()
	end)
	return ok and t or nil
end

-- The delayed callback list is the only place the real expiry time lives.
function CECPagerTimer:_expire_time(clbk_id)
	local ok, t = pcall(function()
		local clbks = managers.enemy._delayed_clbks
		if not clbks then
			return nil
		end

		for _, data in ipairs(clbks) do
			if data[1] == clbk_id then
				return data[2]
			end
		end
	end)

	return ok and t or nil
end

-- Called after CopBrain rescheduled its own callback, so the pending expiry is
-- already in place and can be read straight out of the enemy manager.
function CECPagerTimer:Track(brain)
	local ok = pcall(function()
		local data = brain._alarm_pager_data
		local key = brain._unit:key()

		if not data or not data.pager_clbk_id then
			self._active[key] = nil
			return
		end

		local expire_t = self:_expire_time(data.pager_clbk_id)
		if not expire_t then
			self._active[key] = nil
			return
		end

		local total = data.total_nr_calls or 0
		local made = data.nr_calls_made or 0

		self._active[key] = {
			expire_t = expire_t,
			-- nr_calls_made counts calls already rung, so the pending one is
			-- the next number up. Past the total, the pending callback is the
			-- alarm itself rather than another call.
			call = math.min(made + 1, total),
			total = total,
			alarm = made >= total
		}
	end)

	if not ok then
		pcall(function()
			self._active[brain._unit:key()] = nil
		end)
	end
end

function CECPagerTimer:Untrack(brain)
	pcall(function()
		self._active[brain._unit:key()] = nil
	end)
end

function CECPagerTimer:Clear()
	self._active = {}
end

-- Returns the pager that will fire first, because that is the one the crew has
-- to deal with. Expired entries are dropped on the way.
function CECPagerTimer:_soonest(now)
	local best, best_key = nil, nil

	for key, data in pairs(self._active) do
		if data.expire_t + 1 < now then
			self._active[key] = nil
		elseif not best or data.expire_t < best.expire_t then
			best, best_key = data, key
		end
	end

	return best, best_key
end

function CECPagerTimer:Create(hud)
	if not hud or not hud.panel then
		return
	end

	local existing = hud.panel:child("cec_pager_timer")
	if existing then
		hud.panel:remove(existing)
	end

	local ok, text = pcall(function()
		return hud.panel:text({
			name = "cec_pager_timer",
			text = "",
			font = tweak_data.hud.medium_font,
			font_size = self.font_size,
			color = Color(1, 0.9, 0.4),
			align = "right",
			vertical = "top",
			halign = "right",
			valign = "top",
			word_wrap = false,
			wrap = false,
			layer = 1,
			w = 360,
			h = self.font_size * 2,
			y = self.y
		})
	end)

	if not ok or not text then
		log("[CEC Pager Timer] could not create the HUD text, mod inactive")
		return
	end

	pcall(function()
		text:set_right(hud.panel:w() + self.x)
	end)

	self._text = text
	self:Clear()
end

function CECPagerTimer:Update()
	local text = self._text
	if not alive(text) then
		self._text = nil
		return
	end

	local now = self:_game_time()
	if not now then
		return
	end

	local data = self:_soonest(now)
	if not data then
		if self._line ~= "" then
			self._line = ""
			pcall(function()
				text:set_text("")
			end)
		end
		return
	end

	local left = math.max(data.expire_t - now, 0)
	local line

	if data.alarm then
		line = string.format("PAGER - ALARM IN %.1fs", left)
	else
		line = string.format("PAGER %d/%d - %.1fs", data.call, data.total, left)
	end

	if line ~= self._line then
		self._line = line
		pcall(function()
			text:set_text(line)
			-- Red once no call is left to answer: the next tick is the alarm.
			text:set_color(data.alarm and Color(1, 0.3, 0.3) or Color(1, 0.9, 0.4))
		end)
	end
end
