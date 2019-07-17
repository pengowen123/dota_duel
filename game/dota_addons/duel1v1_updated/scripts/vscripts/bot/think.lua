-- Points to escape to
ESCAPE_POINTS = {
	-- Dire lowground
	Vector(2950, 576, 128),
	-- Radiant lowground
	Vector(-900, 640, 128),
	-- Bottom left
	Vector(250, -100, 384),
	-- Bottom center
	Vector(975, -100, 384),
	-- Bottom right
	Vector(1700, -100, 384),
	-- Top left
	Vector(300, 1300, 384),
	-- Top center
	Vector(1050, 1300, 384),
	-- Top right
	Vector(1800, 1300, 384),
}


-- Points to idle at
IDLE_POINTS = {
	-- Bottom left
	Vector(250, -100, 384),
	-- Bottom right
	Vector(1700, -100, 384),
	-- Top left
	Vector(300, 1300, 384),
	-- Top right
	Vector(1800, 1300, 384),
}


-- The X coordinate of the vertical center line of the map (splits map into left and right)
X_MAP_CENTER = 1050
-- The Y coordinate of the horizontal center line of the map (splits map into top and bottom)
Y_MAP_CENTER = 672


-- Represents which action was taken by `BotController:ThinkAbilities`
THINK_RESULT_NONE = 0
THINK_RESULT_INSTANT = 1
THINK_RESULT_NON_INSTANT = 2


-- Performs all actions for the bot, called every THINK_INTERVAL seconds
function BotController:Think()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	local think_interval = THINK_INTERVAL

	if not bot_hero:IsAlive() then
		think_interval = DEAD_THINK_INTERVAL
	end

	self.global_ability_cooldown = self.global_ability_cooldown - think_interval
	self.cast_point = self.cast_point - think_interval

	if not bot_hero:IsAlive() then
		self.previous_health = nil
		return DEAD_THINK_INTERVAL
	end

	if not self.previous_health then
		self.previous_health = bot_hero:GetMaxHealth()
	end

	local current_health = bot_hero:GetHealth()
	-- HP loss per second based on the previous THINK_INTERVAL seconds
	local hp_loss_per_second = (self.previous_health - current_health) / THINK_INTERVAL

	self.previous_health = current_health

	local is_in_base = bot_hero:HasModifier("modifier_stun")
	-- If this function is run during the small time when the hero is replaced after each round, the
	-- observation updates may happen twice and inaccurately
	-- This might not be possible due to the hero replacement calls being sync, but even if it
	-- happens the consequences aren't too bad
	if is_in_base then
		if not self.purchased_items then
			-- End of round actions
			self.purchased_items = true

			local end_of_round = function()
				self:ThinkShop()

				if not self.first_round then
					self:UpdateObservationChances()
					self:ResetObservationFlags()
					self:ResetDisableCounts()
					self:ResetDamageCounts()
				end
				self.first_round = false
			end

			-- The above code must be delayed because this function could be called while the hero is being swapped
			Timers:CreateTimer(1.5, end_of_round)
		end
		self.time_spent_fighting = 0
	else
		self.purchased_items = false

		if not self.in_round then
			-- Start of round actions
			self.in_round = true

			self:EnterModeRun(0.0)
		end
	end

	self:GatherEnemyInfo()

	self.hold_position = bot_hero:HasModifier("modifier_bloodseeker_rupture")

	-- If ruptured, stand ground and fight
	if self.hold_position then
		self.always_fight = true

		if self.mode ~= MODE_FIGHT then
			self:EnterModeFight()
		end
	end

	if bot_hero:HasModifier("modifier_skeleton_king_reincarnation_scepter_active") then
		-- Run from slark while in wraith form to avoid feeding essence shift stacks
		if player_hero_name == "npc_dota_hero_slark" then
			self:EnterModeRun(1.0)
		end
		-- Running may stil be helpful in this situation, so to be safe this is commented out
		-- self.always_fight = true
		-- self:EnterModeFight()
	end

	-- Update disable counters
	-- This isn't perfect, but it tends to average out to the correct value
	if (bot_hero:IsStunned() or bot_hero:IsMuted() or bot_hero:IsHexed())
			and not bot_hero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not bot_hero:HasModifier("modifier_naga_siren_song_of_the_siren") then
		local base_disable_duration = THINK_INTERVAL / self:GetStatusDurationMultiplier()
		self.seconds_disabled = self.seconds_disabled + base_disable_duration
		self.current_disable = self.current_disable + base_disable_duration
	else
		if self.current_disable > self.longest_disable then
			self.longest_disable = self.current_disable
		end
		self.current_disable = 0
	end

	-- Detect whether the enemy is dealing a dangerous amount of damage (deals with hiding strategies
	-- to manipulate round time, and helps deal with riki perma-invis talent)
	local current_ult_cooldown = bot_hero:GetAbilityByIndex(5):GetCooldownTimeRemaining()
	if current_ult_cooldown == 0 then
		-- If it is not on cooldown, use the skill's effective cooldown
		current_ult_cooldown = EFFECTIVE_REINCARNATION_ULT_COOLDOWN
	end
	local significant_dps = bot_hero:GetHealth() / current_ult_cooldown

	if hp_loss_per_second > significant_dps then
		self.time_spent_fighting = self.time_spent_fighting + THINK_INTERVAL
		self.fighting = true
		self.fighting_timer = FIGHTING_RESET_TIMER
	else
		self.fighting_timer = self.fighting_timer - THINK_INTERVAL

		if self.fighting_timer <= 0 then
			self.fighting = false
		end
	end

	-- Detect short bursts of large amounts of damage such as versus PA or arc warden
	local dps_to_kill = bot_hero:GetMaxHealth() / EFFECTIVE_REINCARNATION_ULT_COOLDOWN
	local very_high_damage = dps_to_kill * VERY_HIGH_DAMAGE_THRESHOLD

	if hp_loss_per_second > very_high_damage then
		self.current_burst_duration = self.current_burst_duration + THINK_INTERVAL

		if self.current_burst_duration >= BURST_DURATION_THRESHOLD then
			self.observations["high_burst_damage"][2] = true
		end
	else
		self.current_burst_duration = self.current_burst_duration - THINK_INTERVAL
		if self.current_burst_duration < 0 then
			self.current_burst_duration = 0
		end
	end

	self.taking_very_high_damage = self.current_burst_duration > 0

	-- Run think function for the current mode
	if not is_in_base then
		if self.mode == MODE_RUN then
			self:ThinkModeRun()
		elseif self.mode == MODE_FIGHT then
			self:ThinkModeFight()
		end
	end

	return THINK_INTERVAL
end


-- Enters the `run` mode
function BotController:EnterModeRun(minimum_run_time)
	-- Makes movement clunky, so commented out for now
	-- local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)
	-- bot_hero:Interrupt()

	self.mode = MODE_RUN
	self.minimum_run_time = minimum_run_time

	self:UpdatePositionGoal()
end


-- Enters the `fight` mode
function BotController:EnterModeFight()
	-- Makes movement clunky, so commented out for now
	-- local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)
	-- bot_hero:Interrupt()

	self.position_goal = nil
	self.mode = MODE_FIGHT
end


-- Think function for using abilities and items
-- Returns whether an ability with a cast point was casted
function BotController:ThinkAbilities()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)
	local player_hero_name = PlayerResource:GetSelectedHeroEntity(self.player_id):GetName()

	local potential_targets = self:GetPotentialAbilityTargets()
	local num_targets = 0

	for i,entity in pairs(potential_targets) do
		if bot_hero:CanEntityBeSeenByMyTeam(entity)
			and entity:IsAlive()
			and (entity:GetTeamNumber() ~= bot_hero:GetTeamNumber()) then
			num_targets = num_targets + 1
		end
	end

	local search_radius = 1300
	local chosen_target = self:GetAbilityTarget(potential_targets, search_radius)

	local is_muted = bot_hero:IsMuted()
	local is_silenced = bot_hero:IsSilenced()
	local health_percentage = bot_hero:GetHealth() / bot_hero:GetMaxHealth()
	local current_mana = bot_hero:GetMana()

	local blade_mail_modifier = bot_hero:FindModifierByName("modifier_item_blade_mail_reflect")

	local has_blade_mail = blade_mail_modifier
		and not (blade_mail_modifier:GetElapsedTime() > BLADE_MAIL_REACTION_TIME
			and self.fighting)

	if bot_hero:IsStunned()
		or IsTaunted(bot_hero)
		or IsFeared(bot_hero)
		or bot_hero:IsAttackImmune()
		or bot_hero:IsInvulnerable()
		or has_blade_mail
		or self:IsCastingAbility()
		or self.global_ability_cooldown > 0
		or (is_muted and is_silenced) then
		return THINK_RESULT_NONE
	end

	-- Only use items if not going to reincarnate on death to save cooldowns until needed
	local use_items = (bot_hero:GetAbilityByIndex(5):GetCooldownTimeRemaining() > 7) and not is_muted

	-- Abilities and items to use
	local wraithfire_blast = bot_hero:GetAbilityByIndex(0)
	local ethereal_blade = nil
	local scythe_of_vyse = nil
	local abyssal_blade = nil
	local euls_scepter = nil
	local heavens_halberd = nil
	local hurricane_pike = nil
	local blade_mail = nil
	local shivas_guard = nil
	local satanic = nil
	local black_king_bar = nil

	for i=0,5 do
		local item = bot_hero:GetItemInSlot(i)

		if item then
			local name = item:GetAbilityName()

			if name == "item_ethereal_blade" then
				ethereal_blade = item

			elseif name == "item_sheepstick" then
				scythe_of_vyse = item

			elseif name == "item_abyssal_blade" then
				abyssal_blade = item

			elseif name == "item_cyclone" then
				euls_scepter = item

			elseif name == "item_shivas_guard" then
				shivas_guard = item

			elseif name == "item_satanic" then
				satanic = item
			elseif name == "item_hurricane_pike" then
				hurricane_pike = item

			elseif name == "item_heavens_halberd" then
				heavens_halberd = item

			elseif name == "item_blade_mail" then
				blade_mail = item

			elseif name == "item_black_king_bar" then
				black_king_bar = item
			end
		end
	end

	if CanCastAbility(black_king_bar, current_mana) then
		bot_hero:CastAbilityImmediately(black_king_bar, 0)
		return THINK_RESULT_INSTANT
	end

	-- Item counters to ethereal blade
	local ethereal_blade_item_counters = {
		["item_satanic"] = true,
		["item_manta"] = true,
		["item_lotus_orb"] = true,
		["item_black_king_bar"] = true,
		["item_guardian_greaves"] = true,
		["item_sphere"] = true,
		["item_cyclone"] = true,
	}

	-- Hero counters to ethereal blade
	local ethereal_blade_hero_counters = {
		["npc_dota_hero_antimage"] = true,
		["npc_dota_hero_phantom_lancer"] = true,
		["npc_dota_hero_omniknight"] = true,
		["npc_dota_hero_troll_warlord"] = true,
		["npc_dota_hero_life_stealer"] = true,
		["npc_dota_hero_legion_commander"] = true,
		["npc_dota_hero_brewmaster"] = true,
		["npc_dota_hero_chaos_knight"] = true,
		["npc_dota_hero_naga_siren"] = true,
		["npc_dota_hero_meepo"] = true,
		["npc_dota_hero_lone_druid"] = true,
		["npc_dota_hero_monkey_king"] = true,
		["npc_dota_hero_weaver"] = true,
		["npc_dota_hero_terrorblade"] = true,
		["npc_dota_hero_templar_assassin"] = true,
		["npc_dota_hero_spectre"] = true,
		["npc_dota_hero_slark"] = true,
		["npc_dota_hero_riki"] = true,
		["npc_dota_hero_visage"] = true,
		["npc_dota_hero_arc_warden"] = true,
	}

	-- Item counters to eul's scepter
	local euls_scepter_item_counters = {
		["item_sphere"] = true,
	}

	-- Hero counters to eul's scepter
	local euls_scepter_hero_counters = {
		["npc_dota_hero_slark"] = true,
		["npc_dota_hero_phantom_lancer"] = true,
		["npc_dota_hero_chaos_knight"] = true,
		["npc_dota_hero_naga_siren"] = true,
		["npc_dota_hero_arc_warden"] = true,
		["npc_dota_hero_monkey_king"] = true,
		["npc_dota_hero_meepo"] = true,
		["npc_dota_hero_visage"] = true,
	}

	-- For each available ability and item:
	-- If it is off cooldown, try to cast it
	-- Otherwise, go to the next ability/item and repeat
	-- If trying to cast and ShouldCastAbility returns false, look for a different target to cast on
	--
	-- Items and abilities are prioritized from lowest cooldown to highest
	while search_radius > 0 and chosen_target do
		local choose_new_target = false
		local distance_to_target = (bot_hero:GetAbsOrigin() - chosen_target:GetAbsOrigin()):Length2D()

		self.is_enemy_disabled = is_disabled

		if not is_silenced then
			if CanCastAbility(wraithfire_blast, current_mana) then
				if ShouldCastAbility(wraithfire_blast, distance_to_target) then
					bot_hero:CastAbilityOnTarget(chosen_target, wraithfire_blast, 0)
					self.cast_point = 0.35
					return THINK_RESULT_NON_INSTANT
				else
					choose_new_target = true
				end
			end
		end

		if use_items then
			if CanCastAbility(heavens_halberd, current_mana) then
				if ShouldCastAbility(heavens_halberd, distance_to_target) then
					bot_hero:CastAbilityOnTarget(chosen_target, heavens_halberd, 0)
					return THINK_RESULT_INSTANT
				else
					choose_new_target = true
				end
			end

			if CanCastAbility(ethereal_blade, current_mana) then
				local self_cast_ethereal_blade = (num_targets > 1)
					or HasAnyItem(chosen_target, ethereal_blade_item_counters)
					or ethereal_blade_hero_counters[player_hero_name]
					or self.use_only_self_cast

				if self_cast_ethereal_blade then
					bot_hero:CastAbilityOnTarget(bot_hero, ethereal_blade, 0)
				else
					if ShouldCastAbility(ethereal_blade, distance_to_target) then
						bot_hero:CastAbilityOnTarget(chosen_target, ethereal_blade, 0)
					else
						bot_hero:CastAbilityOnTarget(bot_hero, ethereal_blade, 0)
					end
				end
				return THINK_RESULT_INSTANT
			end

			if CanCastAbility(scythe_of_vyse, current_mana) then
				if ShouldCastAbility(scythe_of_vyse, distance_to_target) then
					bot_hero:CastAbilityOnTarget(chosen_target, scythe_of_vyse, 0)
					return THINK_RESULT_INSTANT
				else
					choose_new_target = true
				end
			end

			if CanCastAbility(euls_scepter, current_mana) then
				local self_cast_euls_scepter = (num_targets > 1)
					or HasAnyItem(chosen_target, euls_scepter_item_counters)
					or euls_scepter_hero_counters[player_hero_name]
					or self.use_only_self_cast
					or is_silenced

				if self_cast_euls_scepter then
					bot_hero:CastAbilityOnTarget(bot_hero, euls_scepter, 0)
				else
					if ShouldCastAbility(euls_scepter, distance_to_target) then
						bot_hero:CastAbilityOnTarget(chosen_target, euls_scepter, 0)
					else
						bot_hero:CastAbilityOnTarget(bot_hero, euls_scepter, 0)
					end
				end
				return THINK_RESULT_INSTANT
			end

			if CanCastAbility(hurricane_pike, current_mana) then
				local self_cast_hurricane_pike = bot_hero:HasModifier("modifier_slark_pounce_leash")
				if self_cast_hurricane_pike then
					bot_hero:CastAbilityOnTarget(bot_hero, hurricane_pike, 0)
					self:EnterModeRun(3.0)
				else
					if ShouldCastAbility(hurricane_pike, distance_to_target) then
						bot_hero:CastAbilityOnTarget(chosen_target, hurricane_pike, 0)
						self:EnterModeRun(3.0)
						return THINK_RESULT_INSTANT
					else
						choose_new_target = true
					end
				end
			end

			if CanCastAbility(abyssal_blade, current_mana) then
				if ShouldCastAbility(abyssal_blade, distance_to_target) then
					bot_hero:CastAbilityOnTarget(chosen_target, abyssal_blade, 0)
					return THINK_RESULT_INSTANT
				else
					choose_new_target = true
				end
			end

			if CanCastAbility(blade_mail, current_mana)
				and not has_blade_mail
				and self.taking_very_high_damage then
				bot_hero:CastAbilityImmediately(blade_mail, 0)
				return THINK_RESULT_INSTANT
			end

			if CanCastAbility(shivas_guard, current_mana) then
				bot_hero:CastAbilityImmediately(shivas_guard, 0)
			end

			-- Cast satanic if low on health and in the fight mode
			if self.mode == MODE_FIGHT
				and health_percentage < SATANIC_USE_THRESHOLD
				and CanCastAbility(satanic, current_mana)
				and not bot_hero:IsAttackImmune()
				and not bot_hero:IsDisarmed() then
				bot_hero:CastAbilityImmediately(satanic, 0)
			end
		end

		-- Search in progressively smaller areas for ability targets
		if choose_new_target then
			search_radius = search_radius - 200
			chosen_target = self:GetAbilityTarget(potential_targets, search_radius)
		else
			break
		end
	end

	-- Handle spell immune enemies and fighting riki with the talent
	if self.fighting and use_items and not self.is_enemy_disabled then
		local result = THINK_RESULT_INSTANT

		if CanCastAbility(ethereal_blade, current_mana) then
			bot_hero:CastAbilityOnTarget(bot_hero, ethereal_blade, 0)
		elseif CanCastAbility(euls_scepter, current_mana) then
			bot_hero:CastAbilityOnTarget(bot_hero, euls_scepter, 0)
		elseif CanCastAbility(hurricane_pike, current_mana) then
			bot_hero:CastAbilityOnTarget(bot_hero, hurricane_pike, 0)
			self:EnterModeRun(3.0)
		elseif CanCastAbility(blade_mail, current_mana) then
			bot_hero:CastAbilityImmediately(blade_mail, 0)
		elseif CanCastAbility(shivas_guard, current_mana) then
			bot_hero:CastAbilityImmediately(shivas_guard, 0)
		-- This is here for when the bot is attacking creeps while playing versus a riki who has the
		-- talent
		elseif CanCastAbility(satanic, current_disable)
			and not bot_hero:IsAttackImmune()
			and not bot_hero:IsDisarmed() then
			bot_hero:CastAbilityImmediately(satanic, 0)
		else
			result = THINK_RESULT_NONE
		end

		return result
	end

	return THINK_RESULT_NONE
end


-- Think function for the `run` mode
function BotController:ThinkModeRun()
	local think_result = self:ThinkAbilities()
	if think_result == THINK_RESULT_NON_INSTANT then
		self:OnCastAbility(false)
		return
	elseif think_result == THINK_RESULT_INSTANT then
		self:OnCastAbility(true)
	end

	-- Check for ability area effects and avoid them
	self:CheckOtherAbilities()
	for i,entity in pairs(Entities:FindAllByName("npc_dota_thinker")) do
		local new_run_time = self:CheckThinkerEntity(entity)

		if new_run_time then
			self.minimum_run_time = new_run_time
		end
	end

	if self.always_fight then
		self:EnterModeFight()
		return
	end

	if self:IsCastingAbility() then
		return
	end

	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)
	self:UpdatePositionGoal()

	if self.position_goal
		and not self.hold_position
		and not self:IsCastingAbility()
		and not IsTaunted(bot_hero)
		and not IsFeared(bot_hero) then
		bot_hero:MoveToPosition(self.position_goal)
	end
end


-- Think function for the `fight` mode
function BotController:ThinkModeFight()
	local think_result = self:ThinkAbilities()
	if think_result == THINK_RESULT_NON_INSTANT then
		self:OnCastAbility(false)
		return
	elseif think_result == THINK_RESULT_INSTANT then
		self:OnCastAbility(true)
	end

	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	-- Decide whether to switch back to the running mode
	if bot_hero:GetAbilityByIndex(5):GetCooldownTimeRemaining() > REINCARNATION_AGHANIM_DURATION then
		if self.taking_very_high_damage and not self.always_fight then
			self:EnterModeRun(MINIMUM_RUN_TIME)
			return
		end
	end

	local num_enemies = 0
	local enemy_positions = self:GetPotentialAttackTargets(bot_hero:GetHealthDeficit() > FIGHT_NEUTRALS_HP_THRESHOLD)

	for i,enemy in pairs(enemy_positions) do
		num_enemies = num_enemies + 1
	end

	if num_enemies == 0 and not self.always_fight then
		self:EnterModeRun(0)
		return
	end

	local attack_target = self:GetAttackTarget()

	if self:IsCastingAbility() then
		return
	end

	if not IsTaunted(bot_hero) and not IsFeared(bot_hero) then
		if self.position_goal and not self.hold_position then
			bot_hero:MoveToPosition(self.position_goal)
		elseif attack_target then
			bot_hero:Interrupt()
			bot_hero:MoveToTargetToAttack(attack_target)
		elseif self.hold_position then
			bot_hero:Hold()
		end
	end

	if attack_target then
		self.attack_target = attack_target
	else
		self.attack_target = nil
	end
end


-- Updates the bot's position goal
function BotController:UpdatePositionGoal()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	self.minimum_run_time = self.minimum_run_time - THINK_INTERVAL

	-- Get dangerous visible enemy positions and count
	local num_enemies = 0
	local potential_positions = self:GetPotentialAttackTargets(bot_hero:GetHealthDeficit() > FIGHT_NEUTRALS_HP_THRESHOLD)
	local enemy_positions = {}

	for i,enemy in pairs(potential_positions) do
		num_enemies = num_enemies + 1

		-- Don't consider neutral positions when running away
		if not enemy:GetClassname() == "npc_dota_creep_neutral" then
			enemy_positions[i] = enemy:GetAbsOrigin()
		end
	end

	-- If no enemies are visible and the bot is not fighting, go stand at one of the idle points
	-- Also lock the position so it doesn't change until something new happens
	if num_enemies == 0 and not self.fighting then
		if not self.lock_position_goal then
			self.lock_position_goal = true
			self.position_goal = GetRandomIdlePoint()
		end
		return
	else
		self.lock_position_goal = false
	end

	-- Decide whether to switch back to fighting mode
	local switch_mode = false
	if num_enemies > 0 then
		if bot_hero:GetAbilityByIndex(5):GetCooldownTimeRemaining() < REINCARNATION_AGHANIM_DURATION then
			switch_mode = true
		else
			switch_mode = not self.taking_very_high_damage
		end
	end

	-- If `minimum_run_time` was set, wait that long before exiting this mode
	if switch_mode and self.minimum_run_time <= 0.0 then
		self:EnterModeFight()
		return
	end

	-- Variables to store whether there is a dangerous unit in each quadrant around the bot

	-- The quadrants centered around the bot
	local bot_position = bot_hero:GetAbsOrigin()
	local bot_quadrants = GetEnemyQuadrants(bot_position, enemy_positions)

	local left = bot_quadrants["bl"] or bot_quadrants["tl"]
	local right = bot_quadrants["br"] or bot_quadrants["tr"]
	local top = bot_quadrants["tl"] or bot_quadrants["tr"]
	local bottom = bot_quadrants["bl"] or bot_quadrants["br"]

	local closest_escape_point = GetClosestEscapePoint(bot_position)

	local chosen_escape_point = nil
	local chosen_point_distance = nil

	-- Updates the chosen escape point if the provided one is closer to the bot
	local update_escape_point = function(new_escape_point)
		if not new_escape_point then
			return
		end

		local new_point_distance = (new_escape_point - bot_position):Length2D()

		-- Use the first escape point found
		if (not chosen_escape_point) then
			chosen_escape_point = new_escape_point
			chosen_point_distance = new_point_distance
		-- If a closer point is found, interpolate towards it
		elseif new_point_distance < chosen_point_distance then
			chosen_escape_point = Interpolate(chosen_escape_point, new_point_distance, POSITION_GOAL_INTERPOLATION_AMOUNT)
			chosen_escape_point = chosen_escape_point + RandomVector(POSITION_GOAL_RANDOMNESS)
			chosen_point_distance = (chosen_escape_point - bot_position):Length2D()
		end
	end

	if bottom then
		local compare = function(a, b)
			if (b.y < bot_position.y) or (b == closest_escape_point) then
				return
			else
				return IsCloser(a, b, bot_position)
					and math.abs(b.y - bot_position.y) > math.abs(bot_position.y - closest_escape_point.y)
			end
		end

		update_escape_point(MaxBy(ESCAPE_POINTS, compare))
	end

	if top then
		local compare = function(a, b)
			if (b.y > bot_position.y) or (b == closest_escape_point) then
				return
			else
				return IsCloser(a, b, bot_position)
					and math.abs(b.y - bot_position.y) > math.abs(bot_position.y - closest_escape_point.y)
			end
		end

		update_escape_point(MaxBy(ESCAPE_POINTS, compare))
	end

	if left then
		local compare = function(a, b)
			if (b.x < bot_position.x) or (b == closest_escape_point) then
				return
			else
				return IsCloser(a, b, bot_position)
					and math.abs(b.x - bot_position.x) > math.abs(bot_position.x - closest_escape_point.x)
			end
		end

		update_escape_point(MaxBy(ESCAPE_POINTS, compare))
	end

	if right then
		local compare = function(a, b)
			if (b.x > bot_position.x) or (b == closest_escape_point) then
				return
			else
				return IsCloser(a, b, bot_position)
					and math.abs(b.x - bot_position.x) > math.abs(bot_position.x - closest_escape_point.x)
			end
		end

		update_escape_point(MaxBy(ESCAPE_POINTS, compare))
	end

	if not chosen_escape_point then
		local reached_position = (not self.position_goal)
			or (bot_position - self.position_goal):Length2D() < POSITION_GOAL_RADIUS

		if reached_position and not self.lock_position_goal then
			self.position_goal = GetRandomEscapePoint()
			self.lock_position_goal = true
			return
		end
	else
		self.lock_position_goal = false
	end

	if chosen_escape_point and not self.lock_position_goal then
		self.position_goal = chosen_escape_point
	end
end


-- Returns a list of visible enemies that should be considered targets to attack
function BotController:GetPotentialAttackTargets(include_neutrals)
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)
	local enemies = {}

	local entity = Entities:First()

	while entity do
		if entity.IsAlive and entity:IsAlive()
			and bot_hero:CanEntityBeSeenByMyTeam(entity)
			and entity.GetHealth
			and entity.GetTeamNumber and (entity:GetTeamNumber() ~= bot_hero:GetTeamNumber())
			-- To exclude the special entities like neutral camp dummies
			and entity:GetMaxHealth() > 1
			and entity:GetName() ~= "ent_dota_shop"
			and entity:GetClassname() ~= "player" then
			if entity:GetClassname() == "npc_dota_creep_neutral" then
				if include_neutrals then
					table.insert(enemies, entity)
				end
			else
				table.insert(enemies, entity)
			end
		end
		entity = Entities:Next(entity)
	end

	return enemies
end


-- Returns a list of visible entities that should be considered targets to use abilities on
-- Some of these entities may be allies so they should be filtered out by the caller of this
-- function
function BotController:GetPotentialAbilityTargets()
	local player_hero_name = PlayerResource:GetSelectedHeroEntity(self.player_id):GetName()
	local enemies = Entities:FindAllByName(player_hero_name)
	local bears = Entities:FindAllByName("npc_dota_lone_druid_bear")

	for i,bear in pairs(bears) do
		table.insert(enemies, bear)
	end

	return enemies
end


-- Returns the highest priority target to attack
-- Priority from highest to lowest:
-- - Dropped items
-- - Summoned units (lowest HP to highest)
-- - Heroes (priority varies depending on the enemy hero)
function BotController:GetAttackTarget()
	TYPE_NEUTRAL = 0
	TYPE_NPC = 1
	TYPE_SUMMON = 2

	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)
	local bot_position = bot_hero:GetAbsOrigin()
	local player_hero_name = PlayerResource:GetSelectedHeroEntity(self.player_id):GetName()

	local result = nil
	local result_type = TYPE_NPC

	-- Comparison function for sorting hero targets
	local compare_distance = function(a, b)
		return (a:GetAbsOrigin() - bot_position):Length2D() < (b:GetAbsOrigin() - bot_position):Length2D()
	end
	local compare = compare_distance

	if player_hero_name == "npc_dota_hero_phantom_lancer" then
		-- Focus the highest health hero (which tends to be the real phantom lancer)
		compare = function(a, b)
			return a:GetHealth() >= b:GetHealth()
		end
	elseif illusion_heroes[player_hero_name] then
		-- Focus the lowest health hero
		compare = function(a, b)
			return a:GetHealth() <= b:GetHealth()
		end
	elseif player_hero_name == "npc_dota_hero_arc_warden" then
		-- Focus the real arc warden, falling back to the default compare function if there are
		-- multiple arc wardens (such as from manta style)
		compare = function(a, b)
			if a:HasModifier("modifier_arc_warden_tempest_double") then
				return false
			elseif b:HasModifier("modifier_arc_warden_tempest_double") then
				return true
			else
				return compare_distance(a, b)
			end
		end
	end

	local entity = Entities:First()
	local ward_names = {
		["npc_dota_ignis_fatuus"] = true,
		["npc_dota_zeus_cloud"] = true,
		-- Pugna ward and phoenix supernova
		["npc_dota_base_additive"] = true,
		["npc_dota_venomancer_plagueward"] = true,
		["npc_dota_shadowshaman_serpentward"] = true,
		["npc_dota_clinkz_skeleton_archer"] = true,
		["npc_dota_unit_undying_tombstone"] = true,
		["npc_dota_lone_druid_bear"] = true,
		["npc_dota_rattletrap_cog"] = true,
		["npc_dota_techies_mines"] = true,
	}

	-- Comparison function for sorting summoned unit targets
	local compare_summons = function(a, b)
		local b_name = b:GetName()
		-- Give higher priority to ward units (still sort clinkz archers though)
		if ward_names[b_name] and b_name ~= "npc_dota_clinkz_skeleton_archer" then
			return false
		end

		return a:GetHealth() < b:GetHealth()
	end

	-- If certain entities are found (such as riki smoke screen) run away for this amount of time
	local minimum_run_time = nil

	if bot_hero:HasModifier("modifier_cold_feet") then
		local ability_radius = 740
		minimum_run_time = GetMinimumRunTime(ability_radius, bot_hero:GetBaseMoveSpeed())
	elseif bot_hero:HasModifier("modifier_medusa_stone_gaze_slow")
		or bot_hero:HasModifier("modifier_medusa_stone_gaze_facing") then
		minimum_run_time = 3.0
	elseif player_hero_name == "npc_dota_hero_nevermore" then
		local player_hero = PlayerResource:GetSelectedHeroEntity(self.player_id)

		-- If shadow fiend is channelling requiem of souls nearby, run away
		if bot_hero:CanEntityBeSeenByMyTeam(player_hero)
			and player_hero:GetAbilityByIndex(5):IsInAbilityPhase()
			and (bot_hero:GetAbsOrigin() - player_hero:GetAbsOrigin()):Length2D() < 300 then
			local cast_time = 1.67
			minimum_run_time = cast_time + 0.5
		end
	elseif player_hero_name == "npc_dota_hero_tiny" then
		local player_hero = PlayerResource:GetSelectedHeroEntity(self.player_id)

		if bot_hero:CanEntityBeSeenByMyTeam(player_hero)
			and player_hero:HasModifier("modifier_tiny_tree_channel") then
				local channel_time = 2.4
				minimum_run_time = channel_time + 0.5
		end
	end

	-- Reset each time so it is not permanent
	self.always_fight = false
	self.position_goal_from_thinker = false

	self:CheckOtherAbilities()
	while entity do
		-- Detect ability areas and avoid them
		if entity:GetClassname() == "npc_dota_thinker" then
			local new_run_time = self:CheckThinkerEntity(entity)

			if new_run_time then
				minimum_run_time = new_run_time
			end
		end

		if entity.IsAlive and entity:IsAlive() and bot_hero:CanEntityBeSeenByMyTeam(entity) then
			if entity:GetClassname() == "dota_item_drop" then
				return entity
			end

			local distance = (entity:GetAbsOrigin() - bot_hero:GetAbsOrigin()):Length2D()
			local in_attack_range = distance <= MELEE_ATTACK_RANGE

			-- If holding position, don't attack if it means moving
			if not self.hold_position or (self.hold_position and in_attack_range) then
				-- Only attack enemies
				if entity.GetTeamNumber and (entity:GetTeamNumber() ~= bot_hero:GetTeamNumber()) then
					local name = entity:GetName()
					-- Summoned units
					if entity.IsSummoned
						and (entity:IsSummoned() or ward_names[name])
						and not entity:IsAttackImmune()
						and not entity:IsInvulnerable() then
						if result_type == TYPE_SUMMON then
							if compare_summons(entity, result) then
								result = entity
							end
						else
							result = entity
							result_type	= TYPE_SUMMON
						end
					-- Heroes, with priority given by the `compare` function
					elseif entity.IsHero and entity:IsHero() and not entity:IsAttackImmune() and not entity:IsInvulnerable() then
						if result_type == TYPE_NPC then
							if not result or compare(entity, result) then
								result = entity
							end
						elseif result_type == TYPE_NEUTRAL then
							result = entity
							result_type = TYPE_NPC
						end
					-- Other NPCs such as neutrals
					elseif entity.IsHero and (entity:GetMaxHealth() > 1) and not result
						and not entity:IsAttackImmune() and not entity:IsInvulnerable()
						and entity:GetName() ~= "npc_dota_thinker" then
						result = entity
						result_type = TYPE_NEUTRAL
					end
				end
			end
		end

		entity = Entities:Next(entity)
	end

	-- Handles when a thinker causing the position goal to be set dies before the position goal is
	-- unset
	if self.position_goal and not self.position_goal_from_thinker then
		self.position_goal = nil
	end

	if minimum_run_time and not self.always_fight then
		self:EnterModeRun(minimum_run_time)
		return nil
	end

	return result
end


-- Checks the provided thinker entity and takes actions based on its modifiers and position
-- Returns a minimum run time value to be used with `BotController:EnterModeRun`
function BotController:CheckThinkerEntity(entity)
	-- Modifiers that mean a thinker is for an ability that the bot should run from
	-- Values are the radius of the ability used to detect whether the bot is in the abiltity effect
	-- zone
	thinker_modifiers = {
		["modifier_skywrath_mage_mystic_flare"] = 170,
		["modifier_riki_smoke_screen_thinker"] = 325,
		["modifier_viper_nethertoxin_thinker"] = 380,
		["modifier_disruptor_static_storm_thinker"] = 450,
		["modifier_abyssal_underlord_firestorm_thinker"] = 400,
		["modifier_alchemist_acid_spray_thinker"] = 625,
		["modifier_shredder_chakram_thinker"] = 200,
		-- This is approximate and doesn't take into account whether the talent is skilled
		["modifier_monkey_king_fur_army_thinker"] = 1200,
		["modifier_ancient_apparition_ice_vortex_thinker"] = 275,
		["modifier_enigma_midnight_pulse_thinker"] = 550,
	}

	-- These abilities are not circles so just run for a fixed duration
	non_circle_modifiers = {
		["modifier_elder_titan_earth_splitter_thinker"] = 3.0,
		["modifier_jakiro_macropyre"] = 3.0,
	}

	-- Modifiers than mean an thinker is for an ability that acts as an arena that has a penalty for
	-- leaving (such as arena of blood and dream coil)
	thinker_arena_modifiers = {
		["modifier_mars_arena_of_blood_thinker"] = 550,
		["modifier_dream_coil_thinker"] = 600,
	}

	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)
	local minimum_run_time = nil

	for i,modifier in pairs(entity:FindAllModifiers()) do
		local modifier_name = modifier:GetName()
		local ability_radius = thinker_modifiers[modifier_name]
		local fixed_run_time = non_circle_modifiers[modifier_name]
		if ability_radius then
			if (bot_hero:GetAbsOrigin() - entity:GetAbsOrigin()):Length2D() < ability_radius then
				-- Run away for what should be enough time to escape the ability area
				minimum_run_time = GetMinimumRunTime(ability_radius, bot_hero:GetBaseMoveSpeed())
			end
		elseif fixed_run_time then
			minimum_run_time = fixed_run_time
		elseif modifier_name == "modifier_kunkka_torrent_thinker" then
			local ability_radius = 325
			minimum_run_time = GetMinimumRunTime(ability_radius, bot_hero:GetBaseMoveSpeed())
		elseif modifier_name == "modifier_arc_warden_magnetic_field_thinker_evasion" then
			local ability_radius = 300
			local position = entity:GetAbsOrigin()
			local is_in_field = (position - bot_hero:GetAbsOrigin()):Length2D() < ability_radius

			-- While not in the magnetic field and the attack target is in it, walk towards it
			-- Doesn't handle magnetic fields at cliffs and map edges
			if not is_in_field
				and self.attack_target
				and not self.attack_target:IsNull()
				and self.attack_target:HasModifier("modifier_arc_warden_magnetic_field_evasion") then
				self.position_goal_from_thinker = true
				self.position_goal = position
			else
				self.position_goal = nil
			end
		else
			local ability_radius = thinker_arena_modifiers[modifier_name]

			if ability_radius then
				if (entity:GetAbsOrigin() - bot_hero:GetAbsOrigin()):Length2D() < ability_radius then
					-- Don't run if in an arena
					self.always_fight = true
				end
			end
		end
	end

	return minimum_run_time
end


-- Returns the highest priority target to cast disabling spells on
-- Only targets heroes, clones, and spirit bears, and chooses the target with the highest DPS if
-- there are multiple
function BotController:GetAbilityTarget(entities, max_radius)
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)
	local player_hero_name = PlayerResource:GetSelectedHeroEntity(self.player_id):GetName()
	local bot_evasion = self.bot_evasion

	if bot_hero:HasModifier("modifier_bloodthorn_debuff") then
		bot_evasion = 0
	end

	local result = nil
	local result_dps = nil
	local result_distance = nil

	for i,entity in pairs(entities) do
		local distance = (bot_hero:GetAbsOrigin() - entity:GetAbsOrigin()):Length2D()

		if entity:IsAlive()
			and bot_hero:CanEntityBeSeenByMyTeam(entity)
			and entity:GetTeamNumber() ~= bot_hero:GetTeamNumber()
			and distance <= max_radius
			and not entity:IsUnselectable()
			and not entity:IsMagicImmune() then

			if entity:IsDisarmed()
				or entity:IsStunned()
				or entity:IsInvulnerable()
				or entity:IsAttackImmune()
				or entity:IsHexed() then
				self.is_enemy_disabled = true
			else
				local dps = GetDPS(entity, bot_evasion)

				if not result or ((dps / result_dps) > GREATER_DPS_THRESHOLD) then
					result = entity
					result_dps = dps
					result_distance = distance

					if self.is_enemy_disabled then
						self:OnEnemyNoLongerDisabled()

						self.is_enemy_disabled = false
					end
				elseif (math.abs(dps - result_dps) < SIMILAR_DPS_THRESHOLD) then
					if distance < result_distance then
						result = entity
						result_dps = dps
						result_distance = distance

						if self.is_enemy_disabled then
							self:OnEnemyNoLongerDisabled()
							self.is_enemy_disabled = false
						end
					end
				end
			end
		end
	end

	return result
end


-- Returns whether the bot is casting an ability
function BotController:IsCastingAbility()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	return bot_hero:GetCurrentActiveAbility() or self.cast_point > 0
end


-- Triggered when an ability or item is used
function BotController:OnCastAbility(is_instant)
	-- Wait GLOBAL_ABILITY_COOLDOWN seconds between each cast
	self.global_ability_cooldown = GLOBAL_ABILITY_COOLDOWN
	-- Set the cast point if an instant spell was cast to the time taken to turn 180 degrees
	-- This is not entirely accurate but it works well enough
	if is_instant then
		self.cast_point = 0.188
	end
end


-- Triggered when the current ability target is no longer disabled
function BotController:OnEnemyNoLongerDisabled()
	self.global_ability_cooldown = GLOBAL_ABILITY_COOLDOWN
end


-- Checks whether the bot is standing near a dangerous ability and, if so, runs away to escape it
function BotController:CheckOtherAbilities()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)
	local player_hero = PlayerResource:GetSelectedHeroEntity(self.player_id)

	-- Radius is doubled because sand king may stand on the edge
	local radius = 650 * 2

	if player_hero:GetName() == "npc_dota_hero_sand_king"
		and player_hero:HasModifier("modifier_sandking_sand_storm")
		and (player_hero:GetAbsOrigin() - bot_hero:GetAbsOrigin()):Length2D() < radius
		and not self.always_fight then
		local minimum_run_time = GetMinimumRunTime(radius, bot_hero:GetBaseMoveSpeed())
		if self.mode == MODE_RUN then
			self.minimum_run_time = minimum_run_time
		elseif self.mode == MODE_FIGHT then
			self:EnterModeRun(minimum_run_time)
		end
	end

	local static_link_player = player_hero:FindModifierByName("modifier_razor_static_link")
	local static_link_bot = bot_hero:FindModifierByName("modifier_razor_static_link_debuff")

	if static_link_player and static_link_bot then
		local minimum_run_time = 2.0

		if self.mode == MODE_RUN then
			self.minimum_run_time = minimum_run_time
		elseif self.mode == MODE_FIGHT then
			self:EnterModeRun(minimum_run_time)
		end
	end
end


-- For each of the four quadrants centered at the provided location, returns whether an enemy lies
-- in it
function GetEnemyQuadrants(center, enemy_positions)
	local quadrants = {
		bl = false,
		br = false,
		tl = false,
		tr = false,
	}

	local center_x = center.x
	local center_y = center.y

	for i,position in pairs(enemy_positions) do
		if position.x < center_x then
			if position.y < center_y then
				quadrants.bl = true
			else
				quadrants.tl = true
			end
		else
			if position.y < center_y then
				quadrants.br = true
			else
				quadrants.tr = true
			end
		end
	end

	return quadrants
end


-- Returns a random point in IDLE_POINTS
function GetRandomIdlePoint()
	return IDLE_POINTS[RandomInt(1, 4)]
end


-- Returns a random point in ESCAPE_POINTS
function GetRandomEscapePoint()
	return ESCAPE_POINTS[RandomInt(1, 6)]
end


-- Returns the closest point in ESCAPE_POINTS to the provided position
function GetClosestEscapePoint(position)
	local closest = nil
	local distance = nil

	for i, point in pairs(ESCAPE_POINTS) do
		local point_distance = (point - position):Length2D()
		if not distance then
			closest = point
			distance = point_distance
		else
			if point_distance < distance then
				closest = point
				distance = point_distance
			end
		end
	end

	return closest
end


-- Returns the maximum value of a table using a comparison function
-- The first argument passed to the function is nil until the function returns `true` for the first
-- time
function MaxBy(t, fn)
	local length = #t
	if length == 0 then
		return nil
	end

	local value = nil
	for i=1,length do
		if fn(value, t[i]) then
			value = t[i]
		end
	end

	return value
end


-- Returns whether `b` is closer to `point` than `a`
-- Returns true if `a` is nil
function IsCloser(a, b, point)
		return (not a) or ((a - point):Length2D() > (b - point):Length2D())
end


-- Interpolates from `a` to `b` by `amount` (0 to 1)
function Interpolate(a, b, amount)
	return a + ((b - a) * amount)
end


-- Returns the average expected attack damage per second of the unit before mitigations
function GetDPS(entity, victim_evasion)
	local damage = (entity:GetBaseDamageMin() + entity:GetBaseDamageMax()) / 2
	local inverse_crit_daedalus = 1
	local inverse_crit_crystalys = 1
	local accuracy = 0

	for i,modifier in pairs(entity:FindAllModifiers()) do
		local ability = modifier:GetAbility()

		if ability then
			local modifier_damage = ability:GetSpecialValueFor("bonus_damage")

			if modifier_damage then
				damage = damage + modifier_damage
			end

			local ability_name = ability:GetAbilityName()

			if ability_name == "item_greater_crit" then
				inverse_crit_daedalus = inverse_crit_daedalus * INVERSE_DAEDALUS_CRIT_CHANCE
			elseif ability_name == "item_lesser_crit" then
				inverse_crit_crystalys = inverse_crit_crystalys * INVERSE_CRYSTALYS_CRIT_CHANCE
			elseif ability_name == "item_monkey_king_bar" then
				accuracy = 0.75
			end
		end
	end

	local crit_chance_daedalus = 1 - inverse_crit_daedalus
	-- Multiplied by inverse of daedalus crit chance because greater crit multipliers take priority
	local crit_chance_crystalys = (1 - inverse_crit_crystalys) * inverse_crit_daedalus

	local extra_damage_daedalus = (DAEDALUS_CRIT_MULTIPLIER - 1) * crit_chance_daedalus
	local extra_damage_crystalys = (CRYSTALYS_CRIT_MULTIPLIER - 1) * crit_chance_crystalys
	local damage_multiplier_crit = (1 + extra_damage_daedalus) * (1 + extra_damage_crystalys)

	-- Effective damage multiplier from evasion
	local damage_multiplier_evasion = 1 - (victim_evasion * (1 - accuracy))

	return entity:GetAttacksPerSecond() * damage * damage_multiplier_evasion * damage_multiplier_crit
end


-- Returns how long the bot should run for to escape an ability with the provided radius
function GetMinimumRunTime(ability_radius, move_speed)
	local result = ability_radius / move_speed
	-- Accounts for turn speed of the bot
	return result + 0.5
end


-- Returns whether to try to cast the provided ability
function ShouldCastAbility(ability, distance_to_target)
	local caster = ability:GetCaster()
	local cast_range = ability:GetCastRange()

	-- If casting requires walking and the bot is rooted, don't try casting the ability
	return not (caster:IsRooted() and distance_to_target > cast_range)
end


-- Returns whether the bot is able to cast the provided ability
function CanCastAbility(ability, current_mana)
	if not ability then
		return
	end

	if not current_mana then
		return false
	end

	return ability:IsCooldownReady() and (ability:GetManaCost(-1) <= current_mana)
end