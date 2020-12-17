-- Think functions for Wraith King


-- Active items that disable the enemy, like sheepstick and abyssal blade active
ITEM_BUILD_STRATEGY_OFFENSIVE = 1
-- Active items that protect the bot, like ethereal blade and eul's scepter
ITEM_BUILD_STRATEGY_DEFENSIVE_ACTIVE = 2
-- Passive items that protect the bot, like satanic and abyssal blade passive
ITEM_BUILD_STRATEGY_DEFENSIVE_PASSIVE = 3


function BotController:ThinkShopWraithKing()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)
	local player_hero = PlayerResource:GetSelectedHeroEntity(self.player_id)
	local player_hero_name = player_hero:GetName()
	local is_player_ranged = player_hero:IsRangedAttacker()
	local inverse_bot_evasion = 1

	local predictions = self:GetPredictedObservations()

	if self.first_round then
		-- Eat aghanim's scepter and moonshard on first round
		local moon_shard = bot_hero:AddItemByName("item_moon_shard")
    local player_index = 0
    bot_hero:CastAbilityOnTarget(bot_hero, moon_shard, player_index)

    bot_hero:AddItemByName("item_ultimate_scepter_2")
	end

	-- Items to be purchased
	local items = {}

	-- Core items
	table.insert(items, "item_octarine_core")

	local strategy = ITEM_BUILD_STRATEGY_OFFENSIVE

	-- Which item to purchase when passive defense is needed
	local defensive_item = "item_shivas_guard"
	if predictions["high_magic_damage"] then
		defensive_item = "item_pipe"
	elseif predictions["high_pure_damage"] then
		defensive_item = "item_heart"
	end

	-- Non-core items
	-- This is the default build

	local item_1 = "item_assault"
	local item_2 = defensive_item
	local item_3 = "item_ethereal_blade"
	local item_4 = "item_sheepstick"
	local item_5 = "item_abyssal_blade"
	local item_neutral = "item_spell_prism"

	local needs_status_resistance = false

	-- Halberd is a 5 effectively a 5 second disable for ranged heroes that rely on attacking
	if is_player_ranged and not predictions["high_magic_damage"] then
		item_5 = "item_heavens_halberd"
	end

	-- Status resistance prevents disabling strategies from working
	if predictions["high_status_resistance"] then
		strategy = ITEM_BUILD_STRATEGY_DEFENSIVE_ACTIVE
	end

	-- Heroes that have troublesome units can't be effectively disabled, therefore focus on
	-- defensive active items
	if illusion_heroes[player_hero_name]
		or player_hero_name == "npc_dota_hero_arc_warden"
		or player_hero_name == "npc_dota_hero_phantom_lancer"
		or player_hero_name == "npc_dota_hero_life_stealer"
		or player_hero_name == "npc_dota_hero_antimage" then
		strategy = ITEM_BUILD_STRATEGY_DEFENSIVE_ACTIVE
	end

	-- Nullifier just needs to be survived, which status resistance helps with. Then, the usual
	-- strategies apply
	if predictions["nullifier"] then
		needs_status_resistance = true
	end

	-- Try to get status resistance if the enemy uses a lot of disables
	if predictions["high_disable_amount"] or predictions["high_consecutive_disable"] then
		needs_status_resistance = true
	end

	if predictions["mana_burn"] or player_hero_name == "npc_dota_hero_riki" then
		strategy = ITEM_BUILD_STRATEGY_DEFENSIVE_PASSIVE
	end

	if strategy == ITEM_BUILD_STRATEGY_DEFENSIVE_ACTIVE then
		item_4 = "item_cyclone"
		item_5 = "item_hurricane_pike"
	elseif strategy == ITEM_BUILD_STRATEGY_DEFENSIVE_PASSIVE then
		if not predictions["mana_burn"] then
			item_3 = "item_satanic"
		end
		item_4 = defensive_item
		if predictions["high_status_resistance"] or predictions["high_evasion"] then
			item_5 = defensive_item
		end
	end

	-- MKB is unnecessary because the bot doesn't intend on killing the opponent
	-- Eul's scepter is more useful here
	if predictions["high_evasion"] then
		if item_4 == "item_cyclone" then
			item_4 = defensive_item
		else
			item_5 = "item_cyclone"
		end
	end

	-- If never attacking, assault cuirass is useless
	if strategy == ITEM_BUILD_STRATEGY_DEFENSIVE_ACTIVE or predictions["high_evasion"] then
		item_1 = "item_shivas_guard"
	end

	-- Replace euls/pike/abyssal with satanic if status resistance is needed
	if needs_status_resistance then
		item_5 = "item_satanic"
	end

	-- Blademail is effectively a 4.5 second disable versus heroes that can't attack during it
	if predictions["high_burst_damage"]
		and not predictions["satanic"]
		and not illusion_heroes[player_hero_name]
		and not (player_hero_name == "npc_dota_hero_life_stealer") then
		item_5 = "item_blade_mail"
	end

	-- Some rounds can cheesed with butterflies
	-- Only buy them if the enemy doesn't have high accuracy or true strike, and if they rely on
	-- attacking for damage
	if (not predictions["monkey_king_bar"])
		and (not predictions["bloodthorn"])
		and (not predictions["high_magic_damage"])
		-- If this is uncommented, butterflies will never be purchased vs silencer/OD, which would be
		-- suboptimal
		-- and not predictions["high_pure_damage"]
		and (not (player_hero_name == "npc_dota_hero_ember_spirit"))
		and (not (player_hero_name == "npc_dota_hero_mars"))
		and (not (player_hero_name == "npc_dota_hero_riki")) then
		item_2 = "item_butterfly"
		item_3 = "item_butterfly"

		inverse_bot_evasion = inverse_bot_evasion * INVERSE_BUTTERFLY_EVASION * INVERSE_BUTTERFLY_EVASION
	end

	if predictions["disruptor_cheat"] and player_hero_name == "npc_dota_hero_disruptor" then
		item_3 = "item_black_king_bar"
	end

	table.insert(items, item_1)
	table.insert(items, item_2)
	table.insert(items, item_3)
	table.insert(items, item_4)
	table.insert(items, item_5)
	table.insert(items, item_neutral)

	-- Buy items from the list
	local buy_items = function()
		for i=0,20 do
			local item = bot_hero:GetItemInSlot(i)

			if item then
				item:Destroy()
			end
		end
		for i,item in pairs(items) do
			bot_hero:AddItemByName(item)
		end
	end

	self.bot_evasion = 1 - inverse_bot_evasion

	-- Do it after a delay so the eaten moonshard doesn't interfere with item positions
	Timers:CreateTimer(0.5, buy_items)
end


function BotController:ThinkAbilitiesWraithKing()
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
		bot_hero:CastAbilityImmediately(black_king_bar, self.bot_id)
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
					bot_hero:CastAbilityOnTarget(chosen_target, wraithfire_blast, self.bot_id)
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
					bot_hero:CastAbilityOnTarget(chosen_target, heavens_halberd, self.bot_id)
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
					bot_hero:CastAbilityOnTarget(bot_hero, ethereal_blade, self.bot_id)
				else
					if ShouldCastAbility(ethereal_blade, distance_to_target) then
						bot_hero:CastAbilityOnTarget(chosen_target, ethereal_blade, self.bot_id)
					else
						bot_hero:CastAbilityOnTarget(bot_hero, ethereal_blade, self.bot_id)
					end
				end
				return THINK_RESULT_INSTANT
			end

			if CanCastAbility(scythe_of_vyse, current_mana) then
				if ShouldCastAbility(scythe_of_vyse, distance_to_target) then
					bot_hero:CastAbilityOnTarget(chosen_target, scythe_of_vyse, self.bot_id)
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
					bot_hero:CastAbilityOnTarget(bot_hero, euls_scepter, self.bot_id)
				else
					if ShouldCastAbility(euls_scepter, distance_to_target) then
						bot_hero:CastAbilityOnTarget(chosen_target, euls_scepter, self.bot_id)
					else
						bot_hero:CastAbilityOnTarget(bot_hero, euls_scepter, self.bot_id)
					end
				end
				return THINK_RESULT_INSTANT
			end

			if CanCastAbility(hurricane_pike, current_mana) then
				local self_cast_hurricane_pike = bot_hero:HasModifier("modifier_slark_pounce_leash")
				if self_cast_hurricane_pike then
					bot_hero:CastAbilityOnTarget(bot_hero, hurricane_pike, self.bot_id)
					self:EnterModeRun(3.0)
				else
					if ShouldCastAbility(hurricane_pike, distance_to_target) then
						bot_hero:CastAbilityOnTarget(chosen_target, hurricane_pike, self.bot_id)
						self:EnterModeRun(3.0)
						return THINK_RESULT_INSTANT
					else
						choose_new_target = true
					end
				end
			end

			if CanCastAbility(abyssal_blade, current_mana) then
				if ShouldCastAbility(abyssal_blade, distance_to_target) then
					bot_hero:CastAbilityOnTarget(chosen_target, abyssal_blade, self.bot_id)
					return THINK_RESULT_INSTANT
				else
					choose_new_target = true
				end
			end

			if CanCastAbility(blade_mail, current_mana)
				and not has_blade_mail
				and self.taking_very_high_damage then
				bot_hero:CastAbilityImmediately(blade_mail, self.bot_id)
				return THINK_RESULT_INSTANT
			end

			if CanCastAbility(shivas_guard, current_mana) then
				bot_hero:CastAbilityImmediately(shivas_guard, self.bot_id)
			end

			-- Cast satanic if low on health and in the fight mode
			if self.mode == MODE_FIGHT
				and health_percentage < SATANIC_USE_THRESHOLD
				and CanCastAbility(satanic, current_mana)
				and not bot_hero:IsAttackImmune()
				and not bot_hero:IsDisarmed() then
				bot_hero:CastAbilityImmediately(satanic, self.bot_id)
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
			bot_hero:CastAbilityOnTarget(bot_hero, ethereal_blade, self.bot_id)
		elseif CanCastAbility(euls_scepter, current_mana) then
			bot_hero:CastAbilityOnTarget(bot_hero, euls_scepter, self.bot_id)
		elseif CanCastAbility(hurricane_pike, current_mana) then
			bot_hero:CastAbilityOnTarget(bot_hero, hurricane_pike, self.bot_id)
			self:EnterModeRun(3.0)
		elseif CanCastAbility(blade_mail, current_mana) then
			bot_hero:CastAbilityImmediately(blade_mail, self.bot_id)
		elseif CanCastAbility(shivas_guard, current_mana) then
			bot_hero:CastAbilityImmediately(shivas_guard, self.bot_id)
		-- This is here for when the bot is attacking creeps while playing versus a riki who has the
		-- talent
		elseif CanCastAbility(satanic, current_disable)
			and not bot_hero:IsAttackImmune()
			and not bot_hero:IsDisarmed() then
			bot_hero:CastAbilityImmediately(satanic, self.bot_id)
		else
			result = THINK_RESULT_NONE
		end

		return result
	end

	return THINK_RESULT_NONE
end


function BotController:ThinkModeRunWraithKing()
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


function BotController:ThinkModeFightWraithKing()
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


function BotController:ThinkRoundStartWraithKing()
end