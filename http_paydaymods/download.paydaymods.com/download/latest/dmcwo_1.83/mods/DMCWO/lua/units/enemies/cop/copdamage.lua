--[[
This script is used in DMC's Weapon Overhaul, please make sure you have the most up to date version
]]

function CopDamage:damage_bullet(attack_data)
	self._attack_data = attack_data
	if self._dead or self._invulnerable then
		return
	end
	if PlayerDamage.is_friendly_fire(self, attack_data.attacker_unit) then
		return "friendly_fire"
	end
	
	local damage = attack_data.damage
	
	local has_ap = attack_data.weapon_unit:base()._has_ap or nil
	local has_hp = attack_data.weapon_unit:base()._has_hp or nil
	
	local is_civilian = CopDamage.is_civilian(self._unit:base()._tweak_table)
	if not is_civilian then
		managers.player:send_message(Message.OnEnemyShot, nil, attack_data.attacker_unit, self._unit, "bullet")
	end
	if self._has_plate and ( (attack_data.col_ray.body and attack_data.col_ray.body:name() == Idstring("body_plate")) or ( self._char_tweak and self._char_tweak == "tank" and (attack_data.col_ray.body:name() == Idstring("body_armor_chest") or attack_data.col_ray.body:name() == Idstring("body_armor_stomache") or attack_data.col_ray.body:name() == Idstring("body_armor_back"))) ) and not attack_data.armor_piercing
	then
		local armor_pierce_roll = math.rand(1)
		local armor_pierce_value = 0
		if attack_data.attacker_unit == managers.player:player_unit() and not attack_data.weapon_unit:base().thrower_unit then
			armor_pierce_value = armor_pierce_value + attack_data.weapon_unit:base():armor_piercing_chance()
			armor_pierce_value = armor_pierce_value + managers.player:upgrade_value("player", "armor_piercing_chance", 0)
			armor_pierce_value = armor_pierce_value + managers.player:upgrade_value("weapon", "armor_piercing_chance", 0)
			armor_pierce_value = armor_pierce_value + managers.player:upgrade_value("weapon", "armor_piercing_chance_2", 0)
			if attack_data.weapon_unit:base():got_silencer() then
				armor_pierce_value = armor_pierce_value + managers.player:upgrade_value("weapon", "armor_piercing_chance_silencer", 0)
			end
			local weapon_category = attack_data.weapon_unit:base():weapon_tweak_data().category
			if weapon_category == "saw" then
				armor_pierce_value = armor_pierce_value + managers.player:upgrade_value("saw", "armor_piercing_chance", 0)
			end
		elseif attack_data.attacker_unit:base() and attack_data.attacker_unit:base().sentry_gun then
			local owner = attack_data.attacker_unit:base():get_owner()
			if alive(owner) then
				if owner == managers.player:player_unit() then
					armor_pierce_value = armor_pierce_value + managers.player:upgrade_value("sentry_gun", "armor_piercing_chance", 0)
					armor_pierce_value = armor_pierce_value + managers.player:upgrade_value("sentry_gun", "armor_piercing_chance_2", 0)
				else
					armor_pierce_value = armor_pierce_value + (owner:base():upgrade_value("sentry_gun", "armor_piercing_chance") or 0)
					armor_pierce_value = armor_pierce_value + (owner:base():upgrade_value("sentry_gun", "armor_piercing_chance_2") or 0)
				end
			end
		end
		damage = damage * armor_pierce_value
		if armor_pierce_roll >= armor_pierce_value then
			return
		end
	elseif self._char_tweak and self._char_tweak == "tank" then
		if attack_data.col_ray.body then
			if attack_data.col_ray.body:name() == Idstring("body_helmet_plate") or attack_data.col_ray.body:name() == Idstring("body_armor_throat") or attack_data.col_ray.body:name() == Idstring("body_armor_neck") or attack_data.col_ray.body:name() == Idstring("body_helmet_glass") then
				damage = damage * 0.1
			end
		end
	end
	local result
	local body_index = self._unit:get_body_index(attack_data.col_ray.body:name())
	local head = self._head_body_name and attack_data.col_ray.body and attack_data.col_ray.body:name() == self._ids_head_body_name
	--log(tostring( attack_data.col_ray.body:name():key() ))
	if self._char_tweak then
		if self._char_tweak == "tank" then
			if has_ap then
				if head then
				else
					damage = damage * 1.2
				end
			elseif has_hp then
				if head then
					damage = damage * 0.6
				else
					damage = damage * 1.2
				end
			end
		elseif self._char_tweak == "city_swat" or self._char_tweak == "phalanx_minion" then
			if has_ap then
				damage = damage * 1.2
			elseif has_hp then
				damage = damage * 0.6
			end
		elseif self._char_tweak == "fbi_heavy_swat" then
			if has_ap then
				if head then
					damage = damage * 1.2
				else
					damage = damage * 0.6
				end
			elseif has_hp then
				if head then
					damage = damage * 0.6
				else
					damage = damage * 1.2
				end
			end
		else --other units
			if has_ap then
				if head then
				else
					damage = damage * 0.6
				end
			elseif has_hp then
				damage = damage * 1.2
			end
		end
	end
	
	if self._unit:base():char_tweak().DAMAGE_CLAMP_BULLET then
		damage = math.min(damage, self._unit:base():char_tweak().DAMAGE_CLAMP_BULLET)
	end
	damage = damage * (self._marked_dmg_mul or 1)
	if self._marked_dmg_mul and managers.player:has_category_upgrade("player", "marked_inc_dmg_distance") then
		local dst = mvector3.distance(attack_data.origin, self._unit:position())
		local spott_dst = managers.player:upgrade_value("player", "marked_inc_dmg_distance")
		if dst > spott_dst[1] then
			damage = damage * spott_dst[2]
		end
	end
	local headshot = false
	local headshot_multiplier = 1
	local hs_mult = attack_data.weapon_unit:base()._hs_mult or 1
		
	if attack_data.attacker_unit == managers.player:player_unit() then
		local critical_hit, crit_damage = self:roll_critical_hit(damage)
	
		if critical_hit then
			managers.hud:on_crit_confirmed()
			damage = crit_damage
		else
			managers.hud:on_hit_confirmed()
		end
		headshot_multiplier = managers.player:upgrade_value("weapon", "passive_headshot_damage_multiplier", 1)
		if self._char_tweak and self._char_tweak.priority_shout then
			damage = damage * managers.player:upgrade_value("weapon", "special_damage_taken_multiplier", 1)
		end
		if head then
			managers.player:on_headshot_dealt()
			headshot = true
		end
	end
		
		
	local char_hs_mult
	if self._damage_reduction_multiplier then
		damage = damage * self._damage_reduction_multiplier
	elseif head then
		if self._char_tweak and self._char_tweak.headshot_dmg_mul then
			char_hs_mult = (self._char_tweak.headshot_dmg_mul * headshot_multiplier) * hs_mult
			if char_hs_mult < 1.0 then 
				char_hs_mult = 1.0
			end
		else
			char_hs_mult = (self._health * 10) * hs_mult
			if char_hs_mult < 1.0 then 
				char_hs_mult = 1.0
			end
		end
		damage = damage * char_hs_mult
	end

	if attack_data.weapon_unit and attack_data.weapon_unit:base().is_category and attack_data.weapon_unit:base():is_category("bow", "crossbow", "saw") and managers.player:has_category_upgrade("weapon", "automatic_head_shot_add") then
		attack_data.add_head_shot_mul = managers.player:upgrade_value("weapon", "automatic_head_shot_add", nil)
	end
	if not head and attack_data.add_head_shot_mul and self._char_tweak and self._char_tweak.access ~= "tank" then
		local mul = self._char_tweak.headshot_dmg_mul * attack_data.add_head_shot_mul + 1
		damage = damage * mul
	end
	
	damage = self:_apply_damage_reduction(damage)
	local damage_percent = math.ceil(math.clamp(damage / self._HEALTH_INIT_PRECENT, 1, self._HEALTH_GRANULARITY))
	damage = damage_percent * self._HEALTH_INIT_PRECENT
	damage, damage_percent = self:_apply_min_health_limit(damage, damage_percent)
	if damage >= self._health then
		if head and damage > math.random(10) then
			self:_spawn_head_gadget({
				position = attack_data.col_ray.body:position(),
				rotation = attack_data.col_ray.body:rotation(),
				dir = attack_data.col_ray.ray
			})
		end
		attack_data.damage = self._health
		result = {
			type = "death",
			variant = attack_data.variant
		}
		self:die(attack_data)
		self:chk_killshot(attack_data.attacker_unit, "bullet", headshot)
	else
		attack_data.damage = damage
		local result_type = not self._char_tweak.immune_to_knock_down and (attack_data.knock_down and "knock_down" or attack_data.stagger and not self._has_been_staggered and "stagger") or self:get_damage_type(damage_percent, "bullet")
		result = {
			type = result_type,
			variant = attack_data.variant
		}
		self:_apply_damage_to_health(damage)
	end
	attack_data.result = result
	attack_data.pos = attack_data.col_ray.position
	if result.type == "death" then
		local data = {
			name = self._unit:base()._tweak_table,
			stats_name = self._unit:base()._stats_name,
			head_shot = head,
			weapon_unit = attack_data.weapon_unit,
			variant = attack_data.variant
		}
		if managers.groupai:state():all_criminals()[attack_data.attacker_unit:key()] then
			managers.statistics:killed_by_anyone(data)
		end
		if attack_data.attacker_unit == managers.player:player_unit() then
			local special_comment = self:_check_special_death_conditions(attack_data.variant, attack_data.col_ray.body, attack_data.attacker_unit, attack_data.weapon_unit)
			self:_comment_death(attack_data.attacker_unit, self._unit:base()._tweak_table, special_comment)
			self:_show_death_hint(self._unit:base()._tweak_table)
			local attacker_state = managers.player:current_state()
			data.attacker_state = attacker_state
			managers.statistics:killed(data)
			self:_check_damage_achievements(attack_data, head)
			if not is_civilian and managers.player:has_category_upgrade("temporary", "overkill_damage_multiplier") and not attack_data.weapon_unit:base().thrower_unit then
				local weapon_category = attack_data.weapon_unit:base():weapon_tweak_data().category
				if weapon_category == "shotgun" or weapon_category == "saw" then
					managers.player:activate_temporary_upgrade("temporary", "overkill_damage_multiplier")
				end
			end
			if is_civilian then
				managers.money:civilian_killed()
			end
		elseif attack_data.attacker_unit:in_slot(managers.slot:get_mask("criminals_no_deployables")) then
			self:_AI_comment_death(attack_data.attacker_unit, self._unit:base()._tweak_table)
		elseif attack_data.attacker_unit:base().sentry_gun and Network:is_server() then
			local server_info = attack_data.weapon_unit:base():server_information()
			if server_info and server_info.owner_peer_id ~= managers.network:session():local_peer():id() then
				local owner_peer = managers.network:session():peer(server_info.owner_peer_id)
				if owner_peer then
					owner_peer:send_queued_sync("sync_player_kill_statistic", data.name, data.head_shot and true or false, data.weapon_unit, data.variant, data.stats_name)
				end
			else
				data.attacker_state = managers.player:current_state()
				managers.statistics:killed(data)
			end
		end
	end
	local hit_offset_height = math.clamp(attack_data.col_ray.position.z - self._unit:movement():m_pos().z, 0, 300)
	local attacker = attack_data.attacker_unit
	if attacker:id() == -1 then
		attacker = self._unit
	end
	if alive(attack_data.weapon_unit) and attack_data.weapon_unit:base() and attack_data.weapon_unit:base().add_damage_result then
		attack_data.weapon_unit:base():add_damage_result(self._unit, attacker, result.type == "death", damage_percent)
	end
	local variant
	if result.type == "knock_down" then
		variant = 1
	elseif result.type == "stagger" then
		variant = 2
		self._has_been_staggered = true
	else
		variant = 0
	end
	self:_send_bullet_attack_result(attack_data, attacker, damage_percent, body_index, hit_offset_height, variant)
	self:_on_damage_received(attack_data)
	return result
end

local orig_damage_tase = CopDamage.damage_tase
function CopDamage:damage_tase(attack_data)
	self._attack_data = attack_data
	return orig_damage_tase(self, attack_data)
end

local orig_damage_explosion = CopDamage.damage_explosion
function CopDamage:damage_explosion(attack_data)
	self._attack_data = attack_data
	return orig_damage_explosion(self, attack_data)
end

--Thanks to SC
function CopDamage:damage_fire(attack_data)
	self._attack_data = attack_data
	if self._dead or self._invulnerable then
		return
	end
	local was_alive = not self._dead
	local result
	local head = self._head_body_name and attack_data.col_ray.body and attack_data.col_ray.body:name() == self._ids_head_body_name
	local damage = attack_data.damage
	local headshot_multiplier = 1
	if attack_data.attacker_unit == managers.player:player_unit() then
		local critical_hit, crit_damage = self:roll_critical_hit(damage)
		if critical_hit then
			managers.hud:on_crit_confirmed()
			damage = crit_damage
		else
			managers.hud:on_hit_confirmed()
		end
		headshot_multiplier = managers.player:upgrade_value("weapon", "passive_headshot_damage_multiplier", 1)
		if tweak_data.character[self._unit:base()._tweak_table].priority_shout then
			damage = damage * managers.player:upgrade_value("weapon", "special_damage_taken_multiplier", 1)
		end
		if head then
			managers.player:on_headshot_dealt()
		end
	end
	if self._damage_reduction_multiplier then
		damage = damage * self._damage_reduction_multiplier
	elseif head then
		if self._char_tweak and self._char_tweak.headshot_dmg_mul then
			damage = damage * self._char_tweak.headshot_dmg_mul * headshot_multiplier
		else
			damage = self._health * 10
		end
	end
	damage = self:_apply_damage_reduction(damage)
	damage = math.clamp(damage, 0, self._HEALTH_INIT)
	local damage_percent = math.ceil(damage / self._HEALTH_INIT_PRECENT)
	damage = damage_percent * self._HEALTH_INIT_PRECENT
	damage, damage_percent = self:_apply_min_health_limit(damage, damage_percent)
	if damage >= self._health then
		attack_data.damage = self._health
		result = {
			type = "death",
			variant = attack_data.variant
		}
		self:die(attack_data)
		self:chk_killshot(attack_data.attacker_unit, "fire")
	else
		attack_data.damage = damage
		local result_type = attack_data.variant == "stun" and "hurt_sick" or self:get_damage_type(damage_percent, "fire")
		result = {
			type = result_type,
			variant = attack_data.variant
		}
		self:_apply_damage_to_health(damage)
	end
	attack_data.result = result
	attack_data.pos = attack_data.col_ray.position
	if self._head_body_name and attack_data.variant ~= "stun" then
		head = attack_data.col_ray.body and self._head_body_key and attack_data.col_ray.body:key() == self._head_body_key
		local body = self._unit:body(self._head_body_name)
	end
	local attacker = attack_data.attacker_unit
	if not attacker or attacker and alive(attacker) and attacker:id() == -1 then
		attacker = self._unit
	end
	local attacker_unit = attack_data.attacker_unit
	if result.type == "death" then
		local data = {
			name = self._unit:base()._tweak_table,
			stats_name = self._unit:base()._stats_name,
			owner = attack_data.owner,
			weapon_unit = attack_data.weapon_unit,
			variant = attack_data.variant,
			head_shot = head
		}
		if not attack_data.is_fire_dot_damage then
			managers.statistics:killed_by_anyone(data)
		end
		if managers.player:has_category_upgrade("temporary", "overkill_damage_multiplier") and attacker_unit == managers.player:player_unit() and attack_data.weapon_unit and not attack_data.weapon_unit:base().thrower_unit then
			local weapon_category = attack_data.weapon_unit:base():weapon_tweak_data().category
			if weapon_category == "shotgun" or weapon_category == "saw" then
				managers.player:activate_temporary_upgrade("temporary", "overkill_damage_multiplier")
			end
		end
		if attacker_unit and alive(attacker_unit) and attacker_unit:base() and attacker_unit:base().thrower_unit then
			attacker_unit = attacker_unit:base():thrower_unit()
			data.weapon_unit = attack_data.attacker_unit
		end
		if attacker_unit == managers.player:player_unit() then
			if alive(attacker_unit) then
				self:_comment_death(attacker_unit, self._unit:base()._tweak_table)
			end
			self:_show_death_hint(self._unit:base()._tweak_table)
			if not attack_data.is_fire_dot_damage then
				managers.statistics:killed(data)
			end
			if CopDamage.is_civilian(self._unit:base()._tweak_table) then
				managers.money:civilian_killed()
			end
			self:_check_damage_achievements(attack_data, false)
		end
	end
	if alive(attacker) and attacker:base() and attacker:base().add_damage_result then
		attacker:base():add_damage_result(self._unit, result.type == "death", damage_percent)
	end
	if not attack_data.is_fire_dot_damage then
		local fire_dot_data = attack_data.fire_dot_data
		local flammable
		local char_tweak = tweak_data.character[self._unit:base()._tweak_table]
		if char_tweak.flammable == nil then
			flammable = true
		else
			flammable = char_tweak.flammable
		end
		local distance = 1000
		local hit_loc = attack_data.col_ray.hit_position
		if hit_loc and attacker_unit and attacker_unit.position then
			distance = mvector3.distance(hit_loc, attacker_unit:position())
		end
		local fire_dot_max_distance = 3000
		local fire_dot_trigger_chance = 30
		if fire_dot_data then
			fire_dot_max_distance = tonumber(fire_dot_data.dot_trigger_max_distance)
			fire_dot_trigger_chance = tonumber(fire_dot_data.dot_trigger_chance)
		end
		local start_dot_damage_roll = math.random(1, 100)
		local start_dot_dance_antimation = false
		if flammable and not attack_data.is_fire_dot_damage and distance < fire_dot_max_distance and fire_dot_trigger_chance >= start_dot_damage_roll then
			managers.fire:add_doted_enemy(self._unit, TimerManager:game():time(), attack_data.weapon_unit, fire_dot_data.dot_length, fire_dot_data.dot_damage, attack_data.attacker_unit)
			start_dot_dance_antimation = true
		end
		if fire_dot_data then
			fire_dot_data.start_dot_dance_antimation = start_dot_dance_antimation
			attack_data.fire_dot_data = fire_dot_data
		end
	else
	end
	self:_send_fire_attack_result(attack_data, attacker, damage_percent, attack_data.is_fire_dot_damage, attack_data.col_ray.ray)
	self:_on_damage_received(attack_data)
end

local orig_damage_dot = CopDamage.damage_dot
function CopDamage:damage_dot(attack_data)
	self._attack_data = attack_data
	return orig_damage_dot(self, attack_data)
end

--Thanks to Rokk
if not SC then
	Hooks:PostHook(CopDamage, "_on_death", "DMCRemoveJoker", function(self)
		if self._unit:unit_data().is_convert and DMC._converts then
			for i, unit in pairs(DMC._converts) do
				if unit == self._unit then
					table.remove(DMC._converts, i)
				end
			end
		end
	end)
end


local melee_original = CopDamage.damage_melee
if DMCWO.melee_hs == true then
	--Melee hsmult code courtesy of SC
	local mvec_1 = Vector3()
	local mvec_2 = Vector3()
	function CopDamage:damage_melee(attack_data)
		if self._dead or self._invulnerable then
			return
		end
		if PlayerDamage.is_friendly_fire(self, attack_data.attacker_unit) then
			return "friendly_fire"
		end
		local result
		local head = self._head_body_name and attack_data.col_ray.body and attack_data.col_ray.body:name() == self._ids_head_body_name
		local damage = attack_data.damage
		if attack_data.attacker_unit and attack_data.attacker_unit == managers.player:player_unit() then
			local critical_hit, crit_damage = self:roll_critical_hit(damage)
			if critical_hit then
				managers.hud:on_crit_confirmed()
				damage = crit_damage
			else
				managers.hud:on_hit_confirmed()
			end
			if tweak_data.achievement.cavity.melee_type == attack_data.name_id and not CopDamage.is_civilian(self._unit:base()._tweak_table) then
				managers.achievment:award(tweak_data.achievement.cavity.award)
			end
		end
		damage = damage * (self._marked_dmg_mul or 1)
		local head = self._head_body_name and attack_data.col_ray.body and attack_data.col_ray.body:name() == self._ids_head_body_name
		local damage = attack_data.damage
		local damage_effect = attack_data.damage_effect
		local headshot_multiplier = 1
		if attack_data.attacker_unit == managers.player:player_unit() then
			headshot_multiplier = managers.player:upgrade_value("weapon", "passive_headshot_damage_multiplier", 1)
			if self._char_tweak and self._char_tweak.priority_shout then
				damage = damage * managers.player:upgrade_value("weapon", "special_damage_taken_multiplier", 1)
			end
			if head then
				managers.player:on_headshot_dealt()
			end
		end
		if self._damage_reduction_multiplier then
			damage = damage * self._damage_reduction_multiplier
			damage_effect = damage_effect * self._damage_reduction_multiplier
		elseif head then
			if self._char_tweak and self._char_tweak.headshot_dmg_mul then
				damage = damage * self._char_tweak.headshot_dmg_mul * headshot_multiplier
				damage_effect = damage_effect * self._char_tweak.headshot_dmg_mul * headshot_multiplier
			else
				damage = self._health * 10
				damage_effect = self._health * 10
			end
		end
		local damage_effect = attack_data.damage_effect
		local damage_effect_percent
		damage = self:_apply_damage_reduction(damage)
		damage = math.clamp(damage, self._HEALTH_INIT_PRECENT, self._HEALTH_INIT)
		local damage_percent = math.ceil(damage / self._HEALTH_INIT_PRECENT)
		damage = damage_percent * self._HEALTH_INIT_PRECENT
		damage, damage_percent = self:_apply_min_health_limit(damage, damage_percent)
		if damage >= self._health then
			damage_effect_percent = 1
			attack_data.damage = self._health
			result = {
				type = "death",
				variant = attack_data.variant
			}
			self:die(attack_data)
			self:chk_killshot(attack_data.attacker_unit, "melee")
		else
			attack_data.damage = damage
			damage_effect = math.clamp(damage_effect, self._HEALTH_INIT_PRECENT, self._HEALTH_INIT)
			damage_effect_percent = math.ceil(damage_effect / self._HEALTH_INIT_PRECENT)
			damage_effect_percent = math.clamp(damage_effect_percent, 1, self._HEALTH_GRANULARITY)
			local result_type = attack_data.shield_knock and self._char_tweak.damage.shield_knocked and "shield_knock" or attack_data.variant == "counter_tased" and "counter_tased" or attack_data.variant == "taser_tased" and "taser_tased" or attack_data.variant == "counter_spooc" and "expl_hurt" or self:get_damage_type(damage_effect_percent, "melee") or "fire_hurt"
			result = {
				type = result_type,
				variant = attack_data.variant
			}
			self:_apply_damage_to_health(damage)
		end
		attack_data.result = result
		attack_data.pos = attack_data.col_ray.position
		local dismember_victim = false
		local snatch_pager = false
		if result.type == "death" then
			if self:_dismember_condition(attack_data) then
				self:_dismember_body_part(attack_data)
				dismember_victim = true
			end
			local data = {
				name = self._unit:base()._tweak_table,
				stats_name = self._unit:base()._stats_name,
				head_shot = head,
				weapon_unit = attack_data.weapon_unit,
				name_id = attack_data.name_id,
				variant = attack_data.variant
			}
			managers.statistics:killed_by_anyone(data)
			if attack_data.attacker_unit == managers.player:player_unit() then
				self:_comment_death(attack_data.attacker_unit, self._unit:base()._tweak_table)
				self:_show_death_hint(self._unit:base()._tweak_table)
				managers.statistics:killed(data)
				local is_civlian = CopDamage.is_civilian(self._unit:base()._tweak_table)
				local is_gangster = CopDamage.is_gangster(self._unit:base()._tweak_table)
				local is_cop = not is_civlian and not is_gangster
				if not is_civlian and managers.groupai:state():whisper_mode() and managers.blackmarket:equipped_mask().mask_id == tweak_data.achievement.cant_hear_you_scream.mask then
					managers.achievment:award_progress(tweak_data.achievement.cant_hear_you_scream.stat)
				end
				mvector3.set(mvec_1, self._unit:position())
				mvector3.subtract(mvec_1, attack_data.attacker_unit:position())
				mvector3.normalize(mvec_1)
				mvector3.set(mvec_2, self._unit:rotation():y())
				local from_behind = mvector3.dot(mvec_1, mvec_2) >= 0
				if tweak_data.blackmarket.melee_weapons[attack_data.name_id] then
					local achievements = tweak_data.achievement.enemy_melee_kill_achievements or {}
					local melee_type = tweak_data.blackmarket.melee_weapons[attack_data.name_id].type
					local enemy_type = self._unit:base()._tweak_table
					local unit_weapon = self._unit:base()._default_weapon_id
					local health_ratio = managers.player:player_unit():character_damage():health_ratio() * 100
					local melee_pass, melee_weapons_pass, type_pass, enemy_pass, enemy_weapon_pass, diff_pass, health_pass, level_pass, job_pass, jobs_pass, enemy_count_pass, all_pass, cop_pass, gangster_pass, civilian_pass, stealth_pass, on_fire_pass, behind_pass
					for achievement, achievement_data in pairs(achievements) do
						melee_pass = not achievement_data.melee_id or achievement_data.melee_id == attack_data.name_id
						melee_weapons_pass = not achievement_data.melee_weapons or table.contains(achievement_data.melee_weapons, attack_data.name_id)
						type_pass = not achievement_data.melee_type or melee_type == achievement_data.melee_type
						enemy_pass = not achievement_data.enemy or enemy_type == achievement_data.enemy
						enemy_weapon_pass = not achievement_data.enemy_weapon or unit_weapon == achievement_data.enemy_weapon
						behind_pass = not achievement_data.from_behind or from_behind
						diff_pass = not achievement_data.difficulty or table.contains(achievement_data.difficulty, Global.game_settings.difficulty)
						health_pass = not achievement_data.health or health_ratio <= achievement_data.health
						if achievement_data.level_id then
							level_pass = (managers.job:current_level_id() or "") == achievement_data.level_id
						end
						job_pass = not achievement_data.job or managers.job:current_real_job_id() == achievement_data.job
						jobs_pass = not achievement_data.jobs or table.contains(achievement_data.jobs, managers.job:current_real_job_id())
						enemy_count_pass = not achievement_data.enemy_kills or managers.statistics:session_enemy_killed_by_type(achievement_data.enemy_kills.enemy, "melee") >= achievement_data.enemy_kills.count
						cop_pass = not achievement_data.is_cop or is_cop
						gangster_pass = not achievement_data.is_gangster or is_gangster
						civilian_pass = not achievement_data.is_not_civilian or not is_civlian
						stealth_pass = not achievement_data.is_stealth or managers.groupai:state():whisper_mode()
						on_fire_pass = not achievement_data.is_on_fire or managers.fire:is_set_on_fire(self._unit)
						if achievement_data.enemies then
							enemy_pass = false
							for _, enemy in pairs(achievement_data.enemies) do
								if enemy == enemy_type then
									enemy_pass = true
								else
								end
							end
						end
						all_pass = melee_pass and melee_weapons_pass and type_pass and enemy_pass and enemy_weapon_pass and behind_pass and diff_pass and health_pass and level_pass and job_pass and jobs_pass and cop_pass and gangster_pass and civilian_pass and stealth_pass and on_fire_pass and enemy_count_pass
						if all_pass then
							if achievement_data.stat then
								managers.achievment:award_progress(achievement_data.stat)
							elseif achievement_data.award then
								managers.achievment:award(achievement_data.award)
							elseif achievement_data.challenge_stat then
								managers.challenge:award_progress(achievement_data.challenge_stat)
							elseif achievement_data.challenge_award then
								managers.challenge:award(achievement_data.challenge_award)
							end
						end
					end
				end
				if is_cop and Global.game_settings.level_id == "nightclub" and attack_data.name_id and attack_data.name_id == "fists" then
					managers.achievment:award_progress(tweak_data.achievement.final_rule.stat)
				end
				if is_civlian then
					managers.money:civilian_killed()
				elseif managers.player:upgrade_value("player", "melee_kill_snatch_pager_chance", 0) > math.rand(1) then
					snatch_pager = true
					self._unit:unit_data().has_alarm_pager = false
				end
			end
		end
		local hit_offset_height = math.clamp(attack_data.col_ray.position.z - self._unit:movement():m_pos().z, 0, 300)
		local variant
		if result.type == "shield_knock" then
			variant = 1
		elseif result.type == "counter_tased" then
			variant = 2
		elseif result.type == "expl_hurt" then
			variant = 4
		elseif snatch_pager then
			variant = 3
		elseif result.type == "taser_tased" then
			variant = 5
		elseif dismember_victim then
			variant = 6
		else
			variant = 0
		end
		local body_index = self._unit:get_body_index(attack_data.col_ray.body:name())
		self:_send_melee_attack_result(attack_data, damage_percent, damage_effect_percent, hit_offset_height, variant, body_index)
		self:_on_damage_received(attack_data)
		return result
	end
else
	function CopDamage:damage_melee(attack_data)
		self._attack_data = attack_data
		return melee_original(self, attack_data)
	end
end

local critical_hit_original = CopDamage.roll_critical_hit
function CopDamage:roll_critical_hit(damage)
	if self._attack_data then
		local head = self._head_body_name and self._attack_data.col_ray.body and self._attack_data.col_ray.body:name() == self._ids_head_body_name
		if self._attack_data.weapon_unit then
			local no_crits = self._attack_data.weapon_unit:base()._no_crits or false
			local stat_damage = self._attack_data.weapon_unit:base()._check_damage
			local rays = self._attack_data.weapon_unit:base()._rays or 1
		end
	else
		return false, damage
	end
	self._attack_data = nil
	if stat_damage and rays and (stat_damage / rays) >= 8 then
		no_crits = true		
		--log("Damage per ray exceeds 80! Critical hits will not proc!!")
	end
	if self._char_tweak and self._char_tweak == "tank" and not head then
		no_crits = true		
		--log("Ray did not hit the Tank's face! Critical hits will not proc!!")
	end
	if no_crits then
		return false, damage
	else
		return critical_hit_original(self, damage)
	end
end

if DMCWO.all_dismember_cloaker == true then
	function CopDamage:_dismember_condition(attack_data)
		local dismember_victim = false
		local target_is_spook = false
		target_is_spook = alive(attack_data.col_ray.unit) and attack_data.col_ray.unit:base() and attack_data.col_ray.unit:base()._tweak_table == "spooc"
		local criminal_name = managers.criminals:local_character_name()
		local criminal_melee_weapon = managers.blackmarket:equipped_melee_weapon()
		local weapon_charged = false
		weapon_charged = attack_data.charge_lerp_value and attack_data.charge_lerp_value > 0.5
		if target_is_spook and weapon_charged and criminal_melee_weapon == "sandsteel" then
			dismember_victim = true
		end
		return dismember_victim
	end
end




