dofile(ModPath .. "core.lua")

if rawget(_G, "CrimeSpreeModifiersMenuComponent") then
	if rawget(CrimeSpreeModifiersMenuComponent, "_setup") then
		Hooks:PostHook(CrimeSpreeModifiersMenuComponent, "_setup", "CECSpreePresets_Setup", function(self)
			CECSpreePresets:Apply(self)
		end)
	end

	-- Confirming a modifier refills the same buttons with the next batch and
	-- clears the selection, so the preset has to be applied again.
	if rawget(CrimeSpreeModifiersMenuComponent, "_on_finalize_modifier") then
		Hooks:PostHook(CrimeSpreeModifiersMenuComponent, "_on_finalize_modifier", "CECSpreePresets_Next", function(self)
			if self:modifiers_to_select() > 0 then
				CECSpreePresets:Apply(self)
			end
		end)
	end
else
	log("[CEC Crime Spree Presets] CrimeSpreeModifiersMenuComponent not found, mod inactive")
end
