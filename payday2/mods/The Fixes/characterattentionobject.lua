TheFixesPreventer = TheFixesPreventer or {}
if TheFixesPreventer.fix_ai_set_attention or FullSpeedSwarm then
    return
end

-- Fix issue where going from no attention data to new attention data not being counted as changed attention
-- Fix provided by Hoppip
local set_settings_set_original = CharacterAttentionObject.set_settings_set
function CharacterAttentionObject:set_settings_set(...)
    local no_attention = not self._attention_data
    set_settings_set_original(self, ...)
    if no_attention and self._attention_data then
        self:_call_listeners()
        self:_chk_update_registered_state()
    end
end