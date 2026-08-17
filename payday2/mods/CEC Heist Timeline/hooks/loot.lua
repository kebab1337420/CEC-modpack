dofile(ModPath .. "core.lua")

if not rawget(_G, "LootManager") then
	log("[CEC Heist Timeline] LootManager not found, loot events inactive")
	return
end

if rawget(LootManager, "sync_secure_loot") then
	-- Both the host path and the client path end in sync_secure_loot, so this is
	-- the only hook needed. Small loot (money bundles, jewellery piles) is left
	-- out: it lands several times a second and would bury everything else.
	Hooks:PostHook(LootManager, "sync_secure_loot", "CECTimeline_Loot", function(self, carry_id, multiplier_level, silent, peer_id)
		pcall(function()
			if tweak_data.carry.small_loot[carry_id] then
				return
			end

			CECTimeline:Add("Sac securise : " .. tostring(carry_id) .. " (total " .. tostring(#self._global.secured) .. ")")
		end)
	end)
end
