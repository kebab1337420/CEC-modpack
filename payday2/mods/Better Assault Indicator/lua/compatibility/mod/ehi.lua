if BAI.EHISync then
    return
end
BAI.EHISync = {}

function BAI.EHISync:post_init()
    self._is_skirmish = managers.skirmish:is_skirmish()
    if not self._is_skirmish then
        local SustainListener = class(BaseModifier)
        ---@param duration number
        function SustainListener:OnEnterSustainPhase(duration)
            LuaNetworking:SendToPeersExcept(1, BAI.EHI_SyncMessage.SustainStart, json.encode({ t = duration }))
        end
        managers.modifiers:add_modifier(SustainListener, "BAI")
    end
end

---@param data table
function BAI.EHISync:save(data)
    if not self._is_skirmish then -- Simulate data send as from EHI
        local state = {}
        state.diff = managers.groupai:state()._difficulty_value or 0 -- Get the value directly from the manager
        data.EHIAssaultManager = state
    end
end