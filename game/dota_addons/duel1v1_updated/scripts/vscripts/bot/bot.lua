-- Controls the logic for the add bot system and the bot

-- For each patch, update values for the following:
-- Heroes: Drow, PA, Bounty Hunter
-- Items: SNY, KNS, Halberd, Satanic, Sange, Butterfly, Talisman of Evasion
-- TODO: fill this in

BotController = {}
BotController.__index = BotController

require('bot/ui')
require('bot/shop')
require('bot/think')


-- Globals
global_bot_controller = nil

-- Constants
THINK_INTERVAL = 0.5
DEAD_THINK_INTERVAL = 0.1

MODE_RUN = 1
MODE_FIGHT = 2

-- The rate at which the bot learns from observations
-- 0 to never learn, 1 to learn instantly
-- Leaving it in the middle adds unpredictability to the bot, while still preventing abuse of the
-- bot with silly strategies
OBSERVATION_LEARN_RATE = 0.66

-- Active items that disable the enemy, like sheepstick and abyssal blade active
ITEM_BUILD_STRATEGY_OFFENSIVE = 1
-- Active items that protect the bot, like ethereal blade and eul's scepter
ITEM_BUILD_STRATEGY_DEFENSIVE_ACTIVE = 2
-- Passive items that protect the bot, like satanic and abyssal blade passive
ITEM_BUILD_STRATEGY_DEFENSIVE_PASSIVE = 3

HIGH_STATUS_RESISTANCE_THRESHOLD = 0.33
HIGH_EVASION_THRESHOLD = 0.4
HIGH_DISABLE_PERCENT_THRESHOLD = 0.5
HIGH_DISABLE_SINGLE_THRESHOLD = 5.0

INVERSE_SATANIC_STATUS_RESISTANCE = 0.7
-- Raw HP plus HP from strength
HEART_HEALTH = 400 + (20 * 45)
-- Base is 40, minus 10 from octarine, minus 7 from aghanim's scepter, minus 3 from reincarnation
-- time
EFFECTIVE_REINCARNATION_ULT_COOLDOWN = 20
-- The amount of time spent taking very high amounts of damage to be considered high damage burst
BURST_DURATION_THRESHOLD = 3.0
-- The multiplier for DPS required to kill the bot that should be considered a very high amount of
-- damage
VERY_HIGH_DAMAGE_THRESHOLD = 2.0


-- Bot implementation

function BotController:New(bot_id, player_id, settings)
	controller = {}
	setmetatable(controller, BotController)

	controller.bot_id = bot_id
	controller.player_id = player_id
	-- The current mode of the bot
	controller.mode = MODE_RUN
	-- Whether a round is in progress
	controller.in_round = false
	-- Whether the next round is the first one (to avoid performing end of round actions when the game starts)
	controller.first_round = true

	-- Observations about the opponent
	-- Keys are the names of the observations, values are the predicted probability that they will
	-- fit those observations next round. They are adapted over time using a simple algorithm. The
	-- values also include a flag that is set during the round if the enemy is observed to have the
	-- property/item.
	controller.observations = {
		-- General stats
		["high_status_resistance"]   = { 0.5, false },
		["high_evasion"]             = { 0.5, false },
		["high_disable_amount"]      = { 0.5, false },
		["high_consecutive_disable"] = { 0.5, false },
		["high_magic_damage"]        = { 0.5, false },
		["high_pure_damage"]         = { 0.5, false },
		["high_burst_damage"]        = { 0.5, false },
		-- Items
		["scythe_of_vyse"] 				   = { 0.5, false },
		["bloodthorn"] 				       = { 0.5, false },
		["mana_burn"] 				       = { 0.5, false },
		["ethereal_blade"] 		  		 = { 0.5, false },
		["abyssal_blade"] 		  		 = { 0.5, false },
		["force_staff"] 			  	   = { 0.5, false },
		["hurricane_pike"] 		  		 = { 0.5, false },
		["euls_scepter"] 				     = { 0.5, false },
		["dagon"] 				           = { 0.5, false },
		["rod_of_atos"] 			  	 	 = { 0.5, false },
		["nullifier"] 				       = { 0.5, false },
		["orchid_malevolence"] 		   = { 0.5, false },
		["refresher_orb"] 				   = { 0.5, false },
		["linkens_sphere"]           = { 0.5, false },
		["heavens_halberd"]          = { 0.5, false },
		["monkey_king_bar"]          = { 0.5, false },
		["satanic"]                  = { 0.5, false },
	}
	-- Counts how many seconds the bot has been disabled for during the current round
	controller.seconds_disabled = 0
	-- Counts how many seconds the longest disable lasted on the bot during the current round
	controller.longest_disable = 0
	-- Counts how many seconds the current stun on the bot has lasted
	controller.current_disable = 0
	-- Whether significant damage is being taken (defined as the damage per second needed to kill the
	-- bot in the time reincarnation is currently on cooldown)
	controller.fighting = false
	-- Whether a very high amount of damage is being taken (defined by multiple factors)
	controller.taking_very_high_damage = false
	-- The current amount of time a very high amount of damage has been taken for
	controller.current_burst_duration = 0
	-- The amount of time spent fighting during the current round
	controller.time_spent_fighting = 0
	-- Most recently observed HP value
	controller.previous_health = nil
	-- The total amount of damage taken during the current round
	controller.damage_taken = {
		["physical"] = 0,
		["magical"] = 0,
		["pure"] = 0,
	}
	-- The place the bot wants to travel to
	controller.position_goal = nil
	-- Whether to lock the position goal until unlocked when something new happens
	controller.lock_position_goal = false

  local args = {
    endTime = 0.1,
    callback = controller.Think,
  }
	Timers:CreateTimer("bot_think", args, controller)

	return controller
end


-- Resets the bot controller to its default state
function BotController:Reset()
	-- Remove the previous think timer
	Timers:RemoveTimer("bot_think")
	self = BotController:New(self.bot_id, self.player_id, self.settings)
end


-- Updates the chances for each observation
function BotController:UpdateObservationChances()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	-- Calculate whether the high_disable_amount flag should be set
	local disable_ratio = 0
	if self.time_spent_fighting ~= 0 then
		disable_ratio = self.seconds_disabled / self.time_spent_fighting
	end

	if disable_ratio > HIGH_DISABLE_PERCENT_THRESHOLD or self.longest_disable > HIGH_DISABLE_SINGLE_THRESHOLD then
		self.observations["high_disable_amount"][2] = true
	end

	-- Calculate whether the high_consecutive_disable flag should be set
	if self.longest_disable > HIGH_DISABLE_SINGLE_THRESHOLD then
		self.observations["high_consecutive_disable"][2] = true
	end

	-- Calculate usefulness of various types of EHP-giving stats
	local total_damage = self.damage_taken["physical"] + self.damage_taken["magical"] + self.damage_taken["pure"]
	-- Percent of total damage caused by each type
	local percent_phys = self.damage_taken["physical"] / total_damage
	local percent_magic = self.damage_taken["magical"] / total_damage
	local percent_pure = self.damage_taken["pure"] / total_damage

	-- Current (base) stats
	local bot_armor = bot_hero:GetPhysicalArmorBaseValue()
	local current_phys_multiplier = GetPhysicalDamageMultiplier(bot_armor)
	local max_health = bot_hero:GetMaxHealth()

	-- Physical EHP multiplier if 15 armor is gained (from purchasing shiva's guard)
	-- Measured from base armor to not let current items influence it
	local ehp_multiplier_phys = current_phys_multiplier / GetPhysicalDamageMultiplier(bot_armor + 15)

	-- Magic EHP multiplier if 30% magic resistance is gained (from purchasing pipe of insight)
	local ehp_multiplier_magic = 1.3

	-- EHP multiplier if a heart of tarrasque is purchased
	local ehp_multiplier_raw_hp = (max_health + HEART_HEALTH) / max_health

	-- Proportional to physical damage taken and the EHP multiplier from armor
	local armor_usefulness = self.damage_taken["physical"] * ehp_multiplier_phys

	-- Proportional to magic damage taken and the EHP multiplier from magic resistance
	local magic_resistance_usefulness = self.damage_taken["magical"] * ehp_multiplier_magic

	-- Proportional to pure damage taken and the EHP multiplier from buying heart of tarrasque
	local raw_hp_usefulness = self.damage_taken["pure"] * ehp_multiplier_raw_hp

	-- Set observation flags for damage types
	if magic_resistance_usefulness > armor_usefulness then
		self.observations["high_magic_damage"][2] = true
	end

	if raw_hp_usefulness > magic_resistance_usefulness and raw_hp_usefulness > armor_usefulness then
		self.observations["high_pure_damage"][2] = true
		self.observations["high_magic_damage"][2] = false
	end

	-- Update observation chances
	for name,o in pairs(self.observations) do
		local current_chance = self.observations[name][1]
		if o[2] then
			-- Move OBSERVATION_LEARN_RATE percent of the way towards 0 or 1, depending on whether the
			-- observation was true the previous round
			self.observations[name][1] = current_chance + (1 - current_chance) * OBSERVATION_LEARN_RATE
		else
			self.observations[name][1] = current_chance * (1 - OBSERVATION_LEARN_RATE)
		end
	end
end


-- Returns a table containing observation predictions based on previous observations
function BotController:GetPredictedObservations()
	local predictions = {}

	for name,o in pairs(self.observations) do
		predictions[name] = false

		if o[1] > RandomFloat(0, 1) then
			predictions[name] = true
		end
	end

	return predictions
end


-- Resets the counters for how much damage of each type was taken
function BotController:ResetDamageCounts()
	self.damage_taken["physical"] = 0
	self.damage_taken["magical"] = 0
	self.damage_taken["pure"] = 0
end


-- Resets the counters for how long the bot has been disabled for
function BotController:ResetDisableCounts()
	self.seconds_disabled = 0
	self.longest_disable = 0
	self.current_disable = 0
end


-- Resets the flags that control the observation chance updates
function BotController:ResetObservationFlags()
	for name,o in pairs(self.observations) do
		print("observation '" .. name .. "': " .. tostring(o[1]) .. ", " .. tostring(o[2]))
		self.observations[name][2] = false
	end
end


-- Updates the observation flags for the enemy by looking at visible units
function BotController:GatherEnemyInfo()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	local player_hero_name = PlayerResource:GetSelectedHeroEntity(self.player_id):GetName()
	-- All enemy units that info should be gathered on
	local enemies = Entities:FindAllByName(player_hero_name)
	table.insert(enemies, Entities:FindByName(nil, "npc_dota_lone_druid_bear"))

	if player_hero_name == "npc_dota_hero_antimage" then
		self.observations["mana_burn"][2] = true
	end

	for i,entity in pairs(enemies) do
		if entity:GetTeam() ~= bot_hero:GetTeam() then
			if bot_hero:CanEntityBeSeenByMyTeam(entity) then
				-- 1 - status_resistance
				local inverse_status_resistance = 1
				-- 1 - evasion
				local inverse_evasion = 1

				if entity:HasModifier("modifier_spirit_breaker_bulldoze") then
					inverse_status_resistance = inverse_status_resistance * 0.3
				end

				if entity:HasModifier("modifier_omniknight_repel") then
					inverse_status_resistance = inverse_status_resistance * 0.5
				end

				-- Assume these heroes have some evasion from their talents/abilities because there is no
				-- reason to not use those talents
				if player_hero_name == "npc_dota_hero_phantom_assassin" then
					inverse_evasion = inverse_evasion * 0.5
				elseif player_hero_name == "npc_dota_hero_drow_ranger" then
					inverse_evasion = inverse_evasion * 0.75
				elseif player_hero_name == "npc_dota_hero_bounty_hunter" then
					inverse_evasion = inverse_evasion * 0.5
				elseif player_hero_name == "npc_dota_hero_brewmaster" then
					-- Probably better to just run from him instead of fighting
					-- inverse_evasion = inverse_evasion * 0.2
				elseif player_hero_name == "npc_dota_hero_tinker" then
					inverse_evasion = 0
				end

				for i=0,5 do
					local item = entity:GetItemInSlot(i)

					if item then
						-- Update information about the enemy's items
						local item_name = item:GetAbilityName()
						if item_name == "item_sheepstick" then
							self.observations["scythe_of_vyse"][2] = true

						elseif item_name == "item_bloodthorn" then
							self.observations["bloodthorn"][2] = true

						elseif item_name == "item_diffusal_blade" and player_hero_name == "npc_dota_hero_phantom_lancer" then
							self.observations["mana_burn"][2] = true

						elseif item_name == "item_ethereal_blade" then
							self.observations["ethereal_blade"][2] = true

						elseif item_name == "item_abyssal_blade" then
							self.observations["abyssal_blade"][2] = true

						elseif item_name == "item_force_staff" then
							self.observations["force_staff"][2] = true

						elseif item_name == "item_hurricane_pike" then
							self.observations["hurricane_pike"][2] = true

						elseif item_name == "item_cyclone" then
							self.observations["euls_scepter"][2] = true

						elseif item_name == "item_rod_of_atos" then
							self.observations["rod_of_atos"][2] = true

						elseif item_name == "item_nullifier" then
							self.observations["nullifier"][2] = true

						elseif item_name == "item_orchid" then
							self.observations["orchid_malevolence"][2] = true

						elseif item_name == "item_refresher" then
							self.observations["refresher_orb"][2] = true

						elseif item_name == "item_sphere" then
							self.observations["linkens_sphere"][2] = true

						elseif item_name == "item_heavens_halberd" then
							self.observations["heavens_halberd"][2] = true
							inverse_status_resistance = inverse_status_resistance * 0.86
							inverse_evasion = inverse_evasion * 0.75

						elseif item_name == "item_dagon"
								or item_name == "item_dagon_2"
								or item_name == "item_dagon_3"
								or item_name == "item_dagon_4"
								or item_name == "item_dagon_5" then
							self.observations["dagon"][2] = true

						elseif item_name == "item_monkey_king_bar" then
							self.observations["monkey_king_bar"][2] = true

						elseif item_name == "item_satanic" then
							self.observations["satanic"][2] = true

						elseif item_name == "item_satanic" then
							inverse_status_resistance = inverse_status_resistance * INVERSE_SATANIC_STATUS_RESISTANCE

						elseif item_name == "item_sange" then
							inverse_status_resistance = inverse_status_resistance * 0.88

						elseif item_name == "item_sange_and_yasha" or item_name == "item_kaya_and_sange" then
							inverse_status_resistance = inverse_status_resistance * 0.84

						elseif item_name == "item_butterfly" then
							inverse_evasion = inverse_evasion * 0.65

						elseif item_name == "item_talisman_of_evasion" then
							inverse_evasion = inverse_evasion * 0.85
						end
					end
				end

				-- Update other observation flags
				local status_resistance = 1 - inverse_status_resistance

				if status_resistance > HIGH_STATUS_RESISTANCE_THRESHOLD then
					self.observations["high_status_resistance"][2] = true
				end

				local evasion = 1 - inverse_evasion

				if evasion > HIGH_EVASION_THRESHOLD then
					self.observations["high_evasion"][2] = true
				end
			end
		end
	end
end


-- Returns the multiplier for the duration of status effects applied to the bot
function BotController:GetStatusDurationMultiplier()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)
	local multiplier = 1

	for i=0,5 do
		local item = bot_hero:GetItemInSlot(i)

		if item then
			local item_name = item:GetAbilityName()

			-- The bot never buys other items so this is all that needs to be checked
			if item_name == "item_satanic" then
				multiplier = multiplier * INVERSE_SATANIC_STATUS_RESISTANCE
			elseif item_name == "item_heavens_halberd" then
				multiplier = multiplier * 0.86
			end
		end
	end

	return multiplier
end
