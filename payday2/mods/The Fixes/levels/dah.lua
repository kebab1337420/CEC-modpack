TheFixesPreventer = TheFixesPreventer or {}
if not TheFixesPreventer.mute_contractor_fixes then
    for i = 103882, 103884, 1 do
        local element = managers.mission:get_element_by_id(i)
        if element then
            element._values.can_not_be_muted = true
        end
    end
end

if Network:is_client() then
    return
end

--105221 - bust
--105222 - glass case
--100495 - bust
--100499 - glass case
for _, id in ipairs({105221, 105222, 100495, 100499}) do
    local unit = managers.worlddefinition:get_unit(id)
    if unit then
        managers.game_play_central:mission_disable_unit(unit) -- Sync to other players
    end
end

local element = managers.mission:get_element_by_id(100855) -- ´func_sequence_trigger_040´ ElementUnitSequenceTrigger 100855 (for units 100495 and 100499)
if element then -- Disable the trigger in case it gets shot by accident, causes alarm
    element:set_enabled(false)
end

--[[--105221 - bust
--105222 - glass case
for _, id in ipairs({105221, 105222}) do
    local unit = managers.worlddefinition:get_unit(id)
    if unit then
        managers.game_play_central:mission_disable_unit(unit) -- Synces to other players
    end
end

--- Not interactable, no collision
--100495 - bust  
--100499 - glass case
local unit_fixed_position =
{
    [100495] = Vector3(-2500, -4950, -149.169),
    [100499] = Vector3(-2497, -4950, -275)
}
local unit_fixed_rotation =
{
    [100495] = Rotation(-180, 0, -0),
    [100499] = Rotation(-90, 0, -0)
}
for _, id in ipairs({100495, 100499}) do
    local unit = managers.worlddefinition:get_unit(id)
    if unit then
        unit:set_rotation(unit_fixed_rotation[id])
        unit:set_position(unit_fixed_position[id])
    end
end]]