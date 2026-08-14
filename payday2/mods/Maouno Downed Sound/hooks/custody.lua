dofile(ModPath .. "core.lua")

-- Custody, whether it comes from running out of lives or from being cuffed:
-- the game switches to the "waiting for respawn" game state either way.
if IngameWaitingForRespawnState then
	Hooks:PostHook(IngameWaitingForRespawnState, "at_enter", "MaounoDownedSound_custody", function(self)
		MaounoDownedSound:play()
	end)
else
	log("[MaounoDownedSound] IngameWaitingForRespawnState not found, custody sound disabled")
end
