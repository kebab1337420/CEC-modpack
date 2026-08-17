dofile(ModPath .. "core.lua")

if not rawget(_G, "ReviveInteractionExt") then
	log("[CEC Revive Chain] ReviveInteractionExt not found, revive tracking inactive")
	return
end

if rawget(ReviveInteractionExt, "interact") then
	-- interact() bails out silently when the pickup is not allowed any more, and
	-- by the time it returns the downed state is already gone, so whether the
	-- pickup was real has to be read before vanilla runs. can_interact is a plain
	-- check with no side effects, so asking twice costs nothing.
	Hooks:PreHook(ReviveInteractionExt, "interact", "CECReviveChain_Pre", function(self, reviving_unit)
		self._cec_chain_counts = false

		pcall(function()
			if self.tweak_data ~= "revive" then
				return
			end

			if not reviving_unit or reviving_unit ~= managers.player:player_unit() then
				return
			end

			self._cec_chain_counts = self:can_interact(reviving_unit) and true or false
		end)
	end)

	Hooks:PostHook(ReviveInteractionExt, "interact", "CECReviveChain_Post", function(self, reviving_unit)
		if self._cec_chain_counts then
			self._cec_chain_counts = false

			CECReviveChain:OnRevivedTeammate()
		end
	end)
end
