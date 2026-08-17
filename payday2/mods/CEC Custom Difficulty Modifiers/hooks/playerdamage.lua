dofile(ModPath .. "core.lua")

if not rawget(_G, "PlayerDamage") then
	log("[CEC Custom Difficulty Modifiers] PlayerDamage not found, damage taken scaling inactive")
	return
end

-- Every incoming damage path reads attack_data.damage before applying armour and
-- reduction, so scaling it here keeps skills, perks and mods working on top. The
-- marker guards against one path delegating to another and scaling twice.
local function scale(attack_data)
	if not attack_data or type(attack_data.damage) ~= "number" or attack_data._cec_scaled then
		return
	end

	local mul = CECDifficulty:DamageTakenMultiplier()

	if mul == 1 then
		return
	end

	attack_data._cec_scaled = true
	attack_data.damage = attack_data.damage * mul
end

for _, name in ipairs({
	"damage_bullet",
	"damage_melee",
	"damage_explosion"
}) do
	if rawget(PlayerDamage, name) then
		Hooks:PreHook(PlayerDamage, name, "CECDifficulty_" .. name, function(self, attack_data)
			scale(attack_data)
		end)
	end
end
