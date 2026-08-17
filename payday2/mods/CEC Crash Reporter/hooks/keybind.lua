-- Manual report, for the case where the game misbehaves without crashing.
dofile(ModPath .. "core.lua")

local path = CECCrashReporter:WriteReport("manual request")
if path then
	CECCrashReporter:Notify(path, "Report generated on request.")
end
