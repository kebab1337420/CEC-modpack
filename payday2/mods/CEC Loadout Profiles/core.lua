-- CEC Loadout Profiles
--
-- Switching between a stealth build and a loud build means walking through the
-- whole inventory: primary, secondary, mask, armour, melee, throwable, both
-- deployable slots, the skill switch and the perk deck. Nine screens for one
-- decision that was made before the game even launched.
--
-- This mod stores that whole set under a profile number and puts it back with a
-- single key. Three profiles, three load keys, three save keys, all bound from
-- the BLT keybinds menu.
--
-- Everything is applied through the vanilla equip functions, so ownership and
-- unlock checks still run and the lobby outfit sync happens on its own. A piece
-- of gear that is no longer owned is simply skipped instead of breaking the rest
-- of the profile.
--
-- Profiles live in PAYDAY 2/mods/saves/cec_loadout_profiles.json.

if CECLoadouts then
	return
end

CECLoadouts = {}

CECLoadouts.path = (rawget(_G, "SavePath") or "") .. "cec_loadout_profiles.json"
CECLoadouts.profile_count = 3

function CECLoadouts:_all()
	if self._profiles then
		return self._profiles
	end

	local profiles = nil

	pcall(function()
		local file = io.open(self.path, "r")
		if not file then
			return
		end

		local contents = file:read("*all")
		file:close()

		local decoded = json.decode(contents)
		if type(decoded) == "table" then
			profiles = decoded
		end
	end)

	self._profiles = profiles or {}

	return self._profiles
end

function CECLoadouts:_flush()
	local ok = pcall(function()
		local file = io.open(self.path, "w")
		if not file then
			return
		end

		file:write(json.encode(self._profiles or {}))
		file:close()
	end)

	if not ok then
		log("[CEC Loadout Profiles] could not write " .. tostring(self.path))
	end
end

-- Reads the current selection. Every getter is wrapped because a fresh profile,
-- a missing DLC or an inventory the game has not finished loading can make any
-- of them nil.
function CECLoadouts:_capture()
	local bm = managers.blackmarket
	local skills = managers.skilltree
	local player = managers.player

	if not bm or not skills or not player then
		return nil
	end

	local data = {}

	local function try(key, getter)
		local ok, value = pcall(getter)
		if ok and value ~= nil then
			data[key] = value
		end
	end

	try("primary", function()
		return bm:equipped_weapon_slot("primaries")
	end)
	try("secondary", function()
		return bm:equipped_weapon_slot("secondaries")
	end)
	try("mask", function()
		return bm:equipped_mask_slot()
	end)
	try("armor", function()
		return bm:equipped_armor(false, false)
	end)
	try("melee", function()
		return bm:equipped_melee_weapon()
	end)
	try("grenade", function()
		return bm:equipped_grenade()
	end)
	try("character", function()
		return bm:equipped_character()
	end)
	try("deployable_1", function()
		return player:equipment_in_slot(1)
	end)
	try("deployable_2", function()
		return player:equipment_in_slot(2)
	end)
	try("skill_switch", function()
		return skills:get_selected_skill_switch()
	end)
	try("perk_deck", function()
		return skills:get_specialization_value("current_specialization")
	end)

	-- A capture with no weapon in it means the inventory was not readable, and
	-- storing that would silently destroy the profile.
	if not data.primary and not data.secondary then
		return nil
	end

	return data
end

function CECLoadouts:Save(index)
	if type(index) ~= "number" or index < 1 or index > self.profile_count then
		return
	end

	local data = self:_capture()
	if not data then
		log("[CEC Loadout Profiles] inventory not readable, profile " .. tostring(index) .. " left untouched")
		return
	end

	local profiles = self:_all()
	profiles[tostring(index)] = data
	self:_flush()

	pcall(function()
		managers.menu:post_event("item_buy")
	end)

	log("[CEC Loadout Profiles] profile " .. tostring(index) .. " saved")
end

function CECLoadouts:Load(index)
	if type(index) ~= "number" or index < 1 or index > self.profile_count then
		return
	end

	local data = self:_all()[tostring(index)]
	if type(data) ~= "table" then
		log("[CEC Loadout Profiles] profile " .. tostring(index) .. " is empty")
		pcall(function()
			managers.menu:post_event("menu_error")
		end)
		return
	end

	local bm = managers.blackmarket
	local skills = managers.skilltree
	if not bm or not skills then
		return
	end

	local function try(getter)
		pcall(getter)
	end

	-- Skills first: the skill switch carries its own perk deck, so restoring it
	-- afterwards would be overwritten.
	if data.skill_switch then
		try(function()
			skills:switch_skills(data.skill_switch)
		end)
	end

	if data.perk_deck then
		try(function()
			skills:set_current_specialization(data.perk_deck)
		end)
	end

	if data.primary then
		try(function()
			bm:equip_weapon("primaries", data.primary)
		end)
	end

	if data.secondary then
		try(function()
			bm:equip_weapon("secondaries", data.secondary)
		end)
	end

	if data.mask then
		try(function()
			bm:equip_mask(data.mask)
		end)
	end

	if data.armor then
		try(function()
			bm:equip_armor(data.armor)
		end)
	end

	if data.melee then
		try(function()
			bm:equip_melee_weapon(data.melee)
		end)
	end

	if data.grenade then
		try(function()
			bm:equip_grenade(data.grenade)
		end)
	end

	if data.character then
		try(function()
			bm:equip_character(data.character)
		end)
	end

	-- Slot 2 only exists with the right skill, and equip_deployable already
	-- refuses gear the player cannot use. Passing nil clears the slot, which is
	-- what a profile saved without a second deployable should do.
	try(function()
		bm:equip_deployable({
			target_slot = 1,
			name = data.deployable_1
		})
	end)
	try(function()
		bm:equip_deployable({
			target_slot = 2,
			name = data.deployable_2
		})
	end)

	-- The inventory screens cache what they draw, so the open node has to be
	-- rebuilt for the new selection to show up.
	try(function()
		MenuCallbackHandler:_update_outfit_information()
	end)
	try(function()
		managers.menu:active_menu().logic:refresh_node()
	end)
	try(function()
		managers.menu:post_event("item_buy")
	end)

	log("[CEC Loadout Profiles] profile " .. tostring(index) .. " applied")
end
