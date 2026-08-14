dofile(ModPath .. "core.lua")

Hooks:PostHook(PlayerDamage, "on_downed", "MaounoDownedSound_on_downed", function(self)
	MaounoDownedSound:play()
end)
