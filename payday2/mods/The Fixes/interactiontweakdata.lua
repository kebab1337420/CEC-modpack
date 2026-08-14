local original = InteractionTweakData.init
function InteractionTweakData:init(...)
    original(self, ...)
    -- Fixes continuous interact sound when interrupted
    self.hold_generator_start.sound_interupt = "bar_water_pump_cancel"
    self.hold_remove_rope.sound_interupt = "bar_remove_rope_cancel"
end