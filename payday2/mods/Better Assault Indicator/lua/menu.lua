local BAI = BAI
if BAI:CheckHook("MenuManager") then
    return
end
local cache = {}

---@param item MenuItemMultiChoice
local function _compatibility_denied_callback(item)
    local default_value = 1
    if item:name() == "bai_compatibility_choice" then
        cache._compatibility_warning_showed = false
    else
        cache._hudlist_compatibility_warning_showed = false
        default_value = 2
    end
    item:set_value(default_value)
end

local function ShowWarningMessage(message, item)
    QuickMenu:new(
        managers.localization:text(message),
        managers.localization:text(message .. "_desc"),
        {
            [1] = {
                text = managers.localization:text(message .. "_i_know_what_im_doing"),
                callback = callback(MenuCallbackHandler, MenuCallbackHandler, "bai_set_item_value", item)
            },
            [2] = {
                text = managers.localization:text(message .. "_keep_me_safe"),
                callback = function()
                    _compatibility_denied_callback(item)
                end,
                is_cancel_button = true
        }
    }, true)
end

---@param compare { comparator: string, value: integer }
---@param value integer
local function check_value(compare, value)
    local result = true
    local comparator = compare.comparator or "=="
    local value_to_compare = compare.value
    if comparator == "==" then
        result = value == value_to_compare
    elseif comparator == "<" then
        result = value < value_to_compare
    elseif comparator == "<=" then
        result = value <= value_to_compare
    elseif comparator == ">" then
        result = value > value_to_compare
    elseif comparator == ">=" then
        result = value >= value_to_compare
    elseif comparator == "<>" then
        result = value ~= value_to_compare
    end
    return result
end

---Copy of BLT's MenuHelper with BAI specific changes
---Loads a json-formatted text file and automatically parses and converts into a usable menu
---@param file_path string @Path of the file to load and convert into a menu
---@param data_table table? @Table containing the data keys which various menu items can load their value from
local function LoadFromJsonFile(file_path, data_table)
    local file = io.open(file_path, "r")
    if file then
        local file_content = file:read("*all")
        file:close()

        local content = json.decode(file_content)
        local menu_id = content.menu_id
        local parent_menu = content.parent_menu_id
        local items = content.items
        local menu_priority = content.priority or nil

        -- 1.
        Hooks:Add("MenuManagerSetupCustomMenus", "Base_SetupCustomMenus_Json_" .. menu_id, function(menu_manager, nodes)
            MenuHelper:NewMenu(menu_id)
        end)

        -- 3.
        Hooks:Add("MenuManagerBuildCustomMenus","Base_BuildCustomMenus_Json_" .. menu_id, function(menu_manager, nodes)
            local data = {
                focus_changed_callback = content.focus_changed_callback,
                back_callback = content.back_callback,
                area_bg = content.area_bg
            }
            nodes[menu_id] = MenuHelper:BuildMenu(menu_id, data)

            if menu_priority ~= nil then
                for k, v in pairs(nodes[parent_menu]._items) do
                    if menu_priority > (v._priority or 0) then
                        menu_priority = k
                        break
                    end
                end
            end

            if not content.dont_create_menu_button then
                MenuHelper:AddMenuItem(nodes[parent_menu], menu_id, content.title, content.description, menu_priority)
            end
        end)

        -- 2.
        Hooks:Add("MenuManagerPopulateCustomMenus","Base_PopulateCustomMenus_Json_" .. menu_id, function(menu_manager, nodes)
            local all_items = #items
            local previous_items = {}
            for k, item in ipairs(items) do
                local menu_item
                local i_type = item.type
                local id = item.id
                local title = item.title
                local desc = item.description
                local callback = item.callback
                local priority = item.priority or all_items - k
                local value = item.default_value
                local localized = item.localized
                local disabled = false
                local _data_table = data_table
                if item.load_table and _data_table then
                    _data_table = _data_table[item.load_table]
                end
                if _data_table and _data_table[item.value] ~= nil then
                    value = _data_table[item.value]
                end
                if item.disabled_from_start and MenuCallbackHandler then
                    disabled = not _G.callback(MenuCallbackHandler, MenuCallbackHandler, item.disabled_from_start, value)()
                end
                if i_type == "button" then
                    menu_item = MenuHelper:AddButton({
                        id = id,
                        title = title,
                        desc = desc,
                        callback = callback,
                        next_node = item.next_menu or nil,
                        menu_id = menu_id,
                        priority = priority,
                        localized = localized,
                        disabled = disabled
                    })
                elseif i_type == "toggle" then
                    menu_item = MenuHelper:AddToggle({
                        id = id,
                        title = title,
                        desc = desc,
                        callback = callback,
                        value = value,
                        menu_id = menu_id,
                        priority = priority,
                        localized = localized,
                        disabled = disabled
                    })
                elseif i_type == "slider" then
                    menu_item = MenuHelper:AddSlider({
                        id = id,
                        title = title,
                        desc = desc,
                        callback = callback,
                        value = value,
                        min = item.min or 0,
                        max = item.max or 1,
                        step = item.step or 0.1,
                        show_value = true,
                        display_precision = item.display_precision,
                        display_scale = item.display_scale,
                        is_percentage = item.is_percentage,
                        menu_id = menu_id,
                        priority = priority,
                        localized = localized,
                        disabled = disabled
                    })
                elseif i_type == "divider" then
                    menu_item = MenuHelper:AddDivider({
                        id = "",
                        size = item.size,
                        title = title,
                        menu_id = menu_id,
                        priority = priority,
                        no_text = item.no_text
                    })
                    menu_item:set_parameter("color", Color.white)
                elseif i_type == "multiple_choice" then
                    menu_item = MenuHelper:AddMultipleChoice({
                        id = id,
                        title = title,
                        desc = desc,
                        callback = callback,
                        items = item.items,
                        item_values = item.item_values,
                        value = value,
                        menu_id = menu_id,
                        priority = priority,
                        localized = localized,
                        localized_items = item.localized_items,
                        disabled = disabled
                    })
                elseif i_type == "input" then
					menu_item = MenuHelper:AddInput({
						id = id,
						title = title,
						desc = desc,
						callback = callback,
						value = value,
						menu_id = menu_id,
						priority = priority,
						localized = localized
					})
                elseif i_type == "color" then
                    if item.read_color_directly then
                        value = _data_table or item.default_value
                    else
                        local settings_table = BAI.settings
                        if item.params.setting then
                            value = settings_table[item.params.setting]
                        elseif item.params.settings then
                            for _, setting in ipairs(item.params.settings) do
                                settings_table = settings_table[setting]
                            end
                            value = settings_table
                        end
                    end
                    local data =
                    {
                        type = "BAIMenuItemColor",
                        {
                            _meta = "option",
                            text_id = "bai_r",
                            name = "r",
                            value = value.r,
                            localize = true
                        },
                        {
                            _meta = "option",
                            text_id = "bai_g",
                            name = "g",
                            value = value.g,
                            localize = true
                        },
                        {
                            _meta = "option",
                            text_id = "bai_b",
                            name = "b",
                            value = value.b,
                            localize = true
                        }
                    }
                    local params =
                    {
                        name = id,
                        text_id = title,
                        help_id = desc,
                        callback = callback,
                        localize = localized,
                        localize_help = localized,
                        default_color = item.default_value
                    }
                    local menu = MenuHelper:GetMenu(menu_id)
                    menu_item = menu:create_item(data, params)
                    menu_item:set_value(value)
                    menu_item._priority = priority
                    if disabled then
                        menu_item:set_enabled(not disabled)
                    end
                    menu._items_list = menu._items_list or {}
                    table.insert(menu._items_list, menu_item)
                end
                if menu_item and id then -- Dividers do not have ID assigned
                    previous_items[id] = menu_item
                    if item.value then
                        menu_item:set_parameter("option", item.value)
                    end
                    if item.params or content.global_params then
                        for key, param_value in pairs(item.params or content.global_params) do
                            menu_item:set_parameter(key, param_value)
                        end
                    end
                    if item.child then
                        menu_item:set_parameter("child", item.child)
                    elseif item.children then
                        menu_item:set_parameter("children", item.children)
                    end
                    if item.children_f or item.children_f_and then
                        menu_item:set_parameter("children_f", item.children_f_and or item.children_f)
                    end
                    if item.children_f_or then
                        menu_item:set_parameter("children_f_or", item.children_f_or)
                    end
                    if item.child_compare then
                        menu_item:set_parameter("child_compare", item.child_compare)
                    end
                    if item.parent and previous_items[item.parent] then
                        menu_item:set_enabled(previous_items[item.parent]:value() == "on")
                    end
                    if item.parent_compare and item.parent_compare.id and previous_items[item.parent_compare.id] then
                        local data = item.parent_compare
                        local parent = previous_items[data.id]
                        local result = check_value(data, parent:value())
                        if data.enabled then
                            result = result and parent:enabled()
                        end
                        menu_item:set_enabled(result)
                    elseif item.parents_compare then
                        local final_result = true
                        if item.parents_compare.comparator == "and" then
                            for key, data in pairs(item.parents_compare.items) do
                                local parent = previous_items[key]
                                if parent and not check_value(data, parent:value()) then
                                    final_result = false
                                    break
                                end
                            end
                        else -- or
                            final_result = false
                            for key, data in pairs(item.parents_compare.items) do
                                local parent = previous_items[key]
                                if parent and check_value(data, parent:value()) then
                                    final_result = true
                                    break
                                end
                            end
                        end
                        menu_item:set_enabled(final_result)
                    end
                    if item.other_item_compare and item.other_item_compare.id and previous_items[item.other_item_compare.id] then
                        local data = item.other_item_compare
                        previous_items[data.id]:set_enabled(check_value(data, value)) ---@diagnostic disable-line
                    end
                end
            end
        end)
    else
        BLT:Log(LogLevel.ERROR, string.format("Could not load file '%s'", file_path))
    end
end

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_BAI", function(loc)
    local path = BAI.LocPath
    local language_filename = nil
    if BAI.settings.mod_language == 1 then
        local LanguageKey =
        {
            ["PAYDAY 2 THAI LANGUAGE Mod"] = "thai",
            ["Ultimate Localization Manager & 正體中文化"] = "tchinese",
            ["Payday 2 Korean patch"] = "korean"
        }
        for _, mod in ipairs(BLT and BLT.Mods and BLT.Mods:Mods()) do
            language_filename = mod:IsEnabled() and LanguageKey[mod:GetName()] or nil
            if language_filename then
                break
            end
        end
        if not language_filename then
            for _, filename in ipairs(file.GetFiles(path)) do
                local str = filename:match('^(.*).json$')
                if str and Idstring(str) and Idstring(str):key() == SystemInfo:language():key() then
                    language_filename = str
                    break
                end
            end
        end
        if language_filename then
            BAI.Language = language_filename
            loc:load_localization_file(path .. language_filename .. ".json")
        end
    else
        local Languages =
        {
            [2] = "english",
            [3] = "french",
            [4] = "german",
            [5] = "italian",
            [6] = "russian",
            [7] = "thai",
            [8] = "schinese",
            [9] = "tchinese",
            [10] = "portuguese",
            [11] = "spanish",
            [12] = "korean",
            [13] = "japanese",
            [14] = "czech"
        }
        BAI.Language = Languages[BAI.settings.mod_language]
        loc:load_localization_file(path .. BAI.Language .. ".json")
    end
    if BAI.Language ~= "english" or not language_filename then
        loc:load_localization_file(path .. "english.json", false)
    end
    loc:load_localization_file(path .. "languages.json")
    loc:load_localization_file(path .. "common.json", false)
end)

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_BAI", function(menu_manager)
    LoadFromJsonFile(BAI.MenuPath .. "menu.json", BAI.settings)
    LoadFromJsonFile(BAI.MenuPath .. "assault_box.json", BAI.settings.assault_panel)
    LoadFromJsonFile(BAI.MenuPath .. "endless_box.json", BAI.settings.assault_panel.endless)
    LoadFromJsonFile(BAI.MenuPath .. "survived_box.json", BAI.settings.assault_panel.survived)
    LoadFromJsonFile(BAI.MenuPath .. "escape_box.json", BAI.settings.assault_panel.escape)
    LoadFromJsonFile(BAI.MenuPath .. "assault_states.json", BAI.settings.assault_panel)
    LoadFromJsonFile(BAI.MenuPath .. "advanced_assault_info.json", BAI.settings.advanced_assault_info)
    LoadFromJsonFile(BAI.MenuCompatibilityPath .. "holoui.json", BAI.settings.hud.holoui)
    LoadFromJsonFile(BAI.MenuCompatibilityPath .. "pdth_hud_reborn.json", BAI.settings.hud.pdth_hud_reborn)
    LoadFromJsonFile(BAI.MenuCompatibilityPath .. "restoration_mod.json", BAI.settings.hud.restoration_mod)
    LoadFromJsonFile(BAI.MenuCompatibilityPath .. "restoration_mod/assault_box.json")
    LoadFromJsonFile(BAI.MenuCompatibilityPath .. "restoration_mod/endless_box.json")
    LoadFromJsonFile(BAI.MenuCompatibilityPath .. "restoration_mod/survived_box.json")
    LoadFromJsonFile(BAI.MenuCompatibilityPath .. "restoration_mod/assault_states.json")
    LoadFromJsonFile(BAI.MenuCompatibilityPath .. "halo_reach_hud.json", BAI.settings.hud.halo_reach_hud)
    LoadFromJsonFile(BAI.MenuPath .. "hudlist.json", BAI.settings.hud.hudlist)
    for _, assault_type in ipairs({ "assault", "endless" }) do
        for _, length in ipairs({ "long", "short" }) do
            LoadFromJsonFile(string.format("%scustom_text/%s_box_%s.json", BAI.MenuPath, assault_type, length), BAI.settings.assault_panel[assault_type][length == "short" and "short_custom_text" or "custom_text"])
        end
    end
    local main_menu = menu_manager:get_menu(menu_manager._is_start_menu and "menu_main" or "menu_pause")
    if main_menu then
        local node = CoreMenuNode.MenuNode:new({
            gui_class = "BAIMenuNodeCustomizeGadgetGui",
            modifier = "BAIMenuSetColorInitiator",
            refresh = "BAIMenuSetColorInitiator"
        })
        node:set_callback_handler(MenuCallbackHandler:new())
        main_menu.data._nodes.bai_color_select = node
    else
        BAI:Log("!!!!!!!!!!!!!!! Main Menu does not exist !!!!!!!!!!!!!!!")
    end
end)

---@param item MenuItemMultiChoice|CoreMenuItemSlider.ItemSlider|CoreMenuItemToggle.ItemToggle
function MenuCallbackHandler:bai_set_item_value(item)
    local params, type = item:parameters(), item:type()
    local value
    if type == "slider" then ---@cast item CoreMenuItemSlider.ItemSlider
        value = tonumber(item:raw_value_string())
    elseif type == "toggle" then ---@cast item CoreMenuItemToggle.ItemToggle
        value = item:value() == "on"
    else ---@cast item MenuItemMultiChoice
        value = item:value()
    end
    local settings_table = BAI.settings
    if params.setting then
        settings_table = settings_table[params.setting]
    elseif params.settings then
        for _, setting in ipairs(params.settings) do
            settings_table = settings_table[setting]
        end
    end
    settings_table[params.option] = value
    if params.child then
        for _, row_item in ipairs(params.gui_node.row_items) do
            if row_item.name == params.child then
                row_item.item:set_enabled(value)
                break
            end
        end
    elseif params.children then
        local children = table.list_to_set(params.children)
        for _, row_item in ipairs(params.gui_node.row_items) do
            if children[row_item.name] then
                row_item.item:set_enabled(value)
            end
        end
    end
    if params.child_compare then
        local compare = params.child_compare
        for _, row_item in ipairs(params.gui_node.row_items) do
            local data = compare[row_item.name]
            if data and data.value then
                row_item.item:set_enabled(check_value(data, value --[[@as integer]]))
            end
        end
    end
    if params.children_f then
        for name, f in pairs(params.children_f) do
            for _, row_item in ipairs(params.gui_node.row_items) do
                if row_item.name == name and MenuCallbackHandler[f] then
                    row_item.item:set_enabled(MenuCallbackHandler[f](MenuCallbackHandler, value))
                    break
                end
            end
        end
    end
    if params.children_f_or then
        for name, f in pairs(params.children_f_or) do
            for _, row_item in ipairs(params.gui_node.row_items) do
                if row_item.name == name and MenuCallbackHandler[f] then
                    row_item.item:set_enabled(value or MenuCallbackHandler[f]())
                    break
                end
            end
        end
    end
end

---@param item BAIMenuItemColor
function MenuCallbackHandler:bai_modify_item_color(item)
    managers.menu:open_node("bai_color_select", { { item = item } })
    managers.menu_component:post_event("menu_enter")
end

function MenuCallbackHandler:bai_set_item_color()
    local menu = managers.menu:active_menu()
    if not menu then
        return
    end
    if not menu.logic then
        return
    end
    if not menu.logic:selected_node() then
        return
    end
    local color, item = nil, nil
    local active_node_gui = menu.renderer:active_node_gui()
    if active_node_gui and active_node_gui.update_node_colors then
        color = active_node_gui:update_node_colors()
        item = active_node_gui.node:parameters().menu_component_data.item
    end
    if item and color then
        item:set_value(color)
        local params = item:parameters()
        local settings_table = BAI.settings
        if params.setting then
            settings_table = settings_table[params.setting]
        elseif params.settings then
            for _, setting in ipairs(params.settings) do
                settings_table = settings_table[setting]
            end
        end
        settings_table.r = color.r
        settings_table.g = color.g
        settings_table.b = color.b
    end
    managers.menu:back()
end

function MenuCallbackHandler:BAISave(item)
    BAI:SaveOptions()
    if Utils:IsInHeist() then
        BAI.Update = true
        BAI:LoadCustomText(true)
        managers.hud:UpdateColors()
        if _G.IS_VR then
            managers.hud._hud_assault_corner:UpdatePONRBoxVR()
        end
    end
end

---@param item MenuItemMultiChoice
function MenuCallbackHandler:bai_update_hud_compatibility(item)
    if item:value() ~= 1 and not cache._compatibility_warning_showed then
        cache._compatibility_warning_showed = true
        ShowWarningMessage("bai_compatibility_warning", item)
        return
    end
    MenuCallbackHandler:bai_set_item_value(item)
end

---@param item MenuItemMultiChoice
function MenuCallbackHandler:bai_update_hudlist_compatibility(item)
    if item:value() > 2 and not cache._hudlist_compatibility_warning_showed then
        cache._hudlist_compatibility_warning_showed = true
        ShowWarningMessage("bai_hudlist_compatibility_warning", item)
        return
    end
    MenuCallbackHandler:bai_set_item_value(item)
end

function MenuCallbackHandler:bai_is_holoui_present(value)
    return Holo or value == 5
end

function MenuCallbackHandler:bai_is_pdth_hud_reborn_present(value)
    return pdth_hud or value == 7
end

function MenuCallbackHandler:bai_is_restoration_mod_present(value)
    return restoration or value == 8
end

function MenuCallbackHandler:bai_is_halo_reach_hud_present(value)
    return NobleHUD or value == 11
end

function MenuCallbackHandler.bai_is_hide_text_available_1()
    return BAI:GetOption("show_advanced_assault_info")
end

function MenuCallbackHandler.bai_is_hide_text_available_2()
    return BAI:GetOption("show_assault_states")
end

Hooks:PostHook(MenuCallbackHandler, "resume_game", "BAI_MenuCallbackHandler_resume_game", function(self)
    BAI:EasterEggInit()
    if BAI:IsHost() then
        LuaNetworking:SendToPeersExcept(1, BAI.EE_ResetSyncMessage, "")
    end
    if BAI.Update then
        BAI.Update = nil
        BAI:CallEvent(BAI.EventList.Update)
    end
end)