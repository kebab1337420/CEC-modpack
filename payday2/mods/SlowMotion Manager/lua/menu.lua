-- Callbacks du menu. Hooke sur menumanager, seul endroit ou MenuCallbackHandler
-- existe deja.

if not SlowMotionManager then
	dofile(ModPath .. "lua/core.lua")
end

local SMM = SlowMotionManager

for key, _ in pairs(SMM.defaults) do
	MenuCallbackHandler[key .. "_callback"] = function(self, item)
		SMM:Set(key, item:value())
	end
end

-- ResetItemsToDefaultValue ne touche que l'affichage du slider : sans ecriture
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

MenuCallbackHandler.SlowMotionManager_noslowmo_callback = function(self, item)
	apply_preset(item, SMM.no_slowmo)
end
