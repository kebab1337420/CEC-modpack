dofile(ModPath .. "core.lua")

-- Every path that can change the secured total. secure is the local one,
-- sync_secure_loot is a teammate's bag, secure_small_loot is loose loot.
local events = {
	"secure",
	"sync_secure_loot",
	"secure_small_loot"
}

if rawget(_G, "LootManager") then
	for _, name in ipairs(events) do
		if rawget(LootManager, name) then
			Hooks:PostHook(LootManager, name, "CECLootCounter_" .. name, function()
				CECLootCounter:Refresh(true)
			end)
		end
	end
else
	log("[CEC Loot Value Counter] LootManager not found, counter will only refresh on its timer")
end
