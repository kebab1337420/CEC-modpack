dofile(ModPath .. "core.lua")

if not rawget(_G, "PlayerMovement") then
	log("[CEC Detection Risk Live] PlayerMovement not found, mod inactive")
	return
end

if rawget(PlayerMovement, "_feed_suspicion_to_hud") then
	-- Every path that changes the meter ends here, host side and client side
	-- alike, so this is the one place worth reading.
	Hooks:PostHook(PlayerMovement, "_feed_suspicion_to_hud", "CECDetection_Feed", function(self)
		CECDetection:Feed(self)
	end)
end
