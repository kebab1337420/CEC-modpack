dofile(ModPath .. "core.lua")

if rawget(_G, "CopBrain") then
	-- begin_alarm_pager schedules the first ring, clbk_alarm_pager schedules
	-- every following one. Reading the pager data after either gives the
	-- pending deadline.
	if rawget(CopBrain, "begin_alarm_pager") then
		Hooks:PostHook(CopBrain, "begin_alarm_pager", "CECPagerTimer_Begin", function(self)
			CECPagerTimer:Track(self)
		end)
	end

	if rawget(CopBrain, "clbk_alarm_pager") then
		Hooks:PostHook(CopBrain, "clbk_alarm_pager", "CECPagerTimer_Call", function(self)
			CECPagerTimer:Track(self)
		end)
	end

	-- Answered, hung up, or the corpse stopped mattering: no deadline left.
	if rawget(CopBrain, "end_alarm_pager") then
		Hooks:PostHook(CopBrain, "end_alarm_pager", "CECPagerTimer_End", function(self)
			CECPagerTimer:Untrack(self)
		end)
	end

	-- Picking up the pager suspends the callback, so the countdown has to stop
	-- while the player is talking.
	if rawget(CopBrain, "on_alarm_pager_interaction") then
		Hooks:PostHook(CopBrain, "on_alarm_pager_interaction", "CECPagerTimer_Interaction", function(self, status)
			if status == "started" then
				CECPagerTimer:Untrack(self)
			else
				CECPagerTimer:Track(self)
			end
		end)
	end
else
	log("[CEC Pager Timer] CopBrain not found, mod inactive")
end
