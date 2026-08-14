TheFixesPreventer = TheFixesPreventer or {}
if not TheFixesPreventer.end_screen_continue_button then
	local origfunc = MissionEndState.at_enter
	function MissionEndState:at_enter(...)
		origfunc(self, ...)
		if not managers.crime_spree:is_active() then
			self:set_completion_bonus_done(true)
		end
	end
end