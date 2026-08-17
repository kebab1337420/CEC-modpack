dofile(ModPath .. "core.lua")

-- A fresh heist starts with a clean chain and no downs. PlayerDamage itself is
-- recreated on every respawn, so the counters cannot live there.
Hooks:Add("BaseNetworkSessionOnLoadComplete", "CECReviveChain_Reset", function()
	CECReviveChain:Reset()
end)

if not rawget(_G, "PlayerDamage") then
	log("[CEC Revive Chain] PlayerDamage not found, mod inactive")
	return
end

if rawget(PlayerDamage, "on_downed") then
	Hooks:PostHook(PlayerDamage, "on_downed", "CECReviveChain_Downed", function(self)
		CECReviveChain:OnDowned()
	end)
end

if rawget(PlayerDamage, "revive") then
	-- revive() reads _revive_health_multiplier, applies it and clears it again, so
	-- the penalty has to be folded in right before. Multiplying keeps whatever a
	-- skill or another mod already put there.
	Hooks:PreHook(PlayerDamage, "revive", "CECReviveChain_Revive", function(self, silent)
		local mul = CECReviveChain:ReviveMultiplier()

		if mul < 1 then
			self._revive_health_multiplier = (self._revive_health_multiplier or 1) * mul
		end
	end)
end
