-- Think function for purchasing items and leveling abilities
function BotController:ThinkShop()
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

	-- Talents to level
	local abilities = { 7, 8, 10, 13 }

	-- Learn talents
	for i,ability_index in pairs(abilities) do
		bot_hero:UpgradeAbility(bot_hero:GetAbilityByIndex(ability_index))
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

	-- Buy items from the list
	local buy_items = function()
		for i=0,5 do
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