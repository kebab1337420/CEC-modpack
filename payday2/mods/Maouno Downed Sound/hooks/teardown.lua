dofile(ModPath .. "core.lua")

-- Runs once the setup classes exist, which is not guaranteed when the player
-- damage hook pulls core.lua in.
MaounoDownedSound:install_teardown_hooks()
