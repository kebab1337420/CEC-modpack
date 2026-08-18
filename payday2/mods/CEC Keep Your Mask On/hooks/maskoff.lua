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

-- The interruption to suppress is exactly the one _check_use_item fires when the
-- button comes back up, so the suppression is scoped to that call and to nothing
-- else. Every other caller - the state exiting because of an alarm, a taser, an
-- arrest or a vehicle - still cleans up, which matters: the interruption is what
-- hides the progress bar and tells the other peers the mask-on action stopped.
if rawget(PlayerMaskOff, "_check_use_item") then
	local vanilla_check_use_item = PlayerMaskOff._check_use_item

	function PlayerMaskOff:_check_use_item(t, input)
		self._cec_in_use_item = true

		local result = vanilla_check_use_item(self, t, input)

		self._cec_in_use_item = nil

		return result
	end
end

if rawget(PlayerMaskOff, "_interupt_action_start_standard") then
	local vanilla_interupt = PlayerMaskOff._interupt_action_start_standard

	-- A pre hook cannot stop the original from running, so this one has to be a
	-- replacement. complete = true is the call the game makes when the timer ran
	-- out, and it always goes through.
	function PlayerMaskOff:_interupt_action_start_standard(t, input, complete)
		if self._cec_mask_committed and self._cec_in_use_item and not complete then
			return
		end

		self._cec_mask_committed = nil

		return vanilla_interupt(self, t, input, complete)
	end
end

if rawget(PlayerMaskOff, "_enter") then
	Hooks:PostHook(PlayerMaskOff, "_enter", "CECMaskOn_Enter", function(self)
		self._cec_mask_committed = nil
		self._cec_in_use_item = nil

		CECMaskOn:Hint()
	end)
end
