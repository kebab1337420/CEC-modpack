local BAI = BAI
if BAI:IsHost() then
    Hooks:PreHook(GroupAIStateBesiege, "set_wave_mode", "BAI_Pre_GroupAIStateBesiege_set_wave_mode", function(self, flag)
        if managers.hud:GetAssaultMode() ~= "phalanx" and flag == "besiege" and self._hunt_mode then
            managers.hud:SetNormalAssaultOverride()
        end
    end)
end

Hooks:PostHook(GroupAIStateBesiege, "set_phalanx_damage_reduction_buff", "BAI_GroupAIStateBesiege_set_phalanx_damage_reduction_buff", function(self, damage_reduction)
    managers.hud:SetCaptainBuff(damage_reduction or 0)
end)

if not EHI then
    Hooks:PostHook(GroupAIStateBesiege, "_begin_assault_task", "BAI_GroupAIStateBesiege__begin_assault_task", function(self, ...)
        local end_t = self._task_data.assault.phase_end_t
        if end_t > 0 then
            LuaNetworking:SendToPeersExcept(1, BAI.EHI_SyncMessage.AnticipationStart, json.encode({ t = end_t - self._t }))
        end
    end)
end