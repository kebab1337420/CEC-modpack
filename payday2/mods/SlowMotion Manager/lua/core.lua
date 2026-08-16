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

-- Valeurs vanilla de TimeSpeedEffectTweakData (Diesel 3.0), plus la langue.
SMM.defaults = {
	SlowMotionManager_language = 1,

	SlowMotionManager_speed_maskon = 0.2,
	SlowMotionManager_fadein_maskon = 0.25,
	SlowMotionManager_fadeindelay_maskon = 1.35,
	SlowMotionManager_sustain_maskon = 5,
	SlowMotionManager_fadeout_maskon = 0.8,

	SlowMotionManager_speed_downed = 0.3,
	SlowMotionManager_fadein_downed = 0.25,
	SlowMotionManager_sustain_downed = 3,
	SlowMotionManager_fadeout_downed = 0.8,

	SlowMotionManager_speed_scripted = 0.2,
	SlowMotionManager_fadein_scripted = 0.3,
	SlowMotionManager_fadeindelay_scripted = 0.5,
	SlowMotionManager_sustain_scripted = 5,
	SlowMotionManager_fadeout_scripted = 0.8
}

-- Valeurs appliquees par le bouton "No Slow Motion" : vitesse pleine, aucune
-- transition et aucune duree.
SMM.no_slowmo = {
	SlowMotionManager_speed_maskon = 1,
	SlowMotionManager_fadein_maskon = 0,
	SlowMotionManager_fadeindelay_maskon = 0,
	SlowMotionManager_sustain_maskon = 0,
	SlowMotionManager_fadeout_maskon = 0,

	SlowMotionManager_speed_downed = 1,
	SlowMotionManager_fadein_downed = 0,
	SlowMotionManager_sustain_downed = 0,
	SlowMotionManager_fadeout_downed = 0,

	SlowMotionManager_speed_scripted = 1,
	SlowMotionManager_fadein_scripted = 0,
	SlowMotionManager_fadeindelay_scripted = 0,
	SlowMotionManager_sustain_scripted = 0,
	SlowMotionManager_fadeout_scripted = 0
}

SMM.options = {}

function SMM:Load()
	local loaded = io.file_is_readable(self.save_path) and io.load_as_json(self.save_path)

	self.options = type(loaded) == "table" and loaded or {}

	-- Sans ce remplissage, une option absente du fichier vaut nil et les tweaks
	-- retombaient sur 0, ce qui gele le temps au lieu d'appliquer le vanilla.
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
