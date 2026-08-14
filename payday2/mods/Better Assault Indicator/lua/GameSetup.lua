local BAI = BAI
if BAI:CheckLoadHook("GameSetup") then
    return
end

Hooks:PostHook(GameSetup, "load", "BAI_GameSetup_load", function(self, data, ...) ---@param data table
    if data.EHIAssaultManager then
        managers.hud:SetCompatibleHost()
    end
    LuaNetworking:SendToPeer(1, BAI.SyncMessage, BAI.data.BAI_Q)
    BAI:LoadSync()
end)

if BAI:IsHost() and not EHI then
    dofile(BAI.ModCompatibilityPath .. "ehi.lua")
    Hooks:PostHook(GameSetup, "init_finalize", "BAI_GameSetup_init_finalize", function(...)
        BAI.EHISync:post_init()
        Hooks:RemovePostHook("BAI_GameSetup_init_finalize")
    end)
    Hooks:PostHook(GameSetup, "save", "BAI_GameSetup_save", function(self, data, ...) ---@param data table
        BAI.EHISync:save(data)
    end)
end