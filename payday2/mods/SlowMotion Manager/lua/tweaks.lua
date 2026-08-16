-- Application des options sur TimeSpeedEffectTweakData.
--
-- Les deux fonctions vanilla sont enveloppees au lieu d'etre remplacees : les
-- champs que le mod n'expose pas (timer, affect_timer, sync) restent ceux du
-- jeu, y compris si une mise a jour en ajoute.

if not SlowMotionManager then
	dofile(ModPath .. "lua/core.lua")
end

local SMM = SlowMotionManager

local function apply(effect, keys)
	if not effect then
		return
	end

	for field, key in pairs(keys) do
		effect[field] = SMM:Get(key)
	end
end

local _init_base_effects = TimeSpeedEffectTweakData._init_base_effects

function TimeSpeedEffectTweakData:_init_base_effects(...)
	_init_base_effects(self, ...)

	apply(self.mask_on, {
		speed = "SlowMotionManager_speed_maskon",
		fade_in_delay = "SlowMotionManager_fadeindelay_maskon",
		fade_in = "SlowMotionManager_fadein_maskon",
		sustain = "SlowMotionManager_sustain_maskon",
		fade_out = "SlowMotionManager_fadeout_maskon"
	})

	apply(self.downed, {
		speed = "SlowMotionManager_speed_downed",
		fade_in = "SlowMotionManager_fadein_downed",
		sustain = "SlowMotionManager_sustain_downed",
		fade_out = "SlowMotionManager_fadeout_downed"
	})

	-- Le vanilla fige la vitesse joueur a 0.5 et ne recopie que les durees ; le
	-- mod fait suivre le curseur pour que le reglage vaille aussi pour soi.
	if self.mask_on_player then
		self.mask_on_player.speed = self.mask_on.speed
		self.mask_on_player.fade_in_delay = self.mask_on.fade_in_delay
		self.mask_on_player.fade_in = self.mask_on.fade_in
		self.mask_on_player.sustain = self.mask_on.sustain
		self.mask_on_player.fade_out = self.mask_on.fade_out
	end

	if self.downed_player then
		self.downed_player.speed = self.downed.speed
		self.downed_player.fade_in = self.downed.fade_in
		self.downed_player.sustain = self.downed.sustain
		self.downed_player.fade_out = self.downed.fade_out
	end
end

local _init_mission_effects = TimeSpeedEffectTweakData._init_mission_effects

function TimeSpeedEffectTweakData:_init_mission_effects(...)
	_init_mission_effects(self, ...)

	local quickdraw = self.mission_effects and self.mission_effects.quickdraw

	apply(quickdraw, {
		speed = "SlowMotionManager_speed_scripted",
		fade_in_delay = "SlowMotionManager_fadeindelay_scripted",
		fade_in = "SlowMotionManager_fadein_scripted",
		sustain = "SlowMotionManager_sustain_scripted",
		fade_out = "SlowMotionManager_fadeout_scripted"
	})

	local quickdraw_player = self.mission_effects and self.mission_effects.quickdraw_player

	if quickdraw and quickdraw_player then
		quickdraw_player.speed = quickdraw.speed
		quickdraw_player.fade_in_delay = quickdraw.fade_in_delay
		quickdraw_player.fade_in = quickdraw.fade_in
		quickdraw_player.sustain = quickdraw.sustain
		quickdraw_player.fade_out = quickdraw.fade_out
	end
end
