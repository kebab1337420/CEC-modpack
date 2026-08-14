function PVM:Init()
    self.default_stances = {}
	self.black_list = {mask_off = true, civilian = true, clean = true}
    self._global_mode = false

    self.refresh_key = self.Options:GetValue("RefreshKey")

    self._menu = MenuUI:new({
        offset = 6,
        toggle_key = self.Options:GetValue("ToggleKey"),
        toggle_clbk = callback(self, self, "ShowMenu"),
        create_items = callback(self, self, "CreateItems"),
        use_default_close_key = true,
        layer = 500,
        key_press = function(o, k)
            if k == Idstring(self.refresh_key) then
                self:Refresh()
            end
        end
    })

    PVM:UpgradeSave()
end

Hooks:Add("MenuManagerInitialize", "PVM", function()
	MenuCallbackHandler.PVM = ClassClbk(PVM._menu, "SetEnabled", true)
	local node = MenuHelperPlus:GetNode(nil, "blt_options")
	if node then
		MenuHelperPlus:AddButton({
			id = "PVM",
			title = "Perfect Viewmodel",
			localized = false,
			node = node,
			callback = "PVM",
		})
	end
end)

function PVM:AddDefaultToWeapon(weapon_id, stance_id, stance)
    self.default_stances[weapon_id] = self.default_stances[weapon_id] or {}
    self.default_stances[weapon_id][stance_id] = self.default_stances[weapon_id][stance_id] or {
        translation = mvector3.copy(stance.translation or Vector3()),
        rotation = mrotation.copy(stance.rotation or Rotation())
    }
end

function PVM:CreateItems(menu)
    self._menu = menu
    local accent = BeardLib.Options:GetValue("MenuColor")
    self._holder = self._menu:DivGroup({
        name = "Holder",
        w = 400,
		text = "Perfect Viewmodel",
        auto_height = false,
        size = 20,
        background_visible = true,
        border_bottom = true,
        border_center_as_title = true,
        border_position_below_title = true,
        private = {text_align = "center"},
        border_lock_height = true,
        accent_color = accent,
        background_color = Color(0.75, 0.15, 0.15, 0.15),
    })
end

function PVM:Refresh()
    self:ShowMenu()
end

function PVM:ShowMenu(menu, opened)
	self._holder:ClearItems()
	if opened then
		game_state_machine:current_state():set_controller_enabled(false)

		local weapon_id = self:GetWeaponId()
        local stances = self:GetWeaponStances()

        self._settings_group = self._holder:DivGroup({text = "PVM Settings", border_left = true, border_lock_height = true})
        self._settings_group:KeyBind({name = "ToggleKey", value = self.Options:GetValue("ToggleKey"), text = "Toggle key", on_callback = callback(self, self, "Set")})
        self._settings_group:KeyBind({name = "RefreshKey", value = self.Options:GetValue("RefreshKey"), text = "Refresh key", on_callback = callback(self, self, "Set")})
        self._settings_group:NumberBox({name = "TranslationStep", value = self.Options:GetValue("TranslationStep"), text = "Translation Slider Step", on_callback = callback(self, self, "Set")})
        self._settings_group:NumberBox({name = "RotationStep", value = self.Options:GetValue("RotationStep"), text = "Rotation Slider Step", on_callback = callback(self, self, "Set")})
        self._settings_group:Toggle({
            name = "ApplyOnAll",
            value = self.Options:GetValue("ApplyOnAll"),
            text = "Allow Global Setting",
            help = "If enabled, allows for 'Global Mode' which sets a setting for all weapons. If a weapon has its own setting, it'll be used instead of the global.",
            on_callback = callback(self, self, "Set")
        })

        self._settings_group:Button({
            name = "Reset All Weapons",
            on_callback = function()
                QuickDialog({
                    force = true,
                    title = "Alert",
                    message = "Are you sure you want to reset all weapons?",
                    no = "No"
                }, {{"Yes", function()
                    self.Options:SetValue("Saved", {})
                    self.Options:Save()
                    self:RefreshState()
                    self:RefreshState()
                end}})
            end
        })

        if weapon_id then
            self._weapon_group = self._holder:DivGroup({text = weapon_id or "N/A", border_left = true, border_lock_height = true})

            self._weapon_group:Button({
                name = "Reset Weapon",
                on_callback = function()
                    QuickDialog({
                        force = true,
                        title = "Alert",
                        message = "Are you sure you want to reset this weapon?",
                        no = "No"
                    }, {{"Yes", function()
                        for name in pairs(stances) do
                            self:ResetStance(name)
                        end
                    end}})
                end
            })
            self._weapon_group:Toggle({
                name = "GlobalMode",
                value = self._global_mode,
                text = "All Weapons Mode",
                on_callback = function(item) self._global_mode = item:Value() end,
                visible = self.Options:GetValue("ApplyOnAll")
            })
        end

        local stances_copy = table.map_values(stances, function(a, b)
            if (a.is_part and b.is_part) or (not a.is_part and not b.is_part) then
                return a.id > b.id
            else
                return not a.is_part
            end
        end)
        for _, stance in pairs(stances_copy) do
            self:StanceEdit(stance.id, stance.data.translation or Vector3(), true)
            self:StanceEdit(stance.id, stance.data.rotation or Rotation(), true)
        end
    else
		game_state_machine:current_state():set_controller_enabled(true)
        self._menu:disable()
    end
end

function PVM:Set(item)
    local name, value = item.name, item:Value()
    self.Options:SetValue(name, value)
    if name == "ToggleKey" then
        self._menu.toggle_key = value
    end
    if name == "RefreshKey" then
        self.refresh_key = value
    end
    if name == "ApplyOnAll" and self._weapon_group then
        self._weapon_group:GetItem("GlobalMode"):SetVisible(value)
    end

    if name == "RotationStep" or name == "TranslationStep" then
		for name in pairs(self:GetWeaponStances()) do
            local panel = self._weapon_group:GetMenu(name)
            if panel then
                local pos = panel:GetItem(name == "TranslationStep" and "Vector3" or "Rotation")
                for _, item in pairs(pos:Items()) do
                    item:SetStep(value)
                end
            end
        end
    end
end

function PVM:StanceEdit(stance_id, pos, is_part)
    local panel = self._weapon_group:GetMenu(stance_id)
    if not panel then
        local toggleable = stance_id == "crouched" or stance_id == "standard" or stance_id == "steelsight"
        panel = self._weapon_group:DivGroup({
            name = stance_id,
            border_left = true,
            border_lock_height = true,
            private = {
                offset = 16,
                full_bg_color = Color(0.5, 0, 0, 0),
            },
            align_method = "grid",
        })
        local tb = panel:GetToolbar()
        if toggleable then
            tb:Button({
                text = "Toggle",
                size_by_text = true,
                on_callback = ClassClbk(self, "Toggle", stance_id)
            })
        end
        tb:Button({
            text = "Reset",
            size_by_text = true,
            on_callback = function()
                self:ResetStance(stance_id)
                if self._last_toggled == stance_id then
                    self:Toggle(stance_id)
                end
            end
        })
        tb:Button({
            text = "Copy XML",
            size_by_text = true,
            on_callback = function()
                local pos = panel:GetItem("Vector3")
                local rot = panel:GetItem("Rotation")
                if pos and rot then
                    local posrot = {
                        translation = Vector3(pos:GetItem("x"):Value(), pos:GetItem("y"):Value(), pos:GetItem("z"):Value()),
                        rotation = Rotation(rot:GetItem("yaw"):Value(), rot:GetItem("pitch"):Value(), rot:GetItem("roll"):Value()),
                    }
                    local t = is_part and posrot or {[stance_id] = {shoulders = posrot}}
                    Application:set_clipboard(tostring(ScriptSerializer:to_custom_xml(t)))
                end
            end
        })
    end
    local rot = pos.type_name == "Rotation"
    local control_panel = panel:DivGroup({
        name = pos.type_name,
        text_align = "left",
        text = rot and "Rotate" or "Translate",
        index = not rot and 4,
        align_method = "grid",
    })

    local step = rot and PVM.Options:GetValue("RotationStep") or PVM.Options:GetValue("TranslationStep")

    for _, axis in pairs(rot and {"yaw", "pitch", "roll"} or {"x","y","z"}) do
        local value = rot and mrotation[axis](pos) or pos[axis]
        control_panel:NumberBox({
            name = axis,
            value = value,
            is_rotation = rot,
            text = axis,
            stance_id = stance_id,
            offset = 0,
            w = control_panel.w / 3,
            step = step,
            control_slice = 0.6,
            floats = 3,
            on_callback = callback(self, self, "ItemSetStance"),
        })
    end
end

function PVM:Toggle(name)
    local state = managers.player:player_unit():movement():current_state()
    self._last_toggled = name
    if name == "crouched" then
        state:_start_action_ducking()
    end
    if name == "standard" then
        state:_end_action_steelsight()
        state:_end_action_ducking()
    end
    if name == "steelsight" then
        state:_start_action_steelsight()
    end
end

function PVM:ItemSetStance(item)
    local saved = self.Options:GetValue("Saved")

    local weapon_id = self:GetWeaponId()
    local save_weapon_id = self._global_mode and "__All" or weapon_id
    local stance = self:GetWeaponStances()[item.stance_id].data

    saved[save_weapon_id] = saved[save_weapon_id] or {}
    saved[save_weapon_id][item.stance_id] = saved[save_weapon_id][item.stance_id] or {}
    stance.rotation = stance.rotation or Rotation()
    stance.translation = stance.translation or Vector3()
    if item.is_rotation then
        mrotation["set_" .. item.text](stance.rotation, item.value)
        saved[save_weapon_id][item.stance_id].rotation = mrotation.copy(stance.rotation)
    else
        mvector3["set_" .. item.text](stance.translation, item.value)
        saved[save_weapon_id][item.stance_id].translation = mvector3.copy(stance.translation)
    end
    self.Options:Save()
    self:RefreshState()
end

function PVM:RefreshState()
    -- Handles with WeaponLib's caching so you can change stance and see the effects
    local weapon_factory = managers.weapon_factory
    if weapon_factory._method_caches then
        weapon_factory._method_caches._part_data = {}
        weapon_factory._method_caches.get_stance_mod = {}
    end

    if managers.player:player_unit() then
        local state = managers.player:player_unit():movement():current_state()
        state:_stance_entered()
        if state._state_data.current_state == "bipod" then
            state:exit(nil, "standard")
            managers.player:set_player_state(state._state_data.current_state)
        end
    end

    self:ReloadStanceTweak()
end

PVM._weapon_ids_cache = {}
function PVM:ReloadStanceTweak()
    for weapon_id, stances in pairs(tweak_data.player.stances) do
        for stance_name, mode in pairs(stances) do
            if mode.shoulders then
                PVM:SetStanceFromSave(weapon_id, stance_name, mode.shoulders)
            end
        end
    end

    for part_id, data in pairs(tweak_data.weapon.factory) do
        if data.stance_mods then
            for factory_id, stance_mod in pairs(data.stance_mods) do
                local weapon_id = self._weapon_ids_cache[factory_id] or managers.weapon:get_weapon_id_by_factory_id(factory_id)
                self._weapon_ids_cache[factory_id] = weapon_id
                PVM:SetStanceFromSave(weapon_id, part_id, stance_mod)
            end
        end
    end
end

function PVM:ResetStance(stance_id)
    local weapon_id = self:GetWeaponId()
    local default = self.default_stances[weapon_id]

    if not default then
        PVM:Err("No defaults found for weapon %s", weapon_id)
        return
    end

    if not default[stance_id] then
        PVM:Err("No default found for stance ID %s weapon %s", stance_id, weapon_id)
        return
    end


    local stance = self:GetWeaponStances()[stance_id].data
    local saved = self.Options:GetValue("Saved")
    local save_weapon_id = self._global_mode and "__All" or weapon_id

    if saved[save_weapon_id] then
        saved[save_weapon_id][stance_id] = nil
    end
    stance.translation = mvector3.copy(default[stance_id].translation)
    stance.rotation = mrotation.copy(default[stance_id].rotation)
    local panel = self._holder:GetItem(stance_id)
    if panel then
        local pos_p = panel:GetItem("Vector3")
        local rot_p = panel:GetItem("Rotation")
        if pos_p and rot_p then
            for _, axis in pairs({"x","y","z"}) do
                pos_p:GetItem(axis):SetValue(stance.translation[axis])
            end
            for _, axis in pairs({"yaw","pitch","roll"}) do
                rot_p:GetItem(axis):SetValue(stance.rotation[axis](stance.rotation))
            end
        end
    end
    self.Options:Save()
    self:RefreshState()
end

--- Upgrades the save file to 2.0 format (Removes pointless shoulder key)
function PVM:UpgradeSave()
    local saved = PVM.Options:GetValue("Saved")
    local changed = false
    if saved then
        for _, weapon in pairs(saved) do
            for _, mode in pairs(weapon) do
                if type(mode) == "table" and mode.shoulders then
                    changed = true
                    mode.translation = mode.shoulders.translation
                    mode.rotation = mode.shoulders.rotation
                    mode.shoulders = nil
                end
            end
        end
    end
    if changed then
        PVM.Options:Save()
    end
end

--- Sets a given stance table to the saved values
---@param weapon_id string ID of the weapon (not factory ID!)
---@param stance_id string ID of the stance, can be a stnace or part_id.
---@param stance table the stance table to modify (for regular it's the shoulders, otherwise stance_mod[weapon_id])
function PVM:SetStanceFromSave(weapon_id, stance_id, stance)
	local saved = PVM.Options:GetValue("Saved")
    local saved_weapon = saved[weapon_id]

    if self.Options:GetValue("ApplyOnAll") and (not saved_weapon or (saved_weapon and not saved_weapon[stance_id])) then
        saved_weapon = saved.__All
    end

    self:AddDefaultToWeapon(weapon_id, stance_id, stance)

    if saved then
        local default_stance = self.default_stances[weapon_id][stance_id]
        stance.translation = mvector3.copy(default_stance.translation)
        stance.rotation = mrotation.copy(default_stance.rotation)
        if saved_weapon and saved_weapon[stance_id] then
            local saved_stance = saved_weapon[stance_id]
            if saved_stance.translation then
                stance.translation = mvector3.copy(saved_stance.translation)
            end
            if saved_stance.rotation then
                stance.rotation = mrotation.copy(saved_stance.rotation)
            end
        end
    end
end

function PVM:GetWeaponStances()
    if not managers.player:player_unit() then
        return {}
    end

    local state = managers.player:player_unit():movement():current_state()
    local weapon = alive(state._equipped_unit) and state._equipped_unit:base()

	if not weapon._blueprint or not weapon._factory_id then
		return {}
	end
	return managers.weapon_factory:get_stances(weapon._factory_id, weapon._blueprint)
end

function PVM:GetWeaponId()
    if not managers.player:player_unit() then
        return nil
    end

    local state = managers.player:player_unit():movement():current_state()
    local weapon = alive(state._equipped_unit) and state._equipped_unit:base()
    return weapon and weapon:get_name_id() or "default"
end