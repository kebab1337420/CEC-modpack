dofile(ModPath .. "core.lua")

Hooks:Add("MenuManagerPostInitialize", "CECModpackUpdater_Check", function()
	CECModpackUpdater:Check()
end)
