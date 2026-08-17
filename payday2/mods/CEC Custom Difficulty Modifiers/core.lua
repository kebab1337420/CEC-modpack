-- CEC Custom Difficulty Modifiers
--
-- The game has six difficulties and nothing in between. A crew that finds Death
-- Sentence unfair but Mayhem boring has no way to say "the same enemies, twenty
-- percent tougher" without replacing the difficulty tweak data wholesale.
--
-- This reads three multipliers out of a JSON file and applies them at the two
-- points where they cannot desync anything:
--
--   * enemy health is scaled on the host only, when the unit is created. Damage
--     is replicated as a percentage of maximum health, so clients follow along
--     without knowing the mod exists.
--   * damage taken by the player is scaled locally, in the same place vanilla
--     armour and health reduction already apply.
--
-- Nothing touches tweak_data itself, so the values stay correct for anything
-- else that reads them, and a client joining a vanilla host simply gets vanilla
-- enemy health with its own damage-taken setting.

if CECDifficulty then
	return
end

CECDifficulty = {}

CECDifficulty.path = (rawget(_G, "SavePath") or "") .. "cec_difficulty_modifiers.json"

CECDifficulty.defaults = {
	enemy_health_multiplier = 1,
	special_enemy_health_multiplier = 1,
	damage_taken_multiplier = 1
}

-- Units the special multiplier applies to, on top of the general one. These are
-- the _tweak_table names the game gives its own special enemies.
CECDifficulty.specials = {
	tank = true,
	spooc = true,
	taser = true,
	shield = true,
	medic = true,
	sniper = true,
	phalanx_minion = true,
	phalanx_vip = true
}

function CECDifficulty:_write_defaults()
	local file = io.open(self.path, "w")

	if not file then
		log("[CEC Custom Difficulty Modifiers] could not write " .. self.path)

		return
	end

	file:write(json.encode(self.defaults))
	file:close()

	log("[CEC Custom Difficulty Modifiers] wrote default config to " .. self.path)
end

-- A multiplier outside this range is almost certainly a typo, and a zero would
-- make enemies unkillable or unable to hurt anyone at all.
function CECDifficulty:_sane(value, fallback)
	if type(value) ~= "number" or value <= 0 or value > 20 then
		return fallback
	end

	return value
end

function CECDifficulty:Config()
	if self._config then
		return self._config
	end

	local file = io.open(self.path, "r")

	if not file then
		self:_write_defaults()

		self._config = self.defaults

		return self._config
	end

	local raw = file:read("*all")
	file:close()

	local ok, decoded = pcall(function()
		return json.decode(raw)
	end)

	if not ok or type(decoded) ~= "table" then
		log("[CEC Custom Difficulty Modifiers] " .. self.path .. " is not readable, using defaults")

		self._config = self.defaults

		return self._config
	end

	self._config = {
		enemy_health_multiplier = self:_sane(decoded.enemy_health_multiplier, 1),
		special_enemy_health_multiplier = self:_sane(decoded.special_enemy_health_multiplier, 1),
		damage_taken_multiplier = self:_sane(decoded.damage_taken_multiplier, 1)
	}

	log(string.format("[CEC Custom Difficulty Modifiers] health x%.2f, specials x%.2f, damage taken x%.2f", self._config.enemy_health_multiplier, self._config.special_enemy_health_multiplier, self._config.damage_taken_multiplier))

	return self._config
end

function CECDifficulty:HealthMultiplier(tweak_table)
	local config = self:Config()
	local mul = config.enemy_health_multiplier

	if tweak_table and self.specials[tweak_table] then
		mul = mul * config.special_enemy_health_multiplier
	end

	return mul
end

function CECDifficulty:DamageTakenMultiplier()
	return self:Config().damage_taken_multiplier
end

-- Applied to a freshly initialised CopDamage. The granularity value is derived
-- from the initial health, so it has to be recomputed rather than left behind.
function CECDifficulty:ScaleEnemy(damage_ext, tweak_table)
	local mul = self:HealthMultiplier(tweak_table)

	if mul == 1 then
		return
	end

	pcall(function()
		damage_ext._HEALTH_INIT = damage_ext._HEALTH_INIT * mul
		damage_ext._health = damage_ext._HEALTH_INIT

		if damage_ext._HEALTH_GRANULARITY then
			damage_ext._HEALTH_INIT_PRECENT = damage_ext._HEALTH_INIT / damage_ext._HEALTH_GRANULARITY
		end
	end)
end
