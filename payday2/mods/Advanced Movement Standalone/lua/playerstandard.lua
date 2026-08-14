_G.AdvMov = _G.AdvMov or {}
AdvMov._path = ModPath
AdvMov._data_path = SavePath .. 'advmovsave.txt'
AdvMov.settings = AdvMov.settings or {
	runkick = false,
	kickyeet = 1,
	goldeneye = 1,
	slidestealth = 2,
	slideloud = 3,
	slidewpnangle = 15,
	wallrunwpnangle = 15,
	dashcontrols = 4
}

function AdvMov:Save()
	local file = io.open(AdvMov._data_path, 'w+')
	if file then
		file:write(json.encode(AdvMov.settings))
		file:close()
	end
end

function AdvMov:Load()
	local file = io.open(AdvMov._data_path, 'r')
	if file then
		for k, v in pairs(json.decode(file:read('*all')) or {}) do
			AdvMov.settings[k] = v
		end
		file:close()
	end
end

AdvMov.Load()
-- generate save data even if nobody ever touches the mod options menu
AdvMov.Save()


function PlayerStandard:_stance_entered(unequipped, timemult)
	local stance_standard = tweak_data.player.stances.default[managers.player:current_state()] or tweak_data.player.stances.default.standard
	local head_stance = self._state_data.ducking and tweak_data.player.stances.default.crouched.head or stance_standard.head
	local stance_id = nil
	local stance_mod = {
		translation = Vector3(0, 0, 0),
		rotation = Rotation(0, 0, 0)
	}

	local head_duration = tweak_data.player.TRANSITION_DURATION or 0.23
	local head_duration_multiplier = 1
	local duration = head_duration + (self._equipped_unit:base():transition_duration() or 0)
	--local duration = tweak_data.player.TRANSITION_DURATION + (self._equipped_unit:base():transition_duration() or 0)
	local duration_multiplier = self._state_data.in_steelsight and 1 / self._equipped_unit:base():enter_steelsight_speed_multiplier() or 1

	-- Diesel 3.0 : transition de stance instantanee (equip rapide, sortie de bipod, etc.)
	if self._instant_stance_transition then
		self._instant_stance_transition = nil
		duration_multiplier = 0
	end

	if not unequipped then
		stance_id = self._equipped_unit:base():get_stance_id()

		if self._state_data.in_steelsight and self._equipped_unit:base().stance_mod then
			stance_mod = self._equipped_unit:base():stance_mod() or stance_mod
		end
	end

	-- geddan
--[[
	stance_mod.rotation = stance_mod.rotation * Rotation(math.random(-90, 90), math.random(-90, 90), math.random(-90, 90))
	duration = 0.01
--]]


	-- shift melee weapons
	local tdmelee = tweak_data.blackmarket.melee_weapons[managers.blackmarket:equipped_melee_weapon()]
	if self._state_data.meleeing and tdmelee.stance_mod then
		if tdmelee.stance_mod.translation then
			stance_mod.translation = stance_mod.translation + tdmelee.stance_mod.translation
		end
		if tdmelee.stance_mod.rotation then
			stance_mod.rotation = stance_mod.rotation * tdmelee.stance_mod.rotation
		end
	end


	-- mid-reload viewmodel adjustments aka flipturn
	local reload_timed_stances = self._equipped_unit:base()._reload_timed_stance_mod
	if self:_is_reloading() and reload_timed_stances and self._flipturn_reload_state then
		local empty = 0
		local values = reload_timed_stances.not_empty
		if self._flipturn_reload_state > 99 then
			empty = 100
			values = reload_timed_stances.empty
		end
		if values then
			if self:in_steelsight() then
				values = values.ads
			else
				values = values.hip
			end
		end
		local flipturn_index = self._flipturn_reload_state - empty
		if values and values[flipturn_index] then
			if values[flipturn_index].translation then
				stance_mod.translation = stance_mod.translation + values[flipturn_index].translation
			end
			if values[flipturn_index].rotation then
				stance_mod.rotation = stance_mod.rotation * values[flipturn_index].rotation
			end
			if values[flipturn_index].sound and (flipturn_index > self._last_flipturn_sound) then
				self._unit:sound():_play(values[flipturn_index].sound)
				self._last_flipturn_sound = flipturn_index
			end
			duration_multiplier = duration_multiplier / (values[flipturn_index].speed or 1)
			duration_multiplier = duration_multiplier / (self._equipped_unit:base():reload_speed_multiplier()/self._equipped_unit:base():standard_reload_speed_multiplier())
		end
	end

	-- shell-by-shell viewmodel adjustments
	local shotgun_ammo_stances = self._equipped_unit:base()._shotgun_ammo_stance_mod
	if self:_is_reloading() and shotgun_ammo_stances then
		local values = shotgun_ammo_stances
		if values then
			if self:in_steelsight() then
				values = values.ads
			else
				values = values.hip
			end
		end
		local ammovalue = self._equipped_unit:base():get_ammo_remaining_in_clip() + 1
		if values and values[ammovalue] then
			if values[ammovalue].translation then
				stance_mod.translation = stance_mod.translation + values[ammovalue].translation
			end
			if values[ammovalue].rotation then
				stance_mod.rotation = stance_mod.rotation * values[ammovalue].rotation
			end
			if values[ammovalue].sound and (ammovalue > self._last_flipturn_sound) then
				self._unit:sound():_play(values[ammovalue].sound)
				self._last_flipturn_sound = ammovalue
			end
			duration_multiplier = duration_multiplier / (values[ammovalue].speed or 1)
			duration_multiplier = duration_multiplier / (self._equipped_unit:base():reload_speed_multiplier()/self._equipped_unit:base():standard_reload_speed_multiplier())
		end
	end

	-- post-shooting viewmodel adjustments aka shootturn
	-- works differently than the reload ones because i don't feel like going back and unfucking how the reload shit works
	local fire_timed_stances = self._equipped_unit:base()._fire_timed_stance_mod
	if fire_timed_stances and not self:_is_reloading() then
		if self:in_steelsight() then
			fire_timed_stances = fire_timed_stances.ads
		else
			fire_timed_stances = fire_timed_stances.hip
		end

		if fire_timed_stances[self._shootturn_state] then
			if fire_timed_stances[self._shootturn_state].translation then
				stance_mod.translation = stance_mod.translation + fire_timed_stances[self._shootturn_state].translation
			end
			if fire_timed_stances[self._shootturn_state].rotation then
				stance_mod.rotation = stance_mod.rotation * fire_timed_stances[self._shootturn_state].rotation
			end
			if fire_timed_stances[self._shootturn_state].sound and (self._shootturn_state > self._last_shootturn_sound) then
				if fire_timed_stances[self._shootturn_state].round_sound then
					if fire_timed_stances[self._shootturn_state].round_sound[self._equipped_unit:base():get_ammo_remaining_in_clip()] and fire_timed_stances[self._shootturn_state].round_sound[self._equipped_unit:base():get_ammo_remaining_in_clip()] == self._equipped_unit:base():get_ammo_remaining_in_clip() then
						self._unit:sound():_play(fire_timed_stances[self._shootturn_state].sound)
						self._last_shootturn_sound = self._shootturn_state
					end
				else
					self._unit:sound():_play(fire_timed_stances[self._shootturn_state].sound)
					self._last_shootturn_sound = self._shootturn_state
				end
			end
			duration_multiplier = duration_multiplier / (fire_timed_stances[self._shootturn_state].speed or 1)
			if self._shootturn_state == #fire_timed_stances then
				self._shootturn_state = nil
				self._last_shootturn_sound = 0
			end
		end
		duration_multiplier = duration_multiplier / (self._equipped_unit:base():fire_rate_multiplier())
	end

	-- static adjustment of stance when reloading
	if self._equipped_unit:base()._reload_stance_mod and self:_is_reloading() then
		if self._state_data.in_steelsight and self._equipped_unit:base()._reload_stance_mod.ads then
			if self._equipped_unit:base()._reload_stance_mod.ads.translation then
				stance_mod.translation = stance_mod.translation + self._equipped_unit:base()._reload_stance_mod.ads.translation
			end
			if self._equipped_unit:base()._reload_stance_mod.ads.rotation then
				stance_mod.rotation = stance_mod.rotation * self._equipped_unit:base()._reload_stance_mod.ads.rotation
			end
		elseif self._equipped_unit:base()._reload_stance_mod.hip then
			if self._equipped_unit:base()._reload_stance_mod.hip.translation then
				stance_mod.translation = stance_mod.translation + self._equipped_unit:base()._reload_stance_mod.hip.translation
			end
			if self._equipped_unit:base()._reload_stance_mod.hip.rotation then
				stance_mod.rotation = stance_mod.rotation * self._equipped_unit:base()._reload_stance_mod.hip.rotation
			end
		end
	end
	-- or while equipping
	if self._equipped_unit:base()._equip_stance_mod and self:is_equipping() then
		if self._equipped_unit:base()._equip_stance_mod.ads and self._state_data.in_steelsight then
			if self._equipped_unit:base()._equip_stance_mod.ads.translation then
				stance_mod.translation = stance_mod.translation + self._equipped_unit:base()._equip_stance_mod.ads.translation
			end
			if self._equipped_unit:base()._equip_stance_mod.ads.rotation then
				stance_mod.rotation = stance_mod.rotation * self._equipped_unit:base()._equip_stance_mod.ads.rotation
			end
		elseif self._equipped_unit:base()._equip_stance_mod.hip then
			if self._equipped_unit:base()._equip_stance_mod.hip.translation then
				stance_mod.translation = stance_mod.translation + self._equipped_unit:base()._equip_stance_mod.hip.translation
			end
			if self._equipped_unit:base()._equip_stance_mod.hip.rotation then
				stance_mod.rotation = stance_mod.rotation * self._equipped_unit:base()._equip_stance_mod.hip.rotation
			end
		end
	end
	-- or while sliding (and not ADS)
	if self._is_sliding and not self._state_data.in_steelsight then
		stance_mod.translation = stance_mod.translation + Vector3(0, -3, 0)
		stance_mod.rotation = stance_mod.rotation * Rotation(0, 0, AdvMov.settings.slidewpnangle)
	end
	if self._is_wallrunning and not self._state_data.in_steelsight then
		stance_mod.translation = stance_mod.translation + Vector3(0, -3, 0)
		stance_mod.rotation = stance_mod.rotation * Rotation(0, 0, -1 * AdvMov.settings.wallrunwpnangle)
	end
	if timemult then
		duration_multiplier = duration_multiplier * timemult
	end

	-- goldeneye
	if ((AdvMov.settings.goldeneye == 2 and self._equipped_unit:base().akimbo) or AdvMov.settings.goldeneye == 3 or self._equipped_unit:base()._use_goldeneye_reload) and self:_is_reloading() then
		stance_mod.translation = Vector3(0, 0, -100)
		stance_mod.rotation = Rotation(0, 0, 0)
	end

	local stances = nil
	stances = (self:_is_meleeing() or self:_is_throwing_projectile()) and tweak_data.player.stances.default or tweak_data.player.stances[stance_id] or tweak_data.player.stances.default
	local misc_attribs = stances.standard
	--misc_attribs = (not self:_is_using_bipod() or self:_is_throwing_projectile() or stances.bipod) and (self._state_data.in_steelsight and stances.steelsight or self._state_data.ducking and stances.crouched or stances.standard)
	misc_attribs = self:_is_using_bipod() and not self:_is_throwing_projectile() and stances.bipod or self._state_data.in_steelsight and stances.steelsight or self._state_data.ducking and stances.crouched or stances.standard
	local new_fov = self:get_zoom_fov(misc_attribs) + 0
	
	self._camera_unit:base():clbk_stance_entered(misc_attribs.shoulders, head_stance, misc_attribs.vel_overshot, new_fov, misc_attribs.shakers, stance_mod, duration_multiplier, duration, head_duration_multiplier, head_duration)
	--self._camera_unit:base():clbk_stance_entered(misc_attribs.shoulders, head_stance, misc_attribs.vel_overshot, new_fov, misc_attribs.shakers, stance_mod, duration_multiplier, duration)
	managers.menu:set_mouse_sensitivity(self:in_steelsight())
end




Hooks:PostHook(PlayerStandard, "update", "advmovupdate", function(self, t, dt)
	self._last_t = t
	self._last_dt = dt

	-- geddan
--[[
	self._geddan = self._geddan or 0
	if (t - 0.05) > self._geddan then
		self:_stance_entered()
		self._geddan = t
	end
--]]
end)

--[[
function PlayerStandard:_start_action_jump(t, action_start_data)
	-- don't fuck with the animation if melee weapon is still out
	if self._running and not self.RUN_AND_RELOAD and not self._equipped_unit:base():run_and_shoot_allowed() and not self:_is_meleeing() then
		self:_interupt_action_reload(t)
		self._ext_camera:play_redirect(self:get_animation("stop_running"), self._equipped_unit:base():exit_run_speed_multiplier())
	end

	self:_interupt_action_running(t)

	self._jump_t = t
	local jump_vec = action_start_data.jump_vel_z * math.UP

	self._unit:mover():jump()

	if self._move_dir then
		local move_dir_clamp = self._move_dir:normalized() * math.min(1, self._move_dir:length())
		self._last_velocity_xy = move_dir_clamp * action_start_data.jump_vel_xy
		self._jump_vel_xy = mvector3.copy(self._last_velocity_xy)
	else
		self._last_velocity_xy = Vector3()
	end

	self:_perform_jump(jump_vec)
end
--]]



function PlayerStandard:_get_max_walk_speed(t, force_run)
	local speed_tweak = self._tweak_data.movement.speed
	local movement_speed = speed_tweak.STANDARD_MAX
	local speed_state = "walk"
	local ads_mult = 1

	if self._is_sliding then
		movement_speed = self._slide_speed
		speed_state = "run"
	elseif self._is_wallrunning then
		movement_speed = self._wallrun_speed
		speed_state = "run"
	elseif self._is_wallkicking then
		movement_speed = speed_tweak.RUNNING_MAX * 1.5
		speed_state = "run"
	elseif self._state_data.in_steelsight and not managers.player:has_category_upgrade("player", "steelsight_normal_movement_speed") and not self:_is_reloading() and not _G.IS_VR then
		-- allow full walkspeed while reloading
		movement_speed = speed_tweak.STEELSIGHT_MAX
		speed_state = "steelsight"
	elseif self:on_ladder() then
		movement_speed = speed_tweak.CLIMBING_MAX
		speed_state = "climb"
	elseif self._state_data.ducking then
		movement_speed = speed_tweak.CROUCHING_MAX
		speed_state = "crouch"
	elseif self._state_data.in_air then
		movement_speed = speed_tweak.INAIR_MAX
		speed_state = nil
	elseif self._running or force_run then
		movement_speed = speed_tweak.RUNNING_MAX
		speed_state = "run"
	end

	movement_speed = managers.modifiers:modify_value("PlayerStandard:GetMaxWalkSpeed", movement_speed, self._state_data, speed_tweak)
	local morale_boost_bonus = self._ext_movement:morale_boost()
	local multiplier = managers.player:movement_speed_multiplier(speed_state, speed_state and morale_boost_bonus and morale_boost_bonus.move_speed_bonus, nil, self._ext_damage:health_ratio())
	multiplier = multiplier * (self._tweak_data.movement.multiplier[speed_state] or 1) -- fuck with this if 100% movespeed while aiming is required
	local apply_weapon_penalty = true

	if self:_is_meleeing() then
		local melee_entry = managers.blackmarket:equipped_melee_weapon()
		apply_weapon_penalty = not tweak_data.blackmarket.melee_weapons[melee_entry].stats.remove_weapon_movement_penalty
	end

	if alive(self._equipped_unit) and apply_weapon_penalty then
		multiplier = multiplier * self._equipped_unit:base():movement_penalty()
		-- Diesel 3.0 : bonus de vitesse par arme (skills/mods d'arme)
		multiplier = multiplier * managers.player:upgrade_value(self._equipped_unit:base():get_name_id(), "increased_movement_speed", 1)
	end

	if managers.player:has_activate_temporary_upgrade("temporary", "increased_movement_speed") then
		multiplier = multiplier * managers.player:temporary_upgrade_value("temporary", "increased_movement_speed", 1)
	end

	-- Diesel 3.0 : ralentissement Copr quand la vie descend sous le seuil
	if managers.player:has_activate_temporary_upgrade("temporary", "copr_ability") then
		local out_of_health = self._unit:character_damage():health_ratio() + 0.01 < managers.player:upgrade_value("player", "copr_static_damage_ratio", 0)

		if out_of_health then
			multiplier = multiplier * managers.player:upgrade_value("player", "copr_out_of_health_move_slow", 1)
		end
	end

	-- Diesel 3.0 : ralentissement externe (apply_slowdown)
	if self._slowdown_mul then
		multiplier = multiplier * self._slowdown_mul
	end

	local final_speed = movement_speed * multiplier

	self._cached_final_speed = self._cached_final_speed or 0

	if final_speed ~= self._cached_final_speed then
		self._cached_final_speed = final_speed

		self._ext_network:send("action_change_speed", final_speed)
	end

	--log(final_speed)
	return final_speed
end

-- returns normal walkspeed (used to determine speed threshold for beginning a slide)
function PlayerStandard:_get_modified_move_speed(state)
	local speed_tweak = self._tweak_data.movement.speed
	local movement_speed = 0
	local final_speed = 0

	if speed_tweak then
		movement_speed = speed_tweak.STANDARD_MAX
		local speed_state = "walk"

		if state == "crouch" then
			movement_speed = speed_tweak.CROUCHING_MAX
			speed_state = "crouch"
		elseif state == "run" then
			movement_speed = speed_tweak.RUNNING_MAX
			speed_state = "run"
		end

		movement_speed = managers.modifiers:modify_value("PlayerStandard:GetMaxWalkSpeed", movement_speed, self._state_data, speed_tweak)
		local morale_boost_bonus = self._ext_movement:morale_boost()
		local multiplier = managers.player:movement_speed_multiplier(speed_state, speed_state and morale_boost_bonus and morale_boost_bonus.move_speed_bonus, nil, nil)
		multiplier = multiplier * (self._tweak_data.movement.multiplier[speed_state] or 1)

		if alive(self._equipped_unit) then
			multiplier = multiplier * self._equipped_unit:base():movement_penalty()
			-- Diesel 3.0 : meme bonus par arme que _get_max_walk_speed, sinon le
			-- seuil de declenchement du slide ne colle plus a la vitesse reelle.
			multiplier = multiplier * managers.player:upgrade_value(self._equipped_unit:base():get_name_id(), "increased_movement_speed", 1)
		end

		-- Diesel 3.0 : idem pour le ralentissement externe
		if self._slowdown_mul then
			multiplier = multiplier * self._slowdown_mul
		end

		final_speed = movement_speed * multiplier
	end

	return final_speed
end

Hooks:PostHook(PlayerStandard, "_start_action_ducking", "slide_startducking", function(self, params)
	self:_check_slide()
end)

function PlayerStandard:_check_slide()
	if not ((managers.groupai:state():whisper_mode() and AdvMov.settings.slidestealth == 1) or (not managers.groupai:state():whisper_mode() and AdvMov.settings.slideloud == 1)) then
		if self._last_velocity_xy and (self._running or self._state_data.in_air or self._is_wallkicking) then
			-- must be moving at least a certain speed to slide
			local movedir = self._move_dir or self._last_velocity_xy -- don't use self:get_sampled_xy() in any of the other lines in here
			local velocity = Vector3()
			mvector3.set(velocity, self._last_velocity_xy)
			local horizontal_speed = mvector3.normalize(velocity)
			local walkspeed = self:_get_modified_move_speed()
			local slide_cooldown = 1
			if self._slide_dir then
				-- reduce cooldown if not attempting slide in the same direction i.e. do the speedyboi
				local slide_angle = math.atan2(self._slide_dir.y, self._slide_dir.x)
				local move_angle = math.atan2(movedir.y, movedir.x)
				local angle_diff = math.abs(move_angle - slide_angle)
				if angle_diff > 45 then
					slide_cooldown = slide_cooldown / (angle_diff/45)
				end
			end
			if (self._is_wallkicking or (horizontal_speed > (walkspeed * 1.1))) and ((self._last_t - self._last_slide_time) > slide_cooldown) then
				self._is_sliding = true
				self._slide_dir = mvector3.copy(movedir)
				self._slide_slow_add = 0
				self._slide_desired_dir = mvector3.copy(movedir)
				self._sprinting_speed = self:_get_modified_move_speed("run")
				-- make it feel like a speedy slide
				self._slide_speed = self._sprinting_speed * 1.3 --self._tweak_data.movement.speed.RUNNING_MAX * 1.3
				self._slide_refresh_t = 0
				self._slide_last_z = self._unit:position().z
				self._slide_last_speed = self._slide_speed
				self._slide_end_speed = self:_get_modified_move_speed("crouch")/4 -- don't need to calculate every frame
				self._slide_speed_factor = self._slide_speed/(self._tweak_data.movement.speed.RUNNING_MAX * 1.3) -- it's magic
				self:_stance_entered()
--[[
				if not self._state_data.in_air and managers.user:get_setting("use_headbob") then
					self._ext_camera:play_shaker("player_start_running", 1)
					self._slide_has_played_shaker = true
				end
--]]
				self._last_slide_time = self._last_t
				if not self._state_data.in_air then
					self._is_wallkicking = nil
				end
			end
		end
	end
end

Hooks:PostHook(PlayerStandard, "_end_action_ducking", "slide_stopducking", function(self, params)
	self:_cancel_slide()
end)

Hooks:PostHook(PlayerStandard, "_determine_move_direction", "slide_movedir", function(self)
    if self._is_sliding then
		if self._move_dir then
			local slide_angle = math.atan2(self._slide_dir.y, self._slide_dir.x)
			local move_angle = math.atan2(self._move_dir.y, self._move_dir.x)
			-- use difference between slide and move angles to figure out if the player's trying to slow down
			local angle_diff = math.abs(math.abs(move_angle - slide_angle) - 180)
			if angle_diff < 30 then -- less than x degrees from 180 (rear angle)
				self._slide_slow_add = 1600
			elseif angle_diff < 60 then
				self._slide_slow_add = 800
			elseif angle_diff < 90 then
				self._slide_slow_add = 400
			elseif angle_diff < 120 then
				self._slide_slow_add = 200
			else
				self._slide_slow_add = 0
			end

			self._slide_desired_dir = mvector3.copy(self._move_dir)
			mvector3.multiply(self._slide_desired_dir, 0.2) -- level of control over slide direction
		elseif (managers.groupai:state():whisper_mode() and AdvMov.settings.slidestealth == 2) or (not managers.groupai:state():whisper_mode() and AdvMov.settings.slideloud == 2) then
			-- put on the superbrakes
			self._slide_slow_add = 1600
		end
		-- continue moving in slide direction
		self._move_dir = self._slide_dir
	end
	if (self._is_wallkicking or self._is_wallrunning) and not self._is_sliding then
		-- check user input direction to see if we should apply the brakes
		if self._is_wallrunning then
			self._wallrun_slow_add = 0
			if self._move_dir then
				local wallrun_vel = self:_get_sampled_xy()
				local wallrun_angle = math.atan2(wallrun_vel.y, wallrun_vel.x)
				local move_angle = math.atan2(self._move_dir.y, self._move_dir.x)
				local angle_diff = math.abs(math.abs(move_angle - wallrun_angle) - 180)
				-- angle diff is angle away from 180 (rear)
				if angle_diff < 90 then
					self._wallrun_slow_add = 800
				else
					self._wallrun_slow_add = 0
				end
			end
		end
		if self._is_wallkicking and (self._last_zdiff and self._last_zdiff < -0.33) then
			self._last_vault_boost_t = self._last_vault_boost_t or 0
			if self._unit:mover() and ((self._last_t - self._last_wallkick_t) > 0.3) and ((self._last_t - self._last_vault_boost_t) > 0.5) then
				-- small forward boost to vault over walls
				-- only applied if aiming high enough
				local rotation_flat = self._ext_camera:rotation()
				mvector3.set_x(rotation_flat, 0)
				mvector3.set_y(rotation_flat, 0)
				local facing_vec = Vector3(0, 50, 0)
				mvector3.rotate_with(facing_vec, rotation_flat)
				--self._last_velocity_xy = self._last_velocity_xy + facing_vec
				self._unit:mover():set_velocity(self._unit:sampled_velocity() + facing_vec)
				self._last_vault_boost_t = self._last_t
			end
		end
		self._move_dir = nil
	end
end)

Hooks:PostHook(PlayerStandard, "_end_action_ducking", "slide_stopducking", function(self, params)
	self:_cancel_slide()
end)

Hooks:PostHook(PlayerStandard, "_update_movement", "slide_update", function(self, t, dt)
	self:_check_wallkick(t, dt)

	if self._is_sliding then
		if not self._state_data.in_air then
			-- calculate stamina drain scaling based on current speed vs standard running speed
			local drain_mult = self._slide_speed/self._sprinting_speed
			-- drain stamina, prevent regen
			self._unit:movement():subtract_stamina(tweak_data.player.movement_state.stamina.STAMINA_DRAIN_RATE * dt * drain_mult)
			if drain_mult > 0.50 then
				self._unit:movement():_restart_stamina_regen_timer()
			end
		end

		-- slow slide down as it continues
		self._slide_speed = math.clamp(self._slide_speed - ((400 + self._slide_slow_add) * dt * self._slide_speed_factor^2), 0, 1500)

		local last_refresh_dt = t - self._slide_refresh_t
		if self._slide_refresh_t and last_refresh_dt > 0.1 then

			if not self._state_data.in_air and (t - self._last_jump_t) > 0.20 then
				-- play slide-start stuff
				if not self._slide_has_played_shaker then
					if managers.user:get_setting("use_headbob") then
						self._ext_camera:play_shaker("player_start_running", 1)
					end
					self._slide_has_played_shaker = true
					if self._using_superblt then
						local choice = math.random(1, 2)
						self._inf_sound:post_event("slide_enter" .. choice)
					end
				end
				-- slide loops n shit
				if (t - self._last_snd_slide_t) > 0.20 then
					self._last_snd_slide_t = t
					self._last_snd_slide = self._last_snd_slide or 0
					self._last_snd_slide = (self._last_snd_slide % 6) + 1
					local pitch = ""
					if self._last_speed > (self._slide_end_speed * 5) then
						pitch = ""
					elseif self._last_speed > (self._slide_end_speed * 3) then
						pitch = "slow"
					elseif self._last_speed > (self._slide_end_speed * 2) then
						pitch = "slower"
					else
						pitch = "slowest"
					end
					if self._using_superblt then
						self._inf_sound:post_event("slide_loop" .. self._last_snd_slide .. pitch)
					end
				end
			end

			-- change speed depending on change in z position
			local current_z = self._unit:position().z
			local downspeed = self._slide_last_z - current_z
			-- prevent massive bullshit accelerations from wallkick elevation converting to speed
			if ((t - self._last_wallkick_t) > 0.3) then
				self._slide_speed = self._slide_speed + (downspeed * 10 * last_refresh_dt * self._slide_speed_factor^2)
			end
			self._slide_refresh_t = t
			self._slide_last_z = current_z

			-- apply change of direction
			if self._move_dir then
				mvector3.add(self._slide_dir, self._slide_desired_dir)
				mvector3.normalize(self._slide_dir) -- normalize or the gun goes shakey shakey
			end
		end
		-- kick fools
		if ((t - self._last_movekick_enemy_t) > 0.5) then
			local has_kicked = self:_do_movement_melee_damage(nil, self._is_wallkicking) -- do it really hard if you're still in midair
			if has_kicked then
				self._last_movekick_enemy_t = t
			end
		end

		-- update last known speed
--[[
		local vel = Vector3()
		mvector3.set(vel, self._last_velocity_xy)
		self._slide_last_speed = mvector3.normalize(vel)
--]]

		-- end slide if too slow
		-- grace period for wallkicking to prevent slide from failing because it's detecting a low pre-kick-acceleration speed
		if self._last_speed < (self._slide_end_speed) and ((t - self._last_wallkick_t) > 0.3) then
			self:_cancel_slide(3)
		end
	elseif self._is_wallkicking or self._is_dashing then
		-- coming in from that wallkick
		if not self._state_data.in_air then
			self._is_wallkicking = nil
		end
		if ((t - self._last_movekick_enemy_t) > 0.5) then
			local has_kicked = self:_do_movement_melee_damage(nil, self._is_wallkicking) -- megakick if wallkicking
			if has_kicked then
				self._last_movekick_enemy_t = t
			end
		end
		-- transition to slide bby
		if self._state_data.ducking then
			self:_check_slide()
		end
	elseif self._running and (AdvMov.settings.runkick == true or self._state_data.in_air) then
		-- sprinting
		if ((t - self._last_movekick_enemy_t) > 0.5) then
			local has_kicked = self:_do_movement_melee_damage(true, nil)
			if has_kicked then
				self._last_movekick_enemy_t = t
			end
		end
	end
end)

Hooks:PostHook(PlayerStandard, "_update_movement", "check_wallrun_update", function(self, t, dt)
	local tapping_sprint = self._controller:get_input_pressed("run")
	-- relaxed wallrun conditions to enable jump maps
	-- allow wallrunning while bouncing from wall to wall without explicitly enabling 
	local wallkick_off_cooldown = (self._is_wallkicking and ((t - self._last_wallkick_t) > 0.2))
	local dmgkick_off_cooldown = ((t - self._last_movekick_enemy_t) > 1)
	local holding_jump = self._controller:get_input_bool("jump")
	if not holding_jump and self._state_data.in_air and (tapping_sprint or wallkick_off_cooldown) and dmgkick_off_cooldown and mvector3.normalize(self:_get_sampled_xy()) > 0 then
		-- reduce cooldown if hitting a different wall
		local lenghtmult = 1
		if wallkick_off_cooldown then
			lengthmult = 1.5
		end
		local nearest_ray1 = self:_get_nearest_wall_ray_dir(lenghtmult, nil, nil, 0)
		local nearest_ray2 = self:_get_nearest_wall_ray_dir(lenghtmult, nil, nil, 40)
		local nearest_ray = nearest_ray1 or nearest_ray2
		if nearest_ray and self._last_wallrun_dir then
			local last_angle = math.atan2(self._last_wallrun_dir.y, self._last_wallrun_dir.x)
			local current_angle = math.atan2(nearest_ray.dir.y, nearest_ray.dir.x)
			local angle_diff = 180 - math.abs(((last_angle - current_angle) % 360) - 180)
			if angle_diff < 45 then
				self._new_wallrun_delay = 1.0
				if self._last_zdiff and self._last_zdiff < -0.25 then
					-- prevent wallrun from catching on the wall you just tried to jump up
					-- positive zdiff = downwards
					self._new_wallrun_delay = self._new_wallrun_delay * 3
				end
			else
				self._new_wallrun_delay = 0
			end
		end
		local wallrun_on_cooldown = (t - self._last_wallrun_t) < (self._new_wallrun_delay or 0)
		if not self._is_wallrunning and not wallrun_on_cooldown and self._unit:movement():is_above_stamina_threshold() and not self:on_ladder() and nearest_ray then
			self._sprinting_speed = self:_get_modified_move_speed("run")
			self._wallrun_speed = self._sprinting_speed * 1.5
			self._wallrun_last_speed = self._wallrun_speed
			self._wallrun_end_speed = self:_get_modified_move_speed("crouch")
			self._wallrun_speed_factor = self._wallrun_speed/(self._tweak_data.movement.speed.RUNNING_MAX * 1.3)
			self._is_wallrunning = true
			self:_stance_entered()
			if self._unit:mover() then
				--log("starting wallrun")
				local sampled_xy = mvector3.copy(self:_get_sampled_xy())
				mvector3.normalize(sampled_xy)
				mvector3.multiply(sampled_xy, self._wallrun_last_speed)
				self._unit:mover():set_gravity(Vector3(0, 0, 0))
				self._unit:mover():set_velocity(sampled_xy)
			end
			self._last_wallrun_dir = nearest_ray.dir
		end
	end

	if self._is_wallrunning then
		-- drain stamina, prevent regen
		self._unit:movement():subtract_stamina(tweak_data.player.movement_state.stamina.STAMINA_DRAIN_RATE * dt * (self._wallrun_last_speed/self._sprinting_speed))
			self._unit:movement():_restart_stamina_regen_timer()

		-- keep pushing player along the wall
		if self._unit:mover() then
			local sampled_xy = mvector3.copy(self:_get_sampled_xy())
			mvector3.normalize(sampled_xy)
			mvector3.multiply(sampled_xy, self._wallrun_last_speed)
			self._unit:mover():set_velocity(sampled_xy)
		end

		-- slow wallrun down as it continues
		self._wallrun_last_speed = math.clamp(self._wallrun_last_speed - ((300 + (self._wallrun_slow_add or 0)) * dt * self._wallrun_speed_factor^2), 0, 1500)
		if self._wallrun_last_speed < self._wallrun_end_speed then
			self:_cancel_wallrun(t, "fall", 3)
			--log("ending wallrun: too slow")
		end
--[[
		if not self._state_data.in_air then
			self:_cancel_wallrun(t)
			--log("ending wallrun: hit ground")
		end
--]]
		if (t - self._last_wallrun_t > 0.1) then
			self._last_wallrun_t = t
			if self:on_ladder() or not self:_get_nearest_wall_ray_dir(1.5) then
				self._end_wallrun_kick_dir = self:_get_end_wallrun_kick_dir()
				self:_cancel_wallrun(t, fall)
				--log("ending wallrun: failed to detect wall")
			end
		end
	end
end)


function PlayerStandard:_check_action_jump(t, input)
	local new_action = nil
	local action_wanted = input.btn_jump_press

	-- kick off with force if jumping from wallrun
	if self._is_wallrunning and action_wanted then
--[[
		--log("ending wallrun: jumped")
		-- put wallhang on cooldown
--]]
		self:_cancel_wallrun(t, "jump")
	elseif action_wanted then
		local action_forbidden = self._jump_t and t < self._jump_t + 0.55
		action_forbidden = action_forbidden or self._unit:base():stats_screen_visible() or self._state_data.in_air or self:_interacting() or self:_on_zipline() or self:_does_deploying_limit_movement() or self:_is_using_bipod()

		if not action_forbidden then
			-- don't check for ducking anymore
			if self._state_data.on_ladder then
				self:_interupt_action_ladder(t)
			end

			local action_start_data = {}
			local jump_vel_z = tweak_data.player.movement_state.standard.movement.jump_velocity.z
			action_start_data.jump_vel_z = jump_vel_z

			if self._move_dir then
				local is_running = self._running and self._unit:movement():is_above_stamina_threshold() and t - self._start_running_t > 0.4
				local jump_vel_xy = tweak_data.player.movement_state.standard.movement.jump_velocity.xy[is_running and "run" or "walk"]
				action_start_data.jump_vel_xy = jump_vel_xy

				if is_running then
					self._unit:movement():subtract_stamina(tweak_data.player.movement_state.stamina.JUMP_STAMINA_DRAIN)
				end
			end

			--self._slide_has_played_shaker = nil -- play shaker again after landing
			new_action = self:_start_action_jump(t, action_start_data)
		end
	end

	return new_action
end

function PlayerStandard:_cancel_slide(timemult)
	self._is_sliding = nil
	self._slide_has_played_shaker = nil
	self:_stance_entered(nil, timemult)
end

Hooks:PostHook(PlayerStandard, "enter", "reset_advmov_enter", function(self, params)
	self:_cancel_slide()
	self._slide_end_speed = self:_get_modified_move_speed("crouch")/4 -- don't need to calculate every frame

	self._last_snd_slide_t = 0
	self._last_jump_t = 0

	self._last_slide_time = 0
	self._last_wallrun_t = 0
	self._is_wallkicking = nil
	self._wallkick_is_clinging = nil
	self._wallkick_hold_start_t = nil
	self._last_wallkick_t = 0
	self._last_movekick_enemy_t = 0
end)

Hooks:PostHook(PlayerStandard, "init", "reset_advmov_init", function(self, params)
	self._last_snd_slide_t = 0
	self._last_jump_t = 0

	self._last_slide_time = 0
	self._last_wallrun_t = 0
	self._is_wallkicking = nil
	self._wallkick_is_clinging = nil
	self._wallkick_hold_start_t = nil
	self._last_wallkick_t = 0
	self._last_movekick_enemy_t = 0

	if blt and blt.xaudio then
		self._using_superblt = true
	end
	if self._using_superblt then
		self._inf_sound = SoundDevice:create_source("inf_sounds")
		--self._inf_sound:set_position(managers.player:player_unit():position())
	end
end)


function PlayerStandard:_check_step(t)
	-- don't make footstep noises while sliding
	-- but do make footstep noises while wallrunning
	if (self._state_data.in_air and not self._is_wallrunning) or self._is_sliding then
		return
	end

	self._last_step_pos = self._last_step_pos or Vector3()
	local step_length = self._state_data.on_ladder and 50 or self._state_data.in_steelsight and (managers.player:has_category_upgrade("player", "steelsight_normal_movement_speed") and 150 or 100) or self._state_data.ducking and 125 or self._running and 175 or 150

	if mvector3.distance_sq(self._last_step_pos, self._pos) > step_length * step_length then
		mvector3.set(self._last_step_pos, self._pos)
		self._unit:base():anim_data_clbk_footstep()
	end
end





-- lets me quickly adjust how far the detection rays should go
local wallslide_values = {60} -- minimum of 50-51?
wallslide_values[2] = wallslide_values[1] * 0.707 -- sin 45
wallslide_values[3] = wallslide_values[1] * 0.924 -- cos 22.5/sin 67.5
wallslide_values[4] = wallslide_values[1] * 0.383 -- sin 22.5/cos 67.5

--[[
function PlayerStandard:_check_wallrun_rays(all_directions)
	local playerpos = managers.player:player_unit():position()
	-- only get one axis of rotation so facing up doesn't end the wallrun via not detecting a wall to run on
	local rotation_flat = self._ext_camera:rotation()
	mvector3.set_x(rotation_flat, 0)
	mvector3.set_y(rotation_flat, 0)

	local ray_left = Vector3()
	mvector3.set(ray_left, playerpos)
	local ray_left_adjust = Vector3(-1 * wallslide_values[1], 0, 0)
	mvector3.rotate_with(ray_left_adjust, rotation_flat)
	mvector3.add(ray_left, ray_left_adjust)
	local left_check = Utils:GetCrosshairRay(playerpos, ray_left)

	local ray_right = Vector3()
	mvector3.set(ray_right, playerpos)
	local ray_right_adjust = Vector3(wallslide_values[1], 0, 0)
	mvector3.rotate_with(ray_right_adjust, rotation_flat)
	mvector3.add(ray_right, ray_right_adjust)
	local right_check = Utils:GetCrosshairRay(playerpos, ray_right)

	local ray_forward = nil
	local ray_back = nil

	if all_directions then
		ray_forward = Vector3()
		mvector3.set(ray_forward, managers.player:player_unit():position())
		local ray_forward_adjust = Vector3(0, wallslide_values[1], 0)
		mvector3.rotate_with(ray_forward_adjust, rotation_flat)
		mvector3.add(ray_forward, ray_forward_adjust)
		forward_check = Utils:GetCrosshairRay(playerpos, ray_forward)

		ray_back = Vector3()
		mvector3.set(ray_back, managers.player:player_unit():position())
		local ray_back_adjust = Vector3(0, -1 * wallslide_values[1], 0)
		mvector3.rotate_with(ray_back_adjust, rotation_flat)
		mvector3.add(ray_back, ray_back_adjust)
		back_check = Utils:GetCrosshairRay(playerpos, ray_back)
	end

	return (left_check or right_check or forward_check or back_check)
end
--]]

function PlayerStandard:_get_end_wallrun_kick_dir(mult)
	local magnitude = mult or 20 

	-- have a slight kick-off so you don't look like you're just sliding down a window pane
	local shortest_ray_dir = self:_get_nearest_wall_ray_dir(2)

	-- make it point the other way
	local final_vector = Vector3(0, 0, 0)
	if shortest_ray_dir and shortest_ray_dir.dir then
		mvector3.set(final_vector, shortest_ray_dir.dir)
	end
	final_vector = self:_reverse_vector(final_vector)
	mvector3.normalize(final_vector)
	mvector3.multiply(final_vector, magnitude)

	return final_vector
end

function PlayerStandard:_reverse_vector(vector)
	local new_vector = Vector3(0, 0, 0)
	mvector3.subtract(new_vector, vector)
	return new_vector
end

function PlayerStandard:_get_nearest_wall_ray_dir(ray_length_mult, raytarget, only_frontal_rays, z_offset)
	local length_mult = ray_length_mult or 1
	local playerpos = managers.player:player_unit():position()
	if z_offset then
		mvector3.add(playerpos, Vector3(0, 0, z_offset))
	end
	-- only get one axis of rotation so facing up doesn't end the wallrun via not detecting a wall to run on
	local rotation = self._ext_camera:rotation()
	mvector3.set_x(rotation, 0)
	mvector3.set_y(rotation, 0)
	local shortest_ray_dist = 10000
	local shortest_ray_dir = nil
	local shortest_ray = nil
	local first_ray_dist = 10000
	local first_ray_dir = nil
	local first_ray = nil

	-- alternate table to check more than cardinal and intercardinal directions
	local ray_adjust_table = nil
	if not self._nearest_wall_ray_dir_state then
		self._nearest_wall_ray_dir_state = true
		ray_adjust_table = {
			{-1 * wallslide_values[2], wallslide_values[2]}, -- 315, forward-left
			{0, wallslide_values[1]}, -- 360/0, forward
			{wallslide_values[2], wallslide_values[2]}, -- 45, forward-right
			{wallslide_values[1], 0}, -- 90, right
			{wallslide_values[2], -1 * wallslide_values[2]}, -- 135, back-right
			{0, -1 * wallslide_values[1]}, -- 180, back
			{-1 * wallslide_values[2], -1 * wallslide_values[2]}, -- 225, back-left
			{-1 * wallslide_values[1], 0} -- 270, left
		}
		if only_frontal_rays then
			ray_adjust_table[4] = nil
			ray_adjust_table[5] = nil
			ray_adjust_table[6] = nil
			ray_adjust_table[7] = nil
			ray_adjust_table[8] = nil
		end
	else
		self._nearest_wall_ray_dir_state = nil
		ray_adjust_table = {
			{-1 * wallslide_values[4], wallslide_values[3]}, -- 292.5
			{-1 * wallslide_values[3], wallslide_values[4]}, -- 337.5
			{wallslide_values[3], wallslide_values[4]}, -- 22.5
			{wallslide_values[4], wallslide_values[3]}, -- 67.5
			{wallslide_values[4], -1 * wallslide_values[3]}, -- 112.5
			{wallslide_values[3], -1 * wallslide_values[4]}, -- 157.5
			{-1 * wallslide_values[3], -1 * wallslide_values[4]}, -- 202.5
			{-1 * wallslide_values[4], -1 * wallslide_values[3]} -- 247.5
		}
		if only_frontal_rays then
			--ray_adjust_table[4] = nil
			ray_adjust_table[5] = nil
			ray_adjust_table[6] = nil
			ray_adjust_table[7] = nil
			ray_adjust_table[8] = nil
		end
	end

	for i = 1, #ray_adjust_table do
		local ray = Vector3()
		mvector3.set(ray, playerpos)
		local ray_adjust = Vector3(ray_adjust_table[i][1] * length_mult, ray_adjust_table[i][2] * length_mult, 0)
		mvector3.rotate_with(ray_adjust, rotation)
		mvector3.add(ray, ray_adjust)
		local ray_check = Utils:GetCrosshairRay(playerpos, ray)
		if ray_check and (shortest_ray_dist > ray_check.distance) then
			-- husks use different data reee
			local is_enemy = managers.enemy:is_enemy(ray_check.unit) and ray_check.unit:brain():is_hostile() -- exclude sentries
			local is_shield = ray_check.unit:in_slot(8) and alive(ray_check.unit:parent())
			local enemy_not_surrendered = is_enemy and ray_check.unit:brain() and not (ray_check.unit:brain()._surrendered or ray_check.unit:brain():surrendered())
			local enemy_not_joker = is_enemy and ray_check.unit:brain() and not (ray_check.unit:brain()._converted or (ray_check.unit:brain()._logic_data and ray_check.unit:brain()._logic_data.is_converted))
			local enemy_not_trading = is_enemy and ray_check.unit:brain() and not (ray_check.unit:brain()._logic_data and ray_check.unit:brain()._logic_data.name == "trade") -- i don't know how to check for trading on husk
			if raytarget == "enemy" and ((is_enemy and enemy_not_surrendered and enemy_not_joker and enemy_not_trading) or is_shield) then
				shortest_ray_dist = ray_check.distance
				shortest_ray_dir = ray_adjust
				shortest_ray = ray_check
			elseif raytarget == "breakable" and ray_check.unit:damage() and not ray_check.unit:character_damage() then
				shortest_ray_dist = ray_check.distance
				shortest_ray_dir = ray_adjust
				shortest_ray = ray_check
			elseif not raytarget then
				shortest_ray_dist = ray_check.distance
				shortest_ray_dir = ray_adjust
				shortest_ray = ray_check
			end
		end
	end

	if shortest_ray_dist == 10000 then
		return nil
	else
		return {dir = shortest_ray_dir, raydata = shortest_ray}
	end
end


function PlayerStandard:_cancel_wallrun(t, kick_off_mode, timemult)
	local exit_wallrun_vel = Vector3()
	if self._unit:mover() and self._end_wallrun_kick_dir and kick_off_mode == "fall" then
		mvector3.add(exit_wallrun_vel, self._end_wallrun_kick_dir)
		self._unit:mover():set_velocity(exit_wallrun_vel)
	end

	if self._unit:mover() then
		self._unit:mover():set_gravity(Vector3(0, 0, -982))
	end

	if kick_off_mode == "jump" then
--[[
		local speed = self:_get_modified_move_speed("run")
		local kick_dir = Vector3(0, speed, 0)
		local rotation = self._ext_camera:rotation()
		mvector3.set_x(rotation, 0)
		mvector3.set_y(rotation, 0)
		--mvector3.set_z(rotation, 0)
		mvector3.rotate_with(kick_dir, rotation)
		-- mvector3.rotate_with(kick_dir, self._ext_camera:rotation())
		mvector3.add(exit_wallrun_vel, kick_dir)
		mvector3.add(exit_wallrun_vel, Vector3(0, 0, tweak_data.player.movement_state.standard.movement.jump_velocity.z))
--]]
		self:_do_wallkick()
	end

	self._is_wallrunning = nil
	self._last_wallrun_t = t
	self._last_wallkick_t = t
	self:_stance_entered(nil, timemult)
end

function PlayerStandard:_get_sampled_xy()
	--local vel = Vector3()
	--mvector3.set(vel, self._unit:sampled_velocity())
	local vel = mvector3.copy(self._unit:sampled_velocity())
	mvector3.set_z(vel, 0)
	return vel
end

function PlayerStandard:_do_wallkick()
	-- ending wallhang by wallkicking
	-- kick off of wall in the direction you're facing
	local fast_kickoff = false
	local final_vel = Vector3(0, 0, 0)
	--local nearest_wall_ray = self:_get_nearest_wall_ray_dir(2) -- extra long or the player can end up floating instead of wallkicking because the nearest wall isn't detected
	local nearest_ray1 = self:_get_nearest_wall_ray_dir(2, nil, nil, 0)
	local nearest_ray2 = self:_get_nearest_wall_ray_dir(2, nil, nil, 40)
	local nearest_wall_ray = nearest_ray1 or nearest_ray2
	local speed = self:_get_modified_move_speed("run")
	local kick_dir = Vector3(0, speed * 1.5, 0)
	local rotation = managers.player:equipped_weapon_unit():rotation()
	local rotation_flat = self._ext_camera:rotation()
	mvector3.set_x(rotation_flat, 0)
	mvector3.set_y(rotation_flat, 0)

	-- i have no idea how to read from rotations so you get this instead
	-- actual facing with vertical component
	local facing_vec = Vector3(0, 1, 0)
	mvector3.rotate_with(facing_vec, rotation)
	-- same xy direction, no elevation
	local forward_vec = Vector3(0, 1, 0)
	mvector3.rotate_with(forward_vec, rotation_flat)
	-- get difference to determine if player is facing over or under horizon
	local zdiff = forward_vec.z - facing_vec.z
	if true then --zdiff > 0 then
		fast_kickoff = true
	end

	if nearest_wall_ray and nearest_wall_ray.dir then
		self._last_wallrun_dir = nearest_wall_ray.dir
		--if fast_kickoff then
			-- 'fast' wallkick
			-- kick in direction player is facing
			--mvector3.multiply(kick_dir, 1.35) -- this mattered when fast/slow wallkicks were separate
			mvector3.rotate_with(kick_dir, rotation)
			mvector3.add(final_vel, kick_dir)

			-- vertical boost so you don't automatically fly into the ground regardless of trajectory
			mvector3.add(final_vel, Vector3(0, 0, 300 + (300 * zdiff)))

			-- vertical reduction if aiming upwards so you can't leap over houses in a single bound or some shit
			if zdiff < 0 then
				mvector3.add(final_vel, Vector3(0, 0, speed * zdiff * 0.5))
			end

			if self._unit:mover() then
				self._unit:mover():set_velocity(final_vel)
				self._unit:mover():set_gravity(Vector3(0, 0, -982))
			end

			self._last_zdiff = zdiff
--[[
		else
			-- 'slow' wallkick
			-- only apply horizontal direction
			mvector3.rotate_with(kick_dir, rotation_flat)
			mvector3.add(final_vel, kick_dir)

			-- scale jump value down if aiming too close to nearest wall
			local jump_amount = tweak_data.player.movement_state.standard.movement.jump_velocity.z
			local kick_angle = math.atan2(kick_dir.y, kick_dir.x)
			local wall_angle = math.atan2(nearest_wall_ray.dir.y, nearest_wall_ray.dir.x)
			-- the math continues to drive me up the wall
			local angle_diff = 180 - math.abs(((kick_angle - wall_angle) % 360) - 180)
			if angle_diff < 120 then
				jump_amount = (jump_amount*angle_diff)/120
			end
			mvector3.add(final_vel, Vector3(0, 0, jump_amount * 0.50))
		end

		if self._unit:mover() then
			self._unit:mover():set_velocity(final_vel)
			self._unit:mover():set_gravity(Vector3(0, 0, -982))
		end
--]]
	end

	if self._using_superblt then
		self._inf_sound:post_event("kick_off")
	else
		self._unit:sound():_play("footstep_land")
	end
	self._unit:movement():subtract_stamina(tweak_data.player.movement_state.stamina.JUMP_STAMINA_DRAIN)
	self._unit:movement():_restart_stamina_regen_timer()
	self._is_wallkicking = true
end

function PlayerStandard:_check_wallkick(t, dt)
	if ((t - self._last_wallkick_t) > 1.0) or self._is_wallkicking then
		local action_wanted = self._controller:get_input_bool("jump")
		local ads_mult = 1
		if self:in_steelsight() then
			ads_mult = 0.25
		end

		if action_wanted and self._state_data.in_air then
			local nearest_ray = self:_get_nearest_wall_ray_dir()

			-- check if wall angle is too close to the last one to prevent chain-jumping across single flat walls
			-- if you're gonna break a map you gotta at least earn it with some sick zig-zag hopping
			if nearest_ray and self._last_wallkick_dir then
				local last_angle = math.atan2(self._last_wallkick_dir.y, self._last_wallkick_dir.x)
				local current_angle = math.atan2(nearest_ray.dir.y, nearest_ray.dir.x)
				local angle_diff = 180 - math.abs(((last_angle - current_angle) % 360) - 180)
				if angle_diff < 45 then
					self._new_wallhang_delay = 0.75
				else
					self._new_wallhang_delay = 0
				end
			end
			local wallkick_on_cooldown = (self._is_wallkicking and (t - self._last_wallkick_t) < 0.25 + (self._new_wallhang_delay or 0))

			if not self._wallkick_hold_start_t then
				-- check if holding jump for long enough to cling (don't have to be touching wall yet, just prevent cases of clinging to things you're trying to jump on top of)
				self._wallkick_hold_start_t = t
			elseif self._wallkick_is_clinging and ((t - self._wallkick_hold_start_t) > 6) then
				-- slide down at full speed w/o ADS slowdown
				if self._unit:mover() then
					self._unit:mover():set_gravity(Vector3(0, 0, -982))
				end
				self._wallkick_is_clinging = nil
			elseif self._wallkick_is_clinging and ((t - self._wallkick_hold_start_t) > 4) then
				-- slide down at full speed w/ADS slowdown
				if self._unit:mover() then
					self._unit:mover():set_gravity(Vector3(0, 0, -550 * ads_mult))
				end
			elseif self._wallkick_is_clinging and ((t - self._wallkick_hold_start_t) > 2) then
				-- slide down at full speed w/ADS slowdown
				if self._unit:mover() then
					self._unit:mover():set_gravity(Vector3(0, 0, -300 * ads_mult))
				end
			elseif self._wallkick_is_clinging and ((t - self._wallkick_hold_start_t) > 0.3) then
				-- slide down wall very slowly while clinging
				if self._unit:mover() then
					self._unit:mover():set_gravity(Vector3(0, 0, -150 * ads_mult))
				end
			elseif ((t - self._wallkick_hold_start_t) > 0.15 or self._is_wallrunning) and not self._wallkick_is_clinging then
				if not wallkick_on_cooldown and nearest_ray and nearest_ray.raydata and nearest_ray.raydata.unit and not managers.enemy:is_enemy(nearest_ray.raydata.unit) and not nearest_ray.raydata.unit:in_slot(8) then
					-- cling to wall
					-- cancel out remaining vertical velocity since we're literally disabling the player's gravity
					if self._unit:mover() then
						self._unit:mover():set_gravity(Vector3(0, 0, 0))
						self._unit:mover():set_velocity(Vector3(0, 0, 0))
					end
					mvector3.multiply(self._last_velocity_xy, 0.05)
					mvector3.set_z(self._last_velocity_xy, 0)
					self._wallkick_is_clinging = true

					-- set last wall dir
					self._last_wallkick_dir = nearest_ray.dir
				end
			end
		end

		-- end wallhang if not holding jump or has landed
		if not action_wanted or not self._state_data.in_air then
			if self._wallkick_is_clinging and self._state_data.in_air and self._unit:movement():is_above_stamina_threshold() then
--[[
				-- ending wallhang by wallkicking
				-- kick off of wall in the direction you're facing
				local fast_kickoff = false
				local final_vel = Vector3(0, 0, 0)
				local nearest_wall_ray = self:_get_nearest_wall_ray_dir(2) -- extra long or the player can end up floating instead of wallkicking because the nearest wall isn't detected
				local speed = self:_get_modified_move_speed("run")
				local kick_dir = Vector3(0, speed * 1.50, 0)
				local rotation = self._ext_camera:rotation()
				local rotation_flat = self._ext_camera:rotation()
				mvector3.set_x(rotation_flat, 0)
				mvector3.set_y(rotation_flat, 0)

				-- i have no idea how to read from rotations so you get this instead
				-- actual facing with vertical component
				local facing_vec = Vector3(0, 1, 0)
				mvector3.rotate_with(facing_vec, rotation)
				-- same xy direction, no elevation
				local forward_vec = Vector3(0, 1, 0)
				mvector3.rotate_with(forward_vec, rotation_flat)
				-- get difference to determine if player is facing over or under horizon
				--log(forward_vec.z - facing_vec.z)
				if (forward_vec.z - facing_vec.z) > 0 then
					fast_kickoff = true
				end

				if nearest_wall_ray and nearest_wall_ray.dir then
					if fast_kickoff then
						-- kick in direction player is facing
						mvector3.multiply(kick_dir, 1.50)
						mvector3.rotate_with(kick_dir, rotation)
						mvector3.add(final_vel, kick_dir)

						-- vertical boost so you don't automatically fly into the ground regardless of trajectory
						mvector3.add(final_vel, Vector3(0, 0, 200))

						if self._unit:mover() then
							self._unit:mover():set_velocity(final_vel)
							self._unit:mover():set_gravity(Vector3(0, 0, -982))
						end
					else
						-- only apply horizontal direction
						mvector3.rotate_with(kick_dir, rotation_flat)
						mvector3.add(final_vel, kick_dir)

						-- scale jump value down if aiming too close to nearest wall
						local jump_amount = tweak_data.player.movement_state.standard.movement.jump_velocity.z
						local kick_angle = math.atan2(kick_dir.y, kick_dir.x)
						local wall_angle = math.atan2(nearest_wall_ray.dir.y, nearest_wall_ray.dir.x)
						-- the math continues to drive me up the wall
						local angle_diff = 180 - math.abs(((kick_angle - wall_angle) % 360) - 180)
						if angle_diff < 120 then
							jump_amount = (jump_amount*angle_diff)/120
						end
						mvector3.add(final_vel, Vector3(0, 0, jump_amount * 0.50))
					end

					if self._unit:mover() then
						self._unit:mover():set_velocity(final_vel)
						self._unit:mover():set_gravity(Vector3(0, 0, -982))
					end
				end
--]]
				self:_do_wallkick()

				-- put wallrun on cooldown
				self._last_wallrun_t = t
				self._is_wallkicking = true
				self._wallkick_is_clinging = nil
				self._wallkick_hold_start_t = nil
				self._last_wallkick_t = t
			else
				-- ending wallhang by landing
				self._wallkick_hold_start_t = nil
				self._wallkick_is_clinging = nil
				if self._unit:mover() and not self._state_data.on_ladder and not self._is_wallrunning then -- zipline don't have no mover lmao
					self._unit:mover():set_gravity(Vector3(0, 0, -982))
				end
			end
		end
	end
end

-- DON'T FORGET TO CHANGE THE INFMENU TO ADVMOV WHEN COPYING CHANGES OVER DOOFUS
function PlayerStandard:_do_movement_melee_damage(forward_only, strongkick)
	local enemy_ray1 = self:_get_nearest_wall_ray_dir(2, "enemy", forward_only, nil)
	local enemy_ray2 = self:_get_nearest_wall_ray_dir(2, "enemy", forward_only, 70)
	local enemy_ray = enemy_ray1 or enemy_ray2

	local breakable_ray1 = nil
	local breakable_ray2 = nil
	if not enemy_ray then
		breakable_ray1 = self:_get_nearest_wall_ray_dir(1, "breakable", forward_only)
		breakable_ray2 = self:_get_nearest_wall_ray_dir(1, "breakable", forward_only, 70)
	end
	local breakable_ray = breakable_ray1 or breakable_ray2

	if enemy_ray or breakable_ray then
		local target_ray_data = enemy_ray or breakable_ray
		local targetunit = target_ray_data.raydata.unit

		-- kick away if hitting an enemy/shield
		local finaltarget = targetunit
		if enemy_ray then
			local speed = self:_get_modified_move_speed("run")
			local kick_dir = target_ray_data.dir
			kick_dir = self:_reverse_vector(kick_dir)
			mvector3.normalize(kick_dir)
			mvector3.multiply(kick_dir, speed * 0.50)
			local jump_amount = tweak_data.player.movement_state.standard.movement.jump_velocity.z
			mvector3.add(kick_dir, Vector3(0, 0, jump_amount * 0.25))
			if self._unit:mover() then
				self._unit:mover():set_velocity(kick_dir)
			end
			local hit_sfx = "hit_body"
			if finaltarget:character_damage() and finaltarget:character_damage().melee_hit_sfx then
				hit_sfx = finaltarget:character_damage():melee_hit_sfx()
			end
			if self._using_superblt then
				if strongkick then
					self._inf_sound:post_event("kick_heavy")
				else
					self._inf_sound:post_event("kick_light")
				end
			else
				self:_play_melee_sound("fists", hit_sfx, 0)
				--self:_play_melee_sound("fists", "hit_gen", 0)
			end

			self._unit:movement():subtract_stamina(tweak_data.player.movement_state.stamina.JUMP_STAMINA_DRAIN * 0.5)
			self._unit:movement():_restart_stamina_regen_timer()
		end

		self._wallkick_hold_start_t = nil

		local can_shield_knock = managers.player:has_category_upgrade("player", "shield_knock") or not target_ray_data.raydata.unit:in_slot(8) -- can hit shields in the back
		local dmg_data = {
			damage = 5.0,
			damage_effect = 50.0,
			attacker_unit = self._unit,
			col_ray = target_ray_data.raydata,
			name_id = "wallkick",
			charge_lerp_value = 0,
			shield_knock = can_shield_knock			
		}
		-- this goes here so i can just copy paste this to standalone without manually changing values
		if BeardLib and not BeardLib.Utils:FindMod("irenfist") then
			dmg_data.damage = 18.0
			dmg_data.damage_effect = 200.0
		end
		if targetunit:in_slot(8) and alive(targetunit:parent()) and not targetunit:parent():character_damage():is_immune_to_shield_knockback() then
			-- shield behaviors
			dmg_data.damage = 0
			finaltarget = targetunit:parent()
		end
		if finaltarget and finaltarget:character_damage() and finaltarget:character_damage().damage_melee and dmg_data then -- blanket "what the fuck is crashing" prevention since i don't know how to reproduce it consistently
			local atk_dir_z_offset = -100
			local is_bulldozer = finaltarget:base():has_tag("tank")
			if strongkick and not is_bulldozer then
				dmg_data.damage = dmg_data.damage * 2
				dmg_data.variant = "counter_spooc"
				atk_dir_z_offset = atk_dir_z_offset * 2
			end
			-- hit enemy
			-- apply damage
			finaltarget:character_damage():damage_melee(dmg_data)
			self:_perform_sync_melee_damage(finaltarget, target_ray_data.raydata, dmg_data.damage)
			-- push corpse around
			-- don't push live targets, they'll ragdoll
			if finaltarget:character_damage()._health <= 0 then
				local hit_pos = mvector3.copy(finaltarget:movement():m_pos())
				local attack_dir = hit_pos - self._unit:movement():m_head_pos() - Vector3(0, 0, atk_dir_z_offset)
				local distance = mvector3.normalize(attack_dir)
				-- attack dir also controls how ridiculous the ragdoll push is
				-- Vector3(0, 0, 1) bounces directly upwards
				local magnitude = 1
				if strongkick then
					magnitude = 1.5
				end
				if AdvMov.settings.kickyeet then
					magnitude = magnitude * AdvMov.settings.kickyeet
				end
				mvector3.multiply(attack_dir, magnitude)
				managers.game_play_central:do_shotgun_push(finaltarget, target_ray_data.raydata.hit_position, attack_dir, distance)
			end
			self:_cancel_slide()
			self._ext_camera:play_shaker("player_start_running", 1)
		elseif finaltarget and not finaltarget:character_damage() and finaltarget:damage() and dmg_data then
			-- hit object
			-- core\lib\units\coreunitdamage.lua
			-- observe as exactly one argument is used
			if not managers.groupai:state():whisper_mode() then
				finaltarget:damage():add_damage(nil, nil, nil, nil, nil, nil, dmg_data.damage, nil, nil)
				self:_perform_sync_melee_damage(finaltarget, target_ray_data.raydata, dmg_data.damage)
			end
		else
			log("AAAAAAAAAAAAA WHY IS DUMB KICK NO WORK")
		end
		return true
	end
	return nil
end

Hooks:PostHook(PlayerStandard, "_update_movement", "dash_update", function(self, t, dt)
	if AdvMov.settings.dashcontrols and AdvMov.settings.dashcontrols > 1 then
		local input = self._controller:get_input_axis("move")
		local zero_input = (input.x == 0) and (input.y == 0)
		local input_matches_dash_dir = self._dash_dir and (input.x == self._dash_dir.x) and (input.y == self._dash_dir.y)
		local dash_off_cooldown = (t - (self._last_dash_time or 0)) > 0.80
		local dash_conditions = dash_off_cooldown and not self:on_ladder()

		if not self._state_data.in_air then
			local input_not_matching_or_zero = not zero_input and not input_matches_dash_dir
			local within_doubletap_window = ((t - (self._dash_primed_t or 0)) <= 0.15) and ((t - (self._dash_initial_tap_t or 0)) <= 0.30)
			local dash_primed_timeout = not within_doubletap_window
			local doubletap_conditions = (zero_input and within_doubletap_window) and (AdvMov.settings.dashcontrols == 3 or AdvMov.settings.dashcontrols == 4)
			local keybind_conditions = (HoldTheKey and HoldTheKey:Keybind_Held("inf_dash") and not self._running and not zero_input) and (AdvMov.settings.dashcontrols == 2 or AdvMov.settings.dashcontrols == 4)

			if input_matches_dash_dir and self._dash_stage == 2 then
				-- player has tapped for the second time
				self._dash_stage = 3
				self._dash_primed_t = t
			elseif dash_off_cooldown and ((self._dash_stage == 3 and doubletap_conditions) or keybind_conditions) then
				-- player has released for the second time (and not held down the input)
				local dir = self._dash_dir or input
				local dashed = self:_do_dash(dir)
				if dashed then
					self._dash_dir = nil
					self._dash_stage = 0
				end
			elseif input_not_matching_or_zero then
				-- initial tap/input different from previous
				self._dash_dir = input
				self._dash_stage = 1
				self._dash_initial_tap_t = t
			elseif dash_primed_timeout and self._dash_stage and (self._dash_stage > 2) then
				-- reset, previous readied dash timed out
				self._dash_dir = nil
				self._dash_stage = 0
			elseif zero_input and self._dash_stage == 1 then
				-- player has released input for the first time
				self._dash_stage = 2
			end

-- old immediately-dash-on-second-input implementation
--[[
			local within_doubletap_window = ((t - (self._dash_primed_t or 0)) < 0.10)
			local keybind_conditions = (HoldTheKey and HoldTheKey:Keybind_Held("inf_dash") and not self._running and not zero_input) and (InFmenu.settings.dashcontrols == 2 or InFmenu.settings.dashcontrols == 4)
			local doubletap_conditions = (input_matches_dash_dir and self._dash_stage and self._dash_stage == 2 and within_doubletap_window) and (InFmenu.settings.dashcontrols == 3 or InFmenu.settings.dashcontrols == 4)
			if dash_conditions and (keybind_conditions or doubletap_conditions) then
				local dashed = self:_do_dash(input)
				if dashed then
					self._dash_dir = nil
					self._dash_stage = 0
				end
			elseif not zero_input then
				-- initial input/input different from previous
				self._dash_dir = input
				self._dash_stage = 1
			elseif zero_input and self._dash_stage == 1 then
				-- player has released previous input (to double-tap)
				self._dash_stage = 2
				self._dash_primed_t = t
			end
--]]
		end

		if self._is_dashing and ((t - (self._last_dash_time or 0)) > 0.30) then
			self._is_dashing = nil
			--self._unit:camera():camera_unit():base():set_target_tilt(0)
		end
	end
end)

function PlayerStandard:_do_dash(input)
	if not (managers.player:current_state() == "mask_off" or managers.player:current_state() == "civilian") then
		-- check if carrying a bag
		local my_carry_data = managers.player:get_my_carry_data()
		local dash_mult = 1
		local dash_height_mult = 1
		if my_carry_data then
			-- and use its movespeed to scale down dash distance
			local carried_type = tweak_data.carry[my_carry_data.carry_id].type
			if tweak_data.carry.types[carried_type] then
				dash_mult = tweak_data.carry.types[carried_type].move_speed_modifier
				dash_height_mult = tweak_data.carry.types[carried_type].jump_modifier
			end
		end
		if self._unit:mover() then
			local rotation_flat = self._ext_camera:rotation()
			mvector3.set_x(rotation_flat, 0)
			mvector3.set_y(rotation_flat, 0)
			mvector3.rotate_with(input, rotation_flat)
			mvector3.multiply(input, (500 * dash_mult))
			mvector3.add(input, Vector3(0, 0, 200 * dash_height_mult))
			self._last_velocity_xy = input
			self._unit:mover():set_velocity(self._last_velocity_xy)
			self._last_dash_time = self._last_t
			self._ext_camera:play_shaker("player_land", 0.5)
			self._unit:sound():_play("footstep_land")
			self._is_dashing = true
			--self._unit:camera():camera_unit():base():set_target_tilt(3)
			self._unit:movement():_restart_stamina_regen_timer()
			return true
		end
	end
	return false
end

function PlayerStandard:_is_doing_advanced_movement()
	return self._is_sliding or self._is_wallkicking or self._is_wallrunning or self._is_dashing
end

function PlayerStandard:_advanced_movement_stamina_mult()
	if self._is_wallkicking or self._is_wallrunning then
		return 1.5
	else
		return 1
	end
end


function PlayerStandard:_advanced_movement_dodge_bonus()
	if self._is_dashing then
		return 0.20
	elseif self._is_sliding or self._is_wallkicking or self._is_wallrunning then
		return 0.10
	else
		return 0
	end
end

Hooks:PostHook(PlayerStandard, "_calculate_standard_variables", "wtfismyrealspeed", function(self, t, dt)
	self._last_speed = mvector3.normalize(self._unit:sampled_velocity())
	--log(self._last_speed)
	-- cannot trust last_velocity_xy
end)

Hooks:PostHook(PlayerStandard, "_start_action_jump", "set_jump_var_plox", function(self, t, action_start_data)
	self._last_jump_t = t
end)

--[[
function PlayerStandard:_get_ground_normal()
	local playerpos = mvector3.copy(managers.player:player_unit():position())
	local downpos = mvector3.copy(managers.player:player_unit():position() + Vector3(0, 0, -40))
	return ground_ray = Utils:GetCrosshairRay(playerpos, downpos)	
end
--]]