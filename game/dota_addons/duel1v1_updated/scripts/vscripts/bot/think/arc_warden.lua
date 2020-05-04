-- Think functions for Arc Warden


-- Sneak up with invisibility/blink and use bloodthorn, sheepstick, etc to kill the enemy
ITEM_BUILD_STRATEGY_DISABLE = 1
-- Stack status resistance + lifesteal + armor to out-sustain the enemy
ITEM_BUILD_STRATEGY_TANK = 2
-- Generic right-click build
ITEM_BUILD_STRATEGY_GENERIC_PHYSICAL = 3
-- Generic magic damage build
ITEM_BUILD_STRATEGY_GENERIC_MAGIC = 4


function BotController:ThinkShopArcWarden()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	if self.first_round then
		-- Eat aghanim's scepter and moonshard on first round
		local moon_shard = bot_hero:AddItemByName("item_moon_shard")
    local player_index = 0
    bot_hero:CastAbilityOnTarget(bot_hero, moon_shard, player_index)

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
	local item_neutral = "item_ex_machina"

	local strategy = self:ChooseItemBuildStrategyArcWarden()
	self.strategy = strategy

	if strategy == ITEM_BUILD_STRATEGY_DISABLE then
		item_1 = "item_mjollnir"
		item_2 = "item_nullifier"
		item_3 = "item_sheepstick"
		item_4 = "item_butterfly"
		item_5 = "item_monkey_king_bar"
		item_6 = "item_bloodthorn"

		if self.observations["strong_invisibility"][1] then
			item_1 = "item_gem"
		end
	elseif strategy == ITEM_BUILD_STRATEGY_TANK then
		item_1 = "item_mjollnir"
		item_2 = "item_butterfly"
		item_3 = "item_monkey_king_bar"
		item_4 = "item_assault"
		item_5 = "item_satanic"
		item_6 = "item_satanic"

		if self.observations["strong_invisibility"][1] then
			item_1 = "item_gem"
		end
	elseif strategy == ITEM_BUILD_STRATEGY_GENERIC_PHYSICAL then
		item_1 = "item_butterfly"
		item_2 = "item_assault"
		item_3 = "item_greater_crit"
		item_4 = "item_mjollnir"
		item_5 = "item_hurricane_pike"
		item_6 = "item_sheepstick"

		if self.observations["strong_invisibility"][1] then
			item_1 = "item_gem"
		end
	elseif strategy == ITEM_BUILD_STRATEGY_GENERIC_MAGIC then
		item_1 = "item_bloodthorn"
		item_2 = "item_ethereal_blade"
		item_3 = "item_sheepstick"
		item_4 = "item_hurricane_pike"
		item_5 = "item_heart"
		item_6 = "item_octarine_core"

		if self.observations["strong_invisibility"][1] then
			item_1 = "item_gem"
		end
	end

	table.insert(items, item_1)
	table.insert(items, item_2)
	table.insert(items, item_3)
	table.insert(items, item_4)
	table.insert(items, item_5)
	table.insert(items, item_6)
	-- Items used at round start
	table.insert(items, "item_silver_edge")
	table.insert(items, "item_necronomicon_3")
	table.insert(items, "item_smoke_of_deceit")
	-- Neutral item
	table.insert(items, item_neutral)

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
		bot_hero:SwapItems(3, 6)
		bot_hero:SwapItems(4, 7)
		bot_hero:SwapItems(5, 8)
	end

	-- Do it after a delay so the eaten moonshard doesn't interfere with item positions
	Timers:CreateTimer(0.5, buy_items)
end


function BotController:ThinkAbilitiesArcWarden()
	print("Abilities ArcWarden")
end


function BotController:ThinkModeRunArcWarden()
	print("Run ArcWarden")
end


function BotController:ThinkModeFightArcWarden()
	print("Fight ArcWarden")
end


function BotController:ThinkRoundStartArcWarden()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	local rune_forge = bot_hero:GetAbilityByIndex(3)

	bot_hero:CastAbilityImmediately(rune_forge, 0)

	for i, rune in pairs(Entities:FindAllByClassname("dota_item_rune")) do
		bot_hero:PickupRune(rune)
	end

	local cast_cheese_items = function()
		local silver_edge = bot_hero:GetItemInSlot(3)
		local necronomicon = bot_hero:GetItemInSlot(4)
		local smoke_of_deceit = bot_hero:GetItemInSlot(5)

		bot_hero:CastAbilityImmediately(silver_edge, 0)
		bot_hero:CastAbilityImmediately(necronomicon, 0)
		bot_hero:CastAbilityImmediately(smoke_of_deceit, 0)

		-- Swap cheese items out
		bot_hero:SwapItems(3, 6)
		bot_hero:SwapItems(4, 7)
		bot_hero:SwapItems(5, 8)

		-- Set necronomicon unit handles
		for i, entity in pairs(Entities:FindAllByClassname("npc_dota_creep")) do
			if entity:GetTeam() == DOTA_TEAM_BADGUYS then
				local first_ability_name = entity:GetAbilityByIndex(0):GetAbilityName()

				if first_ability_name == "necronomicon_archer_purge" then
					self.necronomicon_archer = entity
				elseif first_ability_name == "necronomicon_warrior_mana_burn" then
					self.necronomicon_warrior = entity
				end
			end
		end
	end

	-- Cast items after picking up the rune
	Timers:CreateTimer(0.5, cast_cheese_items)
end


function BotController:ChooseItemBuildStrategyArcWarden()
	return RandomInt(1, 4)
end