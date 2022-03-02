-- Think functions for Wisp


-- Attack build with massive DPS and lifesteal
ITEM_BUILD_STRATEGY_ATTACK = 1
-- Passive tank build relying on spirits, regen, and kiting
ITEM_BUILD_STRATEGY_MAGIC = 2


function BotController:ThinkShopWisp()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	if self.first_round then
		-- Eat aghanim's scepter and moonshard on first round
		local moon_shard = bot_hero:AddItemByName("item_moon_shard")
    bot_hero:CastAbilityOnTarget(bot_hero, moon_shard, self.bot_id)

    bot_hero:AddItemByName("item_ultimate_scepter_2")
	end

	-- Items to be purchased
	local items = {}

	local item_1 = nil
	local item_2 = nil
	local item_3 = nil
	local item_4 = nil
	local item_5 = nil
	local item_6 = nil
	local item_neutral = nil

	local strategy = ITEM_BUILD_STRATEGY_ATTACK

	if strategy == ITEM_BUILD_STRATEGY_ATTACK then
		item_1 = "item_assault"
		item_2 = "item_solar_crest"
		item_3 = "item_monkey_king_bar"
		item_4 = "item_satanic"
		item_5 = "item_satanic"
		item_6 = "item_greater_crit"
		item_neutral = "item_desolator_2"
	elseif strategy == ITEM_BUILD_STRATEGY_MAGIC then
		item_1 = "item_ethereal_blade"
		item_2 = "item_assault"
		item_3 = "item_shivas_guard"
		item_4 = "item_heart"
		item_5 = "item_octarine"
		item_6 = "item_sheepstick"
	end

	table.insert(items, item_1)
	table.insert(items, item_2)
	table.insert(items, item_3)
	table.insert(items, item_4)
	table.insert(items, item_5)
	table.insert(items, item_6)
	-- Neutral item
	table.insert(items, item_neutral)
	-- Backpack items
	table.insert(items, "item_demonicon")

	-- Buy items from the list and prepare backpack swaps for round start
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

		-- Swap items to use at round start
		bot_hero:SwapItems(NEUTRAL_ITEM_SLOT, 6)
	end

	-- Do it after a delay so the eaten moonshard doesn't interfere with item positions
	Timers:CreateTimer(0.5, buy_items)
end


function BotController:ThinkAbilitiesWisp()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	local is_muted = bot_hero:IsMuted()
	local is_silenced = bot_hero:IsSilenced()
	local health_percentage = bot_hero:GetHealth() / bot_hero:GetMaxHealth()
	local current_mana = bot_hero:GetMana()

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

	self:UpdateUnitHandles()

	if not is_silenced then
		if not bot_hero:HasModifier("modifier_wisp_tether") then
			local is_entity_closer = function(a, b)
				if (not a) or not a:IsAlive() then
					return true
				elseif (not b) or not b:IsAlive() then
					return false
				else
					return IsCloser(a:GetAbsOrigin(), b:GetAbsOrigin(), bot_hero:GetAbsOrigin())
				end
			end

			local tether = bot_hero:GetAbilityByIndex(0)
			local tether_target = MaxBy(self.melee_units, is_entity_closer)

			if not tether_target then
				tether_target = MaxBy(self.ranged_units, is_entity_closer)
			end

			if tether_target
				and tether_target:IsAlive()
				and CanCastAbility(tether, current_mana) then
				bot_hero:CastAbilityOnTarget(tether_target, tether, 0)

				return THINK_RESULT_INSTANT
			end
		end
	end

	-- TODO: replace with actual target
	local player_hero = PlayerResource:GetSelectedHeroEntity(self.player_id)
	local target_radius = (player_hero:GetAbsOrigin() - bot_hero:GetAbsOrigin()):Length2D()

	self:ThinkSpirits(target_radius)

	print("Abilities Wisp")
end


function BotController:ThinkModeRunWisp()
	print("Run Wisp")
end


function BotController:ThinkModeFightWisp()
	print("Fight Wisp")
end


function BotController:ThinkRoundStartWisp()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	self.move_spirits_in = false

	self:CastDemonicon()
	-- Swap neutral item back
	bot_hero:SwapItems(NEUTRAL_ITEM_SLOT, 6)
end


-- Casts demonicon
--
-- Does not check whether it is off cooldown, the bot is stunned, etc
function BotController:CastDemonicon()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	local demonicon = bot_hero:GetItemInSlot(NEUTRAL_ITEM_SLOT)

	bot_hero:CastAbilityImmediately(demonicon, self.bot_id)

	-- Set demonicon unit handles
	local melee_units = {}
	local ranged_units = {}

	for i, entity in pairs(Entities:FindAllByClassname("npc_dota_creep")) do
		if entity:GetTeam() == bot_hero:GetTeam() then
			local units_table = melee_units

			if entity:IsRangedAttacker() then
				units_table = ranged_units
			end

			table.insert(units_table, entity)
		end
	end

	self.melee_units = melee_units
	self.ranged_units = ranged_units
end


-- Updates handles to summoned units
function BotController:UpdateUnitHandles()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	local melee_units = {}
	local ranged_units = {}

	for i, entity in pairs(Entities:FindAllByClassname("npc_dota_creep")) do
		if entity:GetTeam() == bot_hero:GetTeam() then
			local units_table = melee_units

			if entity:IsRangedAttacker() then
				units_table = ranged_units
			end

			table.insert(units_table, entity)
		end
	end

	self.melee_units = melee_units
	self.ranged_units = ranged_units
end


-- Sets the target spirit radius and works to reach it
function BotController:ThinkSpirits(target_radius)
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)
	local current_radius = nil

	local spirits = {}

	for i, spirit in pairs(Entities:FindAllByClassname("npc_dota_wisp_spirit")) do
		if (spirit:GetTeam() == bot_hero:GetTeam()) then
			table.insert(spirits, spirit)
		end
	end

	for i, spirit in pairs(spirits) do
		current_radius = (spirit:GetAbsOrigin() - bot_hero:GetAbsOrigin()):Length2D()
		-- Getting the last spirit avoids counting dead ones for some reason
		-- break
	end

	local move_spirits_in = current_radius > target_radius

	if move_spirits_in ~= self.move_spirits_in then
		self.move_spirits_in = move_spirits_in

		local spirits_in = bot_hero:FindAbilityByName("wisp_spirits_in")

		bot_hero:CastAbilityImmediately(spirits_in, self.bot_id)
	end
end