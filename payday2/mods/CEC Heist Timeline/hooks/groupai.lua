dofile(ModPath .. "core.lua")

if not rawget(_G, "GroupAIStateBase") then
	log("[CEC Heist Timeline] GroupAIStateBase not found, alarm and assault events inactive")
	return
end

if rawget(GroupAIStateBase, "on_police_called") then
	Hooks:PostHook(GroupAIStateBase, "on_police_called", "CECTimeline_Called", function(self, called_reason)
		CECTimeline:Add("Police appelee" .. (called_reason and (" (" .. tostring(called_reason) .. ")") or ""))
	end)
end

if rawget(GroupAIStateBase, "on_enemy_weapons_hot") then
	Hooks:PostHook(GroupAIStateBase, "on_enemy_weapons_hot", "CECTimeline_Hot", function(self)
		CECTimeline:Add("Alarme : discretion perdue")
	end)
end

if rawget(GroupAIStateBase, "set_assault_mode") then
	-- set_assault_mode is called on every wave flip but only does work when the
	-- flag actually changed, so the flag is read after vanilla ran.
	Hooks:PostHook(GroupAIStateBase, "set_assault_mode", "CECTimeline_Assault", function(self, enabled)
		if self._cec_assault_logged == enabled then
			return
		end

		self._cec_assault_logged = enabled

		if enabled then
			CECTimeline:Add("Assaut " .. tostring(self._assault_number or "?"))
		else
			CECTimeline:Add("Fin d'assaut : pause")
		end
	end)
end
