local BAI = BAI
--[[
    "BAI:CheckLoadHook()" ensures this block of code will not run when "lib/managers/hudmanagerpd2" is required from the Main Menu
    Some mods (particulary More Weapon Stats) are able to do that
]]
if BAI:CheckLoadHook("HUDManagerPD2") then
    return
end
local original =
{
    sync_set_assault_mode = HUDManager.sync_set_assault_mode,
    show_point_of_no_return_timer = HUDManager.show_point_of_no_return_timer,
    hide_point_of_no_return_timer = HUDManager.hide_point_of_no_return_timer,
    sync_start_assault = HUDManager.sync_start_assault
}
dofile(BAI.LuaPath .. "compatibility.lua")
function HUDManager:InitVariables()
    self._assault_mode = "assault"
    if BAI:IsClient() then
        local function SetTime5(active)
            if not active then
                BAI:SetTimeLeft(5)
            end
        end
        BAI:AddEvent(BAI.EventList.Captain, SetTime5)
        if BAI._cache.level_id == "hox_1" then
            BAI:AddEvent(BAI.EventList.NormalAssaultOverride, SetTime5, nil, 1)
            BAI:AddEvent(BAI.EventList.NormalAssaultOverride, function()
                BAI:SetSpawnsLeft(BAI:CalculateSpawnsFromDiff())
            end, nil, 2)
        end
        BAI:AddEvent(BAI.EventList.AssaultStart, function()
            managers.enemy.force_spawned = 0
        end)
    end
    BAI:AddEvent(BAI.EventList.EndlessAssaultStart, function()
        BAI._cache.AssaultType = BAI.Enum.AssaultType.Endless
    end, nil, 100)
    BAI:AddEvent(BAI.EventList.AssaultEnd, function()
        BAI._cache.AssaultType = BAI.Enum.AssaultType.None
    end)
    BAI:AddEvents({BAI.EventList.AssaultStart, BAI.EventList.NormalAssaultOverride}, function()
        BAI._cache.AssaultType = BAI.Enum.AssaultType.Normal
    end, nil, 200)
end

function HUDManager:GetAssaultMode()
    return self._assault_mode
end

function HUDManager:StartEndlessAssault()
    if BAI._cache.AssaultType == BAI.Enum.AssaultType.NoReturn then
        return
    end
    self:SetEndlessClient()
    self._hud_assault_corner:StartEndlessAssault()
end

function HUDManager:SetEndlessClient()
    self._hud_assault_corner:SetEndlessClient()
end

function HUDManager:SetCompatibleHost(BAIHost)
    BAI:SetCompatibleHost(BAIHost)
    self._hud_assault_corner:SetCompatibleHost(BAIHost)
end

function HUDManager:SetNormalAssaultOverride()
    if BAI._cache.AssaultType ~= BAI.Enum.AssaultType.Endless then
        return
    end
    BAI._cache.AssaultType = BAI.Enum.AssaultType.Normal
    BAI:CallEvent(BAI.EventList.NormalAssaultOverride)
end

function HUDManager:UpdateColors()
    self._hud_assault_corner:UpdateColors()
end

function HUDManager:sync_set_assault_mode(mode, ...)
    if self._assault_mode ~= mode then
        self._assault_vip = mode == "phalanx"
        self._assault_mode = mode
        BAI._cache.AssaultType = BAI.Enum.AssaultType[self._assault_vip and "Captain" or "Normal"]
        BAI:CallEvent(BAI.EventList.Captain, self._assault_vip)
        original.sync_set_assault_mode(self, mode, ...)
    end
end

function HUDManager:show_point_of_no_return_timer(tweak_id, ...)
    BAI:CallEvent(BAI.EventList.NoReturn, true, tweak_id)
    BAI._cache.AssaultType = BAI.Enum.AssaultType.NoReturn
    original.show_point_of_no_return_timer(self, tweak_id, ...)
end

function HUDManager:hide_point_of_no_return_timer(...)
    BAI:CallEvent(BAI.EventList.NoReturn, false)
    BAI._cache.AssaultType = BAI.Enum.AssaultType.None
    original.hide_point_of_no_return_timer(self, ...)
end

function HUDManager:GetTimeLeft()
    return BAI._cache.client_time_left - TimerManager:game():time()
end

function HUDManager:GetSpawnsLeft()
    return math.floor(BAI._cache.client_spawns_left - managers.enemy.force_spawned)
end

function HUDManager:GetBreakTimeLeft()
    return BAI._cache.client_break_time_left - TimerManager:game():time()
end

function HUDManager:SetCaptainBuff(buff)
    self._hud_assault_corner:SetCaptainBuff(math.max(0, buff))
end

BAI:Init()
local function ApplyCompatibility(self, class)
    BAI:PostInit()
    class = class or "HUDAssaultCorner"
    BAI:ApplyHUDCompatibility(BAI.settings.hud_compatibility)
    if self._hud_assault_corner and self._hud_assault_corner.InitBAI then
        self:InitVariables()
        self._hud_assault_corner:InitBAI()
        BAI:Log("Successfully initialized") --If the mod doesn't crash above, then this is the good sign that something works here
    else
        BAI:Log("Can't execute code in " .. class .. "! Are you sure it wasn't deleted?", BAI.Enum.LogType.Warning)
    end
end

if ArmStatic and MUIMenu and MUIMenu:ClassEnabled("MUIStats") and MUIStats then
    Hooks:Add("HUDManagerSetupPlayerInfoHudPD2", "BAI_MUI_setup", function(self)
        ApplyCompatibility(self, "MUIStats")
    end)
else
    Hooks:PostHook(HUDManager, "_create_assault_corner", "BAI_HUDManager__create_assault_corner", function(self)
        ApplyCompatibility(self)
    end)
end

function HUDManager:sync_start_assault(...)
    BAI:SetTimer()
    original.sync_start_assault(self, ...)
end

function HUDManager:DebugState(state, override, stealth_broken, no_as_mod)
    managers.chat:_receive_message(1, "[BAI]", "state: " .. tostring(state) .. "; override: " .. tostring(override) .. "; stealth_broken: " .. tostring(stealth_broken) .. "; no_as_mod: " .. tostring(no_as_mod), Color.white)
end

function HUDManager:DebugEvent(event_name)
    managers.chat:_receive_message(1, "[BAI]", "Event called: " .. tostring(event_name), Color.yellow)
end

dofile(BAI.LuaPath .. "network.lua")