function WeaponFactoryManager:get_stances(factory_id, blueprint)
	local stance_mods = {}
	local assembled_blueprint =  self:get_assembled_blueprint(factory_id, blueprint)
	local forbidden = self:_get_forbidden_parts(factory_id, assembled_blueprint)
	local weapon_id = self:get_weapon_id_by_factory_id(factory_id)

	local stances_tweak = tweak_data.player.stances
	for stance_id, stance in pairs(weapon_id and stances_tweak[weapon_id] or stances_tweak.default) do
		if tonumber(stance_id) == nil and stance.shoulders and not PVM.black_list[stance_id] then
			stance_mods[stance_id] = {
				id = stance_id,
				is_part = false,
				data = stance.shoulders
			}
		end
    end

	for _, part_id in ipairs(assembled_blueprint) do
		if not forbidden[part_id] and not PVM.black_list[part_id] then
			local part = self:_part_data(part_id, factory_id)
			if part.stance_mod and part.stance_mod[factory_id] then
				local stance_data = part.stance_mod[factory_id]
				stance_mods[part_id] = {
					id = part_id,
					is_part = true,
					data = stance_data
				}
			end
		end
	end

	return stance_mods
end

PVM:ReloadStanceTweak()