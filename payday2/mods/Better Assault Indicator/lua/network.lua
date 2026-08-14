local BAI = BAI
local data_send = BAI.data
Hooks:Add("NetworkReceivedData", "NetworkReceivedData_BAI", function(sender, id, data)
    if not managers.hud then
        return
    end
    if id == BAI.SyncMessage then
        if data == data_send.BAI_Q then -- Host replies
            LuaNetworking:SendToPeer(sender, id, data_send.BAI_A)
        end
        if data == data_send.BAI_A then -- Client receives
            managers.hud:SetCompatibleHost(true)
            LuaNetworking:SendToPeer(1, BAI.EE_SyncMessage, data_send.EE_FSS1_Q)
            --LuaNetworking:SendToPeer(1, id, data_send.ResendAS)
        end
        if data == data_send.ResendAS then -- Host replies
            LuaNetworking:SendToPeer(sender, BAI.ASO_SyncMessage, managers.groupai:state():GetAssaultState())
        end
        if data == data_send.ResendTime then -- Host replies
            BAI:GetAssaultTime(sender)
        end
    end
    if id == BAI.AS_SyncMessage then -- Client receives
        if BAI:GetOption("show_assault_states") then
            BAI:UpdateAssaultState(data)
        end
    end
    if id == BAI.ASO_SyncMessage then -- Client receives
        if BAI:GetOption("show_assault_states") then
            BAI:UpdateAssaultStateOverride(data, true)
        end
    end
    if id == BAI.AAI_SyncMessage then -- Client receives
        BAI:SetTimeLeft(data)
    end
    if id == BAI.EE_SyncMessage then
        if data == data_send.EE_FSS1_Q then -- Host replies
            if BAI.EasterEgg.FSS.AIReactionTimeTooHigh then
                LuaNetworking:SendToPeer(sender, id, data_send.EE_FSS1_A)
            end
        end
        if data == data_send.EE_FSS1_A then -- Client receives
            BAI.EasterEgg.FSS.AIReactionTimeTooHigh = true
        end
    end
    if id == BAI.EE_ResetSyncMessage then
        BAI.EasterEgg.FSS.AIReactionTimeTooHigh = false
        LuaNetworking:SendToPeer(1, BAI.EE_SyncMessage, data_send.EE_FSS1_Q)
    end
    if id == BAI.EHI_SyncMessage.SustainStart and data and BAI:IsClient() and not BAI.BAIHost then
        local tbl = json.decode(data)
        if tbl and tbl.t then
            local t = tbl.t
            BAI:RemoveASCalls()
            BAI:UpdateAssaultState("sustain")
            BAI:SetTimeLeft(t)
            DelayedCalls:Add("BAI_AssaultStateChange_Fade", t, function()
                BAI:UpdateAssaultState("fade")
            end)
        end
    end
    if id == BAI.EHI_SyncMessage.AnticipationStart and data and BAI:IsClient() then
        local tbl = json.decode(data)
        if tbl and tbl.t then
            BAI._cache.client_break_time_left = TimerManager:game():time() + tbl.t
        end
    end

    -- KineticHUD
    if id == BAI.HUD.KineticHUD.DownCounter and BAI:IsClient() then
        managers.hud:SetCompatibleHost()
    end
    if id == BAI.HUD.KineticHUD.SyncAssaultPhase then
        if BAI:GetOption("show_assault_states") then
            data = utf8.to_lower(data)
            if data == "control" and BAI:GetOption("show_wave_survived") then
                return
            end
            if BAI:IsOr(data, "anticipation", "build", "regroup") then
                return
            end
            BAI:UpdateAssaultState(data)
        end
    end
    -- KineticHUD
end)

Hooks:Add("NetworkReceivedData", "NetworkReceivedData_BAI_AssaultStates_Net", function(sender, id, data)
    if id == "AssaultStates_Net" then
        if BAI:GetOption("show_assault_states") then
            if data == "control" and not managers.hud._hud_assault_corner._assault then
                BAI:UpdateAssaultState("control")
                return
            end
            if data == "control" and BAI:GetOption("show_wave_survived") then
                return
            end
            if BAI:IsOr(data, "anticipation", "build") then
                return
            end
            BAI:UpdateAssaultState(data)
        end
    end
end)