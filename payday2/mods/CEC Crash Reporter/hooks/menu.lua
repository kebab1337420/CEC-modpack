dofile(ModPath .. "core.lua")

Hooks:Add("MenuManagerPostInitialize", "CECCrashReporter_MenuReady", function()
	CECCrashReporter:OnMenuReady()
end)

-- Quitting through the menu is the only exit the game controls, so it is the
-- only place the "session still open" sentinel can be cleared.
if rawget(_G, "MenuCallbackHandler") and rawget(MenuCallbackHandler, "quit_game") then
	Hooks:PostHook(MenuCallbackHandler, "quit_game", "CECCrashReporter_CleanExit", function()
		CECCrashReporter:OnCleanExit()
	end)
end
