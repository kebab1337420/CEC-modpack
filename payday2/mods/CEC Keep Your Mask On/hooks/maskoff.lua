dofile(ModPath .. "core.lua")

if not rawget(_G, "PlayerMaskOff") then
	log("[CEC Keep Your Mask On] PlayerMaskOff not found, mod inactive")
	return
end

if rawget(PlayerMaskOff, "_start_action_state_standard") then
	Hooks:PostHook(PlayerMaskOff, "_start_action_state_standard", "CECMaskOn_Start", function(self)
		self._cec_mask_committed = true
	end)
end

if rawget(PlayerMaskOff, "_end_action_start_standard") then
	Hooks:PostHook(PlayerMaskOff, "_end_action_start_standard", "CECMaskOn_End", function(self)
		self._cec_mask_committed = nil
	end)
end

if rawget(PlayerMaskOff, "_interupt_action_start_standard") then
	local vanilla_interupt = PlayerMaskOff._interupt_action_start_standard

	-- A pre hook cannot stop the original from running, so this one has to be a
	-- replacement. complete = true is the call the game makes when the timer ran
	-- out, which is the only interruption worth honouring.
	function PlayerMaskOff:_interupt_action_start_standard(t, input, complete)
		if self._cec_mask_committed and not complete then
			return
		end

		self._cec_mask_committed = nil

		return vanilla_interupt(self, t, input, complete)
	end
end

if rawget(PlayerMaskOff, "_enter") then
	Hooks:PostHook(PlayerMaskOff, "_enter", "CECMaskOn_Enter", function(self)
		self._cec_mask_committed = nil

		CECMaskOn:Hint()
	end)
end
