-- Etat partage du mod : valeurs par defaut, chargement/sauvegarde des options,
-- localisation et enregistrement du menu. Charge une seule fois via entry_scripts.

if SlowMotionManager then
	return
end

SlowMotionManager = {}

local SMM = SlowMotionManager

SMM.mod_path = ModPath
SMM.save_path = SavePath .. "/SlowMotionManager_options.txt"

SMM.localization = {
	[1] = ModPath .. "loc/english.txt",
	[2] = ModPath .. "loc/french.txt"
}

-- Chaque section du menu : son interrupteur, et la correspondance entre les
-- champs de TimeSpeedEffectTweakData et les options qui les pilotent.
SMM.sections = {
	{
		id = "maskon",
		toggle = "SlowMotionManager_enable_maskon",
		fields = {
			speed = "SlowMotionManager_speed_maskon",
			fade_in_delay = "SlowMotionManager_fadeindelay_maskon",
			fade_in = "SlowMotionManager_fadein_maskon",
			sustain = "SlowMotionManager_sustain_maskon",
			fade_out = "SlowMotionManager_fadeout_maskon"
		}
	},
	{
		id = "downed",
		toggle = "SlowMotionManager_enable_downed",
		fields = {
			speed = "SlowMotionManager_speed_downed",
			fade_in = "SlowMotionManager_fadein_downed",
			sustain = "SlowMotionManager_sustain_downed",
			fade_out = "SlowMotionManager_fadeout_downed"
		}
	},
	{
		id = "scripted",
		toggle = "SlowMotionManager_enable_scripted",
		fields = {
			speed = "SlowMotionManager_speed_scripted",
			fade_in_delay = "SlowMotionManager_fadeindelay_scripted",
			fade_in = "SlowMotionManager_fadein_scripted",
			sustain = "SlowMotionManager_sustain_scripted",
			fade_out = "SlowMotionManager_fadeout_scripted"
		}
	}
}

-- Valeurs appliquees a une section desactivee : vitesse pleine, aucune
-- transition, aucune duree.
SMM.disabled_values = {
	speed = 1,
	fade_in_delay = 0,
	fade_in = 0,
	sustain = 0,
	fade_out = 0
}

-- Valeurs vanilla de TimeSpeedEffectTweakData (Diesel 3.0), plus la langue et
-- les interrupteurs.
SMM.defaults = {
	SlowMotionManager_language = 1,

	SlowMotionManager_enable_maskon = true,
	SlowMotionManager_speed_maskon = 0.2,
	SlowMotionManager_fadein_maskon = 0.25,
	SlowMotionManager_fadeindelay_maskon = 1.35,
	SlowMotionManager_sustain_maskon = 5,
	SlowMotionManager_fadeout_maskon = 0.8,

	SlowMotionManager_enable_downed = true,
	SlowMotionManager_speed_downed = 0.3,
	SlowMotionManager_fadein_downed = 0.25,
	SlowMotionManager_sustain_downed = 3,
	SlowMotionManager_fadeout_downed = 0.8,

	SlowMotionManager_enable_scripted = true,
	SlowMotionManager_speed_scripted = 0.2,
	SlowMotionManager_fadein_scripted = 0.3,
	SlowMotionManager_fadeindelay_scripted = 0.5,
	SlowMotionManager_sustain_scripted = 5,
	SlowMotionManager_fadeout_scripted = 0.8
}

-- Les items toggle rendent "on"/"off" et non un booleen, il faut savoir lesquels
-- convertir dans les callbacks.
SMM.booleans = {}

for _, section in ipairs(SMM.sections) do
	SMM.booleans[section.toggle] = true
end

SMM.options = {}

function SMM:Load()
	local loaded = io.file_is_readable(self.save_path) and io.load_as_json(self.save_path)

	self.options = type(loaded) == "table" and loaded or {}

	-- Sans ce remplissage, une option absente vaut nil et les tweaks retombaient
	-- sur 0, ce qui gele le temps au lieu d'appliquer le vanilla. Ca reprend
	-- aussi les fichiers ecrits avant l'ajout des interrupteurs.
	for key, value in pairs(self.defaults) do
		if self.options[key] == nil then
			self.options[key] = value
		end
	end
end

function SMM:Save()
	if file.DirectoryExists(SavePath) then
		io.save_as_json(self.options, self.save_path)
	end
end

function SMM:Set(key, value)
	self.options[key] = value
	self:Save()
end

function SMM:Get(key)
	local value = self.options[key]

	if value == nil then
		value = self.defaults[key]
	end

	return value
end

---Valeurs a ecrire dans l'effet pour une section, interrupteur pris en compte.
function SMM:SectionValues(section)
	local values = {}
	local enabled = self:Get(section.toggle)

	for field, key in pairs(section.fields) do
		values[field] = enabled and self:Get(key) or self.disabled_values[field]
	end

	return values
end

SMM:Load()

Hooks:Add("LocalizationManagerPostInit", "SlowMotionManager_localization", function(loc)
	-- L'anglais sert toujours de base pour qu'une cle absente d'une traduction
	-- reste lisible.
	loc:load_localization_file(SMM.localization[1])

	local language = SMM:Get("SlowMotionManager_language")

	if language ~= 1 and SMM.localization[language] then
		loc:load_localization_file(SMM.localization[language])
	end
end)

MenuHelper:LoadFromJsonFile(ModPath .. "options/menu.json", SMM, SMM.options)
