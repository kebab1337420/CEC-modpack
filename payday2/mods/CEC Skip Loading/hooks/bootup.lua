dofile(ModPath .. "core.lua")

if rawget(_G, "BootupState") and rawget(BootupState, "setup") then
	Hooks:PostHook(BootupState, "setup", "CECSkipLoading_Bootup", function(self)
		CECSkipLoading:AllowSkipping()
		CECSkipLoading:TrimBootupList(self)
	end)
else
	log("[CEC Skip Loading] BootupState.setup not found, bootup playlist left untouched")
end
