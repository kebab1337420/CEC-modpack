function ElementInventoryDummy:assemble_mask(mask_id, blueprint, position, rotation)
	position = position or self._values.position
	rotation = rotation or self._values.rotation
	local mask_unit_name = managers.blackmarket:mask_unit_name_by_mask_id(mask_id)

	managers.dyn_resource:load(Idstring("unit"), Idstring(mask_unit_name), DynamicResourceManager.DYN_RESOURCES_PACKAGE, false)

	self._mask_unit = World:spawn_unit(Idstring(mask_unit_name), position, rotation)
	local mask_tweak_data = mask_id and tweak_data.blackmarket.masks[mask_id] or {}

	if not mask_tweak_data.type then
		local backside = World:spawn_unit(Idstring("units/payday2/masks/msk_backside/msk_backside"), position, rotation, position, rotation)

		self._mask_unit:link(self._mask_unit:orientation_object():name(), backside, backside:orientation_object():name())
	end

	self._mask_unit:base():apply_blueprint(blueprint)
	self._mask_unit:set_moving(true)
end