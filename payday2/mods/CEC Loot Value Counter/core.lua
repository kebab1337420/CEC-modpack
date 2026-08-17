-- CEC Loot Value Counter
--
-- The vanilla HUD only shows how many bags are secured, and only while the
-- objective panel happens to mention them. What the crew actually argues about
-- mid-heist is money: is one more bag worth the extra assault wave?
--
-- So this draws a small always-on panel on the in-heist HUD with the bag count
-- (mandatory / bonus split) and the cash value of everything secured so far,
-- bags and loose loot together.
--
-- Values come straight from LootManager, which already applies the job's
-- difficulty multiplier and the small loot cap, so what is displayed is what
-- the payout screen will show.

if CECLootCounter then
	return
end

CECLootCounter = {}

-- Panel geometry, in pixels of the 1280x720 HUD space.
CECLootCounter.x = -24
CECLootCounter.y = 140
CECLootCounter.font_size = 20

-- Values are re-read at most this often. Loot events also force a refresh, so
-- the interval only exists to catch value changes nothing notified us about.
CECLootCounter.refresh_interval = 1

function CECLootCounter:_money(value)
	local ok, text = pcall(function()
		return managers.money:add_decimal_marks_to_string(tostring(math.floor(value)))
	end)
	if ok and text then
		return "$" .. text
	end
	return "$" .. tostring(math.floor(value))
end

-- Reads the loot managers. Returns nil when there is nothing to read, which
-- happens in the menu and during the first frames of a heist.
function CECLootCounter:_read()
	local ok, data = pcall(function()
		local loot = managers.loot
		if not loot then
			return nil
		end

		local mandatory = loot:get_secured_mandatory_bags_amount() or 0
		local bonus = loot:get_secured_bonus_bags_amount() or 0
		local bags = loot:get_secured_bags_amount() or (mandatory + bonus)
		local bag_value = loot:get_real_total_loot_value() or 0
		local small_value = loot:get_real_total_small_loot_value() or 0

		return {
			bags = bags,
			mandatory = mandatory,
			bonus = bonus,
			value = bag_value + small_value
		}
	end)

	return ok and data or nil
end

function CECLootCounter:_format(data)
	local bags = string.format("%d bag%s", data.bags, data.bags == 1 and "" or "s")

	-- The mandatory/bonus split is only interesting once a bonus bag exists:
	-- before that it is the same number twice.
	if data.bonus > 0 then
		bags = string.format("%s (%d + %d bonus)", bags, data.mandatory, data.bonus)
	end

	return bags .. "\n" .. self:_money(data.value)
end

-- Called from the HUD setup hook. The text lives on the player info panel, so
-- it is destroyed with the rest of the HUD when the heist ends and there is
-- nothing to clean up by hand.
function CECLootCounter:Create(hud)
	if not hud or not hud.panel then
		return
	end

	local existing = hud.panel:child("cec_loot_counter")
	if existing then
		hud.panel:remove(existing)
	end

	local ok, text = pcall(function()
		return hud.panel:text({
			name = "cec_loot_counter",
			text = "",
			font = tweak_data.hud.medium_font,
			font_size = self.font_size,
			color = Color(0.9, 0.9, 0.7),
			align = "right",
			vertical = "top",
			halign = "right",
			valign = "top",
			word_wrap = false,
			wrap = false,
			layer = 1,
			w = 320,
			h = self.font_size * 3,
			y = self.y
		})
	end)

	if not ok or not text then
		log("[CEC Loot Value Counter] could not create the HUD text, mod inactive")
		return
	end

	pcall(function()
		text:set_right(hud.panel:w() + self.x)
	end)

	self._text = text
	self._next_refresh = 0
	self:Refresh()
end

-- force = true skips the interval, used by the loot event hooks so a secured
-- bag shows up on the very next frame.
function CECLootCounter:Refresh(force)
	local text = self._text
	if not alive(text) then
		self._text = nil
		return
	end

	local data = self:_read()
	if not data then
		return
	end

	local line = self:_format(data)
	if line ~= self._line or force then
		self._line = line
		pcall(function()
			text:set_text(line)
		end)
	end
end

function CECLootCounter:Update(t)
	if not self._text then
		return
	end

	if type(t) ~= "number" then
		self:Refresh()
		return
	end

	if t < (self._next_refresh or 0) then
		return
	end

	self._next_refresh = t + self.refresh_interval
	self:Refresh()
end
