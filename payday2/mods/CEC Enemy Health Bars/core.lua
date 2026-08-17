-- CEC Enemy Health Bars
--
-- PAYDAY 2 never tells you how much of an enemy is left. On lower difficulties
-- that does not matter, but against a Bulldozer or a damage-reduced Captain the
-- difference between "two more shots" and "reload now" is the run.
--
-- Aiming at an enemy shows a small bar under the crosshair: name, health, and,
-- when the target actually has one, its damage reduction as a second bar. The
-- panel lingers for a moment after the target leaves the crosshair so a bar
-- does not flicker away between recoil frames.
--
-- Health is read from CopDamage, which is authoritative on the host and synced
-- on clients, so the numbers match what the bullets are doing.

if CECEnemyBars then
	return
end

CECEnemyBars = {}

CECEnemyBars.width = 240
CECEnemyBars.bar_height = 8
CECEnemyBars.y_offset = 70
CECEnemyBars.font_size = 18

-- Raycast length in centimetres, the engine's world unit.
CECEnemyBars.range = 20000

-- The raycast is the expensive part, so it runs on its own interval rather than
-- every frame. The bars themselves still redraw from the cached target.
CECEnemyBars.scan_interval = 0.1

-- How long the panel stays up after the crosshair leaves the target.
CECEnemyBars.linger = 1.5

function CECEnemyBars:_mask()
	if not self._enemy_mask then
		local ok, mask = pcall(function()
			return managers.slot:get_mask("enemies")
		end)
		self._enemy_mask = ok and mask or nil
	end
	return self._enemy_mask
end

function CECEnemyBars:_pretty_name(unit)
	local ok, name = pcall(function()
		return unit:base()._tweak_table
	end)
	if not ok or type(name) ~= "string" then
		return "ENEMY"
	end
	return string.upper(string.gsub(name, "_", " "))
end

-- Damage reduction comes from two places: the unit's team (Captain's escort,
-- converted crew) and the per-unit multiplier set when a cop is converted.
function CECEnemyBars:_damage_reduction(damage_ext, unit)
	local total = 0

	pcall(function()
		total = unit:movement():team().damage_reduction or 0
	end)

	pcall(function()
		local mul = damage_ext._damage_reduction_multiplier
		if mul and mul > 0 and mul < 1 then
			-- Stored as a surviving-damage multiplier, shown as reduction.
			total = math.max(total, 1 - mul)
		end
	end)

	return math.clamp(total, 0, 1)
end

-- Returns the enemy unit under the crosshair, or nil.
function CECEnemyBars:_scan()
	local ok, unit = pcall(function()
		local mask = self:_mask()
		if not mask then
			return nil
		end

		local player = managers.player:player_unit()
		if not alive(player) then
			return nil
		end

		local camera = player:camera()
		if not camera then
			return nil
		end

		local from = camera:position()
		local ray = World:raycast("ray", from, from + camera:forward() * self.range, "slot_mask", mask)
		if not ray or not alive(ray.unit) then
			return nil
		end

		local damage_ext = ray.unit:character_damage()
		if not damage_ext or not damage_ext.health_ratio or damage_ext:dead() then
			return nil
		end

		return ray.unit
	end)

	return ok and unit or nil
end

-- Read every frame from the remembered unit, so the bar drains as it is shot
-- instead of stepping once per scan.
function CECEnemyBars:_read(unit)
	local ok, target = pcall(function()
		if not alive(unit) then
			return nil
		end

		local damage_ext = unit:character_damage()
		if not damage_ext or damage_ext:dead() then
			return nil
		end

		local health = damage_ext:health() or 0
		local max = damage_ext._HEALTH_INIT or health

		return {
			name = self:_pretty_name(unit),
			ratio = math.clamp(damage_ext:health_ratio() or 0, 0, 1),
			health = health,
			max = max,
			reduction = self:_damage_reduction(damage_ext, unit)
		}
	end)

	return ok and target or nil
end

function CECEnemyBars:Create(hud)
	if not hud or not hud.panel then
		return
	end

	local existing = hud.panel:child("cec_enemy_bars")
	if existing then
		hud.panel:remove(existing)
	end

	local ok = pcall(function()
		local panel = hud.panel:panel({
			name = "cec_enemy_bars",
			w = self.width,
			h = self.font_size + self.bar_height * 2 + 8,
			layer = 1,
			visible = false
		})

		panel:text({
			name = "name",
			text = "",
			font = tweak_data.hud.medium_font,
			font_size = self.font_size,
			color = Color(1, 1, 1),
			align = "center",
			vertical = "top",
			word_wrap = false,
			wrap = false,
			h = self.font_size
		})

		local function bar(name, y, color)
			panel:rect({
				name = name .. "_bg",
				color = Color(0, 0, 0),
				alpha = 0.5,
				x = 0,
				y = y,
				w = self.width,
				h = self.bar_height
			})
			panel:rect({
				name = name,
				color = color,
				x = 0,
				y = y,
				w = self.width,
				h = self.bar_height
			})
		end

		bar("health", self.font_size + 2, Color(0.9, 0.25, 0.25))
		bar("armor", self.font_size + 2 + self.bar_height + 2, Color(0.4, 0.7, 1))

		panel:set_center_x(hud.panel:w() * 0.5)
		panel:set_y(hud.panel:h() * 0.5 + self.y_offset)

		self._panel = panel
	end)

	if not ok then
		log("[CEC Enemy Health Bars] could not create the HUD panel, mod inactive")
		self._panel = nil
		return
	end

	self._unit = nil
	self._seen_t = nil
	self._next_scan = 0
end

function CECEnemyBars:_apply(target)
	local panel = self._panel

	pcall(function()
		panel:child("name"):set_text(string.format("%s  %d%%  (%d/%d)", target.name,
			math.round(target.ratio * 100), math.round(target.health), math.round(target.max)))
		panel:child("health"):set_w(self.width * target.ratio)

		local has_armor = target.reduction > 0
		panel:child("armor"):set_visible(has_armor)
		panel:child("armor_bg"):set_visible(has_armor)
		panel:child("armor"):set_w(self.width * target.reduction)
	end)
end

function CECEnemyBars:Update(t)
	local panel = self._panel
	if not alive(panel) then
		self._panel = nil
		return
	end

	if type(t) ~= "number" then
		return
	end

	if t >= (self._next_scan or 0) then
		self._next_scan = t + self.scan_interval

		local unit = self:_scan()
		if unit then
			self._unit = unit
			self._seen_t = t
		end
	end

	local target = self._unit and self:_read(self._unit) or nil

	-- Nothing aimed at recently, or the target died: hide and stop touching
	-- the panel.
	if not target or not self._seen_t or t - self._seen_t > self.linger then
		if panel:visible() then
			pcall(function()
				panel:set_visible(false)
			end)
		end
		self._unit = nil
		return
	end

	if not panel:visible() then
		pcall(function()
			panel:set_visible(true)
		end)
	end

	self:_apply(target)
end
