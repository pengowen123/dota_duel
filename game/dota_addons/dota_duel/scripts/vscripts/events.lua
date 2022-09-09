-- This file contains all barebones-registered events and has already set up the passed-in parameters for your use.

function GameMode:OnDisconnect(keys)
	Timers:CreateTimer(0.1, function()
	  CustomGameEventManager:Send_ServerToAllClients("update_hero_lists", {})
	end)
end

function GameMode:OnGameRulesStateChange(keys)
	local new_state = GameRules:State_Get()

	if new_state == DOTA_GAMERULES_STATE_HERO_SELECTION then
	  -- Fetch player stats at the start so that they are available by the time the stats are displayed
	  -- Must be done after team selection is finished, so it is done here instead of in InitGameMode
	  UpdatePlayerStatsUI()
	elseif new_state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		if IsOneVsOneMap() then
			Timers:CreateTimer(0.1, ShuffleTeams)
		end
	end
end

-- An NPC has spawned somewhere in game.  This includes heroes
function GameMode:OnNPCSpawned(keys)
	Timers:CreateTimer(0.1, function()
		local entity = EntIndexToHScript(keys.entindex)

		-- Repeatedly check for entity if it hasn't been created yet
		if not entity then
			return 0.3
		end

		-- Prevent neutral creeps from getting stronger over time
		if entity.RemoveModifierByName then
			entity:RemoveModifierByName("modifier_neutral_upgrade")
		end

		-- Only level newly created NPCs
		if entity.GetLevel and entity:GetLevel() > 1 then
			return
		end

		if entity.IsRealHero and entity:IsRealHero() and not IsClone(entity) then
			LevelEntityToMax(entity)
			ClearInventory(entity)

		  local tp_scroll = CreateAndConfigureItem("item_tpscroll", entity)
		  tp_scroll:SetCurrentCharges(3)
		  entity:AddItem(tp_scroll)

		  CustomGameEventManager:Send_ServerToAllClients("rebuild_hero_lists", {})

			-- In case players don't have assigned heroes when rebuild_hero_lists is sent
			Timers:CreateTimer(0.5, function()
				CustomGameEventManager:Send_ServerToAllClients("update_hero_lists", {})
			end)
		end
	end)
end

-- An entity somewhere has been hurt.  This event fires very often with many units so don't do too many expensive
-- operations here
function GameMode:OnEntityHurt(keys)
	local hurt = EntIndexToHScript(keys.entindex_killed)
	if hurt.GetName then
		if global_bot_controller then
			if hurt:GetName() == "npc_dota_hero_skeleton_king" then
				if hurt:GetTeam() == DOTA_TEAM_BADGUYS then
					-- Update damage counters (not 100% accurate because damage type is not always provided,
					-- but it is good enough in most cases)
					local damage = keys.damage
					-- Percentage of magic damage taken that gets mitigated
					local bot_magic_resistance = hurt:GetMagicalArmorValue()
					local bot_armor = hurt:GetPhysicalArmorValue(false)
					-- Percentage of physical damage taken that gets mitigated
					local bot_physical_resistance = 1 - GetPhysicalDamageMultiplier(bot_armor)

					if keys.entindex_inflictor then
						local inflictor = EntIndexToHScript(keys.entindex_inflictor)
						local damage_type = inflictor:GetAbilityDamageType()

						if inflictor:IsItem() then
							-- Items are assumed to cause magical damage
							-- Blademail may cause physical damage to the bot but this should be negligible
							-- because the bot doesn't do much damage
							if bot_magic_resistance < 1 then
								local base_damage = damage / (1 - bot_magic_resistance)
								global_bot_controller.damage_taken["magical"] = global_bot_controller.damage_taken["magical"] + base_damage
							end
						else
							-- Reverse mitigations to get the base damage of the source
							if damage_type == DAMAGE_TYPE_PHYSICAL then
								local base_damage = damage / (1 - bot_physical_resistance)
								global_bot_controller.damage_taken["physical"] = global_bot_controller.damage_taken["physical"] + base_damage

							elseif damage_type == DAMAGE_TYPE_MAGICAL then
								local base_damage = damage / (1 - bot_magic_resistance)
								global_bot_controller.damage_taken["magical"] = global_bot_controller.damage_taken["magical"] + base_damage

							elseif damage_type == DAMAGE_TYPE_PURE then
								global_bot_controller.damage_taken["pure"] = global_bot_controller.damage_taken["pure"] + damage
							end
						end
					else
						-- If there is no inflictor, it is probably an auto-attack which is mostly physical damage
						local base_damage = damage / (1 - bot_physical_resistance)
						-- After each round, each entity takes their HP in damage with no inflictor, this filters that out
						if hurt:GetMaxHealth() == damage then
							return
						end
						global_bot_controller.damage_taken["physical"] = global_bot_controller.damage_taken["physical"] + base_damage
					end
				end
			end
		end
	end
end

-- An item was picked up off the ground
function GameMode:OnItemPickedUp(keys)
end

function GameMode:OnPlayerReconnect(keys)
	Timers:CreateTimer(0.1, function()
	  CustomGameEventManager:Send_ServerToAllClients("update_hero_lists", {})
	end)
end

-- An item was purchased by a player
function GameMode:OnItemPurchased(keys)
end

-- An ability was used by a player
function GameMode:OnAbilityUsed(keys)
	-- for k, v in pairs(keys) do
		-- print(k, v)
	-- end
end

-- A non-player entity (necro-book, chen creep, etc) used an ability
function GameMode:OnNonPlayerUsedAbility(keys)
end

-- A player changed their name
function GameMode:OnPlayerChangedName(keys)
end

-- A player leveled up an ability
function GameMode:OnPlayerLearnedAbility(keys)
end

-- A channelled ability finished by either completing or being interrupted
function GameMode:OnAbilityChannelFinished(keys)
end

-- A player leveled up
function GameMode:OnPlayerLevelUp(keys)
end

-- A player last hit a creep, a tower, or a hero
-- Disabled in internal/gamemode.lua
-- function GameMode:OnLastHit(keys)
-- end

-- A tree was cut down by tango, quelling blade, etc
function GameMode:OnTreeCut(keys)
end

-- A rune was activated by a player
function GameMode:OnRuneActivated (keys)
end

-- A player took damage from a tower
function GameMode:OnPlayerTakeTowerDamage(keys)
end

-- A player picked a hero
function GameMode:OnPlayerPickHero(keys)
end

-- A player killed another player in a multi-team context
function GameMode:OnTeamKillCredit(keys)
end

-- An entity died
function GameMode:OnEntityKilled( keys )
end



-- This function is called 1 to 2 times as the player connects initially but before they 
-- have completely connected
function GameMode:PlayerConnect(keys)
end

-- This function is called once when the player fully connects and becomes "Ready" during Loading
function GameMode:OnConnectFull(keys)
end

-- This function is called whenever illusions are created and tells you which was/is the original entity
function GameMode:OnIllusionsCreated(keys)
end

-- This function is called whenever an item is combined to create a new item
function GameMode:OnItemCombined(keys)
end

-- This function is called whenever an ability begins its PhaseStart phase (but before it is actually cast)
function GameMode:OnAbilityCastBegins(keys)
end

-- This function is called whenever a tower is killed
function GameMode:OnTowerKill(keys)
end

-- This function is called whenever a player changes there custom team selection during Game Setup 
function GameMode:OnPlayerSelectedCustomTeam(keys)
end

-- This function is called whenever an NPC reaches its goal position/target
function GameMode:OnNPCGoalReached(keys)
end

-- This function is called whenever any player sends a chat message to team or All
function GameMode:OnPlayerChat(keys)
	-- local player = PlayerResource:GetSelectedHeroEntity(0)

	-- for i, modifier in pairs(player:FindAllModifiers()) do
	-- 	print(modifier:GetName())
	-- end

	-- local entity = Entities:First()

	-- while entity do
	-- 	local classname = entity:GetClassname()

	-- 	if classname ~= "ent_dota_tree" then
			-- print(entity:GetClassname(), entity:GetName())
	-- 	end

	-- 	entity = Entities:Next(entity)
	-- end
end