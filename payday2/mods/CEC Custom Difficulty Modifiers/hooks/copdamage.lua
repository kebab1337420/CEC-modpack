dofile(ModPath .. "core.lua")

if not rawget(_G, "CopDamage") then
	log("[CEC Custom Difficulty Modifiers] CopDamage not found, enemy health scaling inactive")
	return
end

if rawget(CopDamage, "init") then
	Hooks:PostHook(CopDamage, "init", "CECDifficulty_CopInit", function(self, unit)
		-- Host only: enemy health is authoritative on the server and replicated as
		-- a share of maximum, so a client scaling it locally would only make its
		-- own health bars lie.
		if not Network:is_server() then
			return
		end

		local tweak_table = nil

		pcall(function()
			tweak_table = unit:base()._tweak_table
		end)

		CECDifficulty:ScaleEnemy(self, tweak_table)
	end)
end
