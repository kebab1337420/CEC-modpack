-- Application des options sur TimeSpeedEffectTweakData.
--
-- Les deux fonctions vanilla sont enveloppees au lieu d'etre remplacees : les
-- champs que le mod n'expose pas (timer, affect_timer, sync) restent ceux du
-- jeu, y compris si une mise a jour en ajoute.

if not SlowMotionManager then
	dofile(ModPath .. "lua/core.lua")
end

local SMM = SlowMotionManager

local sections = {}

for _, section in ipairs(SMM.sections) do
	sections[section.id] = section
end

---Ecrit les valeurs d'une section dans l'effet et sa variante joueur.
--
-- Le vanilla fige la vitesse joueur a 0.5 et ne recopie que les durees ; le mod
-- fait suivre le curseur pour que le reglage vaille aussi pour soi.
local function apply(section, effect, player_effect)
	if not effect then
		return
	end

	local values = SMM:SectionValues(section)

	for field, value in pairs(values) do
		effect[field] = value

		if player_effect then
			player_effect[field] = value
		end
	end
end

local _init_base_effects = TimeSpeedEffectTweakData._init_base_effects

function TimeSpeedEffectTweakData:_init_base_effects(...)
	_init_base_effects(self, ...)

	apply(sections.maskon, self.mask_on, self.mask_on_player)
	apply(sections.downed, self.downed, self.downed_player)
end

local _init_mission_effects = TimeSpeedEffectTweakData._init_mission_effects

function TimeSpeedEffectTweakData:_init_mission_effects(...)
	_init_mission_effects(self, ...)

	local effects = self.mission_effects

	if effects then
		apply(sections.scripted, effects.quickdraw, effects.quickdraw_player)
	end
end
