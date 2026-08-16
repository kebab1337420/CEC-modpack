-- Callbacks du menu. Hooke sur menumanager, seul endroit ou MenuCallbackHandler
-- existe deja.

if not SlowMotionManager then
	dofile(ModPath .. "lua/core.lua")
end

local SMM = SlowMotionManager

for key, _ in pairs(SMM.defaults) do
	MenuCallbackHandler[key .. "_callback"] = function(self, item)
		local value = item:value()

		if SMM.booleans[key] then
			value = value == "on" or value == true
		end

		SMM:Set(key, value)
	end
end

-- ResetItemsToDefaultValue ne touche que l'affichage de l'item : sans ecriture
-- explicite dans les options, les deux boutons ci-dessous ne persistaient rien.
local function apply_preset(item, preset)
	for key, value in pairs(preset) do
		MenuHelper:ResetItemsToDefaultValue(item, { [key] = true }, value)
		SMM.options[key] = value
	end

	SMM:Save()
end

MenuCallbackHandler.SlowMotionManager_reset_callback = function(self, item)
	local preset = {}

	for key, value in pairs(SMM.defaults) do
		if key ~= "SlowMotionManager_language" then
			preset[key] = value
		end
	end

	apply_preset(item, preset)
end

-- Coupe les trois interrupteurs plutot que d'ecraser les curseurs : les reglages
-- sont conserves et reviennent tels quels si on rallume une section.
MenuCallbackHandler.SlowMotionManager_noslowmo_callback = function(self, item)
	local preset = {}

	for _, section in ipairs(SMM.sections) do
		preset[section.toggle] = false
	end

	apply_preset(item, preset)
end
