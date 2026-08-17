dofile(ModPath .. "core.lua")

-- Wait for the menu: the scan wants BLT.Notifications and the full mod list,
-- and it walks mod_overrides, which is not something to do mid-load.
Hooks:Add("MenuManagerPostInitialize", "CECConflictChecker_Run", function()
	CECConflictChecker:Run()
end)
