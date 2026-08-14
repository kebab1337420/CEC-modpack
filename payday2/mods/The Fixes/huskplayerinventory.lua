TheFixesPreventer = TheFixesPreventer or {}
if not TheFixesPreventer.crash_add_by_blueprint_huskplayerinv then
	local unit_ids = Idstring("unit")

	-- A part that cannot be spawned on the weapon it is assembled on makes
	-- WeaponFactoryManager:_add_part spawn and link a unit that does not belong to that weapon, which
	-- crashes the game with an access violation (no lua error, so no pcall can catch it). The
	-- blueprint is therefore filtered before it reaches the assembly.
	-- Npc weapons are assembled in third person and need a third person unit, player weapons keep the
	-- vanilla behaviour, and parts that carry no unit at all are stat only and always safe.
	local function is_part_usable(part, is_npc)
		if not part then
			return false
		end
		if not part.unit and not part.third_unit then
			return true
		end
		local unit_name = is_npc and part.third_unit or not is_npc and (part.third_unit or part.unit)
		if not unit_name then
			return false
		end
		return not part.custom or DB:has(unit_ids, unit_name:id())
	end

	local function sanitized_blueprint(factory_name, blueprint)
		if not blueprint then
			return blueprint
		end
		local factory = tweak_data.weapon.factory
		local is_npc = factory_name:match("_npc$") ~= nil
		local uses_parts = {}
		local has_part_list = false
		for _, part_id in pairs(factory[factory_name].uses_parts or {}) do
			uses_parts[part_id] = true
			has_part_list = true
		end
		local result = {}
		for _, part_id in pairs(blueprint) do
			if (not has_part_list or uses_parts[part_id]) and is_part_usable(factory.parts[part_id], is_npc) then
				table.insert(result, part_id)
			else
				log("[The Fixes] Skipped weapon part " .. tostring(part_id) .. " on " .. tostring(factory_name) .. ", it cannot be assembled")
			end
		end
		return result
	end

	local add_u_by_blue_orig = HuskPlayerInventory.add_unit_by_factory_blueprint
	function HuskPlayerInventory:add_unit_by_factory_blueprint(factory_name, equip, instant, blueprint, ...)
		if tweak_data.weapon.factory[factory_name] then
			add_u_by_blue_orig(self, factory_name, equip, instant, sanitized_blueprint(factory_name, blueprint), ...)
		end
	end
end

if not TheFixesPreventer.crash_align_place_huskplayerinv then
	function HuskPlayerInventory:_align_place(...)
		local res1, res2 = HuskPlayerInventory.super._align_place(self, ...)
		if res1 and res2 then
			return res1, res2
		elseif debug.getinfo(2).name == 'add_unit_by_factory_blueprint' then
			return res1 or {}
		else
			return res1
		end
	end
end
