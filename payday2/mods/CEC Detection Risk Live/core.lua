-- CEC Detection Risk Live
--
-- The vanilla detection meter is a small arc that fills up somewhere near the
-- crosshair. It tells you that someone is looking at you, but not how close to
-- full it is, not whether the number is still climbing, and not whether one
-- guard or three are feeding it.
--
-- The value shown here is the same one the meter is drawn from: the maximum
-- suspicion over every observer, with the concealment offset the game applies
-- before display folded in, so a percentage of 100 is the exact point where the
-- meter fills and the guard calls it in.
--
-- Reading only, on the local player. Nothing is written back into the movement
-- extension and nothing is sent to peers.

if CECDetection then
	return
end

CECDetection = {}

CECDetection.x = -24
CECDetection.y = 240
CECDetection.font_size = 22

-- false = nobody looking, true = already spotted, number = meter share 0..1.
CECDetection._ratio = false
CECDetection._observers = 0

function CECDetection:Feed(movement)
	pcall(function()
		if movement._unit ~= managers.player:player_unit() then
			return
		end

		local ratio = movement._suspicion_ratio

		if type(ratio) == "number" then
			-- suspicion_settings().hud_offset is the head start the meter is drawn
			-- with, so applying it here keeps 100% meaning "meter full".
			local offset = movement._unit:base():suspicion_settings().hud_offset

			ratio = ratio * (1 - offset) + offset
		end

		self._ratio = ratio

		local count = 0

		for _, _ in pairs(movement._suspicion or {}) do
			count = count + 1
		end

		self._observers = count
	end)
end

function CECDetection:Clear()
	self._ratio = false
	self._observers = 0
end

function CECDetection:Create(hud)
	if not hud or not hud.panel then
		return
	end

	local existing = hud.panel:child("cec_detection_risk")
	if existing then
		hud.panel:remove(existing)
	end

	local ok, text = pcall(function()
		return hud.panel:text({
			name = "cec_detection_risk",
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
		log("[CEC Detection Risk Live] could not create the HUD text, mod inactive")
		return
	end

	pcall(function()
		text:set_right(hud.panel:w() + self.x)
	end)

	self._text = text
	self._line = nil
	self:Clear()
end

function CECDetection:Update()
	local text = self._text
	if not alive(text) then
		self._text = nil
		return
	end

	local line, color

	if self._ratio == true then
		line = "REPERE"
		color = Color(1, 0.3, 0.3)
	elseif type(self._ratio) == "number" and self._ratio > 0 then
		local pct = math.clamp(self._ratio * 100, 0, 100)

		if self._observers > 1 then
			line = string.format("DETECTION %d%% (x%d)", pct, self._observers)
		else
			line = string.format("DETECTION %d%%", pct)
		end

		-- Amber up to two thirds, red past it: past that point the meter fills
		-- faster than a player can usually break line of sight.
		color = pct >= 66 and Color(1, 0.3, 0.3) or Color(1, 0.9, 0.4)
	else
		line = ""
		color = Color(1, 0.9, 0.4)
	end

	if line ~= self._line then
		self._line = line

		pcall(function()
			text:set_text(line)
			text:set_color(color)
		end)
	end
end
