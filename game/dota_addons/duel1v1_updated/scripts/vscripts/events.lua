-- This file contains all barebones-registered events and has already set up the passed-in parameters for your use.

-- Cleanup a player when they leave
function GameMode:OnDisconnect(keys)
end
-- The overall game state has changed
function GameMode:OnGameRulesStateChange(keys)
end

-- An NPC has spawned somewhere in game.  This includes heroes
function GameMode:OnNPCSpawned(keys)
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

-- A player has reconnected to the game.  This function can be used to repaint Player-based particles or change
-- state as necessary
function GameMode:OnPlayerReconnect(keys)
end

-- An item was purchased by a player
function GameMode:OnItemPurchased( keys )
end

-- An ability was used by a player
function GameMode:OnAbilityUsed(keys)
end

-- A non-player entity (necro-book, chen creep, etc) used an ability
function GameMode:OnNonPlayerUsedAbility(keys)
end

-- A player changed their name
function GameMode:OnPlayerChangedName(keys)
end

-- A player leveled up an ability
function GameMode:OnPlayerLearnedAbility( keys)
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
	-- local entity = Entities:First()

	-- local i = 0
	-- while entity do
	-- 	if entity:GetClassname() == "npc_dota_elder_titan_ancestral_spirit" then
	-- 		i = i + 1
	-- 	end

	-- 	entity = Entities:Next(entity)
	-- end
	-- print(i, "entities")
end