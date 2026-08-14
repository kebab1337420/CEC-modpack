local BAI = BAI
if BAI:CheckLoadHook("ElementAiGlobalEvent") then
    return
end

local _f_client_on_executed = ElementAiGlobalEvent.client_on_executed
function ElementAiGlobalEvent:client_on_executed(...)
    _f_client_on_executed(self, ...)
    local wave_mode = self._wave_modes[self._values.wave_mode]
    if wave_mode then
        if wave_mode == "hunt" then
            managers.hud:StartEndlessAssault()
        elseif wave_mode == "besiege" then
            managers.hud:SetNormalAssaultOverride()
        end
    end
end

if not EHI then
    local mode = "besiege"
    local original_on_executed = ElementAiGlobalEvent.on_executed
    function ElementAiGlobalEvent:on_executed(...)
        if not self._values.enabled then
            return
        end
        local wave_mode = self._wave_modes[self._values.wave_mode]
        if wave_mode and wave_mode ~= mode and (wave_mode == "besiege" or wave_mode == "hunt") then
            mode = wave_mode
            if wave_mode == "besiege" and not managers.skirmish:is_skirmish() then
                local ai_state = managers.groupai:state()
                local assault_data = ai_state._task_data.assault or {}
                local current_state = assault_data.phase
                local assault_values = tweak_data.group_ai.besiege.assault
                if current_state then
                    local data = {
                        state = current_state
                    }
                    if current_state == "build" then
                        data.t_correction = assault_values.build_duration - (assault_data.phase_end_t - ai_state._t)
                    elseif current_state == "sustain" then
                        local t = ai_state._t
                        data.sustain_original_t = assault_data.phase_end_t - t
                        data.sustain_t = ai_state:assault_phase_end_time() - t
                    end
                    LuaNetworking:SendToPeersExcept(1, BAI.EHI_SyncMessage.EndlessStop, json.encode(data))
                end
            end
        end
        original_on_executed(self, ...)
    end
end