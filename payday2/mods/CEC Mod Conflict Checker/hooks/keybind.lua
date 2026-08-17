-- Rescan on demand, typically after enabling or disabling something.
dofile(ModPath .. "core.lua")

CECConflictChecker._done = false
CECConflictChecker:Run()
