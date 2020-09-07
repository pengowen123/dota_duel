-- Utility functions


-- Constants
MAX_KILLS = 5
STRENGTH_MAGIC_RESISTANCE = 0.08


-- Returns a table containing handles to all player entities
function GetPlayerEntities()
  local player_entities = {}
  local player_ids = {}

  local entity = Entities:First()

  for i, playerID in pairs(GetPlayerIDs()) do
    local entity = PlayerResource:GetSelectedHeroEntity(playerID)

    if entity then
      table.insert(player_entities, entity)
      player_ids[playerID] = true
    end
  end

  -- Also add these entities because the above code won't find them
  local entity_names = {
    "npc_dota_hero_meepo",
    "npc_dota_hero_arc_warden",
    "npc_dota_lone_druid_bear",
  }

  for i, name in pairs(entity_names) do
    for i, entity in pairs(Entities:FindAllByName(name)) do
      if not IsDummyHero(entity) then
        table.insert(player_entities, entity)
      end
    end
  end

  return player_entities
end


-- Returns a table containing all non-spectator player IDs
function GetPlayerIDs()
  local players = {}

  for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
    if PlayerResource:IsValidPlayerID(playerID) then
      local team = PlayerResource:GetTeam(playerID)
      if (team == DOTA_TEAM_GOODGUYS) or (team == DOTA_TEAM_BADGUYS) then
        table.insert(players, playerID)
      end
    end
  end

  return players
end


-- Teleports `entity` to the entity with the name `target_entity`
function TeleportEntity(entity, target_entity_name)
  local point = Entities:FindByName(nil, target_entity_name):GetAbsOrigin()

  FindClearSpaceForUnit(entity, point, false)
  entity:Stop()
end


-- Teleports `entity` to the entity named `radiant_target_name` if `entity` is on the radiant team, or
-- to the entity named `dire_target_name` otherwise
function TeleportEntityByTeam(entity, radiant_target_name, dire_target_name)
  local team = entity:GetTeam()

  if team == DOTA_TEAM_GOODGUYS then
    TeleportEntity(entity, radiant_target_name)
  end

  if team == DOTA_TEAM_BADGUYS then
    TeleportEntity(entity, dire_target_name)
  end
end


-- Returns the team that is the enemy of the provided one
function GetOppositeTeam(team)
  if team == DOTA_TEAM_GOODGUYS then
    return DOTA_TEAM_BADGUYS
  elseif team == DOTA_TEAM_BADGUYS then
    return DOTA_TEAM_GOODGUYS
  end
end


-- Returns the player entity of the player that is on the opposite team of the provided one
function GetEnemyPlayer(team)
  local player_entities = GetPlayerEntities()

  for i, player_entity in pairs(player_entities) do
    if player_entity:GetTeam() ~= team then
      return player_entity
    end
  end
end


-- Returns whether a timer with the given name exists
function TimerExists(name)
  return Timers.timers[name] ~= nil
end


-- Returns whether the modifier should be removed at the start or end of rounds
function IsSafeToRemove(modifier)
  -- All temporary modifiers are safe to remove
  local is_temporary = modifier:GetDuration() ~= -1

  -- These permanent modifiers are also safe to remove
  local additional_modifiers = {
    ["modifier_troll_warlord_fervor"] = true,
    ["modifier_legion_commander_duel_damage_boost"] = true,
    ["modifier_silencer_int_steal"] = true,
    ["modifier_life_stealer_infest"] = true,
    ["modifier_night_stalker_darkness"] = true,
    ["modifier_death_prophet_exorcism"] = true,
    ["modifier_mirana_leap_charge_counter"] = true,
    ["modifier_mirana_starfall_scepter_thinker"] = true,
    ["modifier_skeleton_king_mortal_strike"] = true,
    ["modifier_axe_battle_hunger_self"] = true,
    ["modifier_shredder_reactive_armor"] = true,
    ["modifier_slark_essence_shift_permanent_buff"] = true,
    ["modifier_slark_essence_shift_permanent_debuff"] = true,
    ["modifier_abyssal_underlord_atrophy_aura_hero_permanent_buff"] = true,
    ["modifier_lion_finger_of_death_kill_counter"] = true,
    ["modifier_item_shadow_amulet_fade"] = true,
    ["modifier_templar_assassin_meld"] = true,
  }

  local unsafe = {
    ["modifier_sniper_shrapnel_charge_counter"] = true,
    ["modifier_bristleback_warpath"] = true,
    ["modifier_stun"] = true,
    ["leave_arena_modifier"] = true,
  }

  local name = modifier:GetName()

  return (is_temporary or additional_modifiers[name])
    and unsafe[name] == nil
end


-- Returns what ability index this ability is from, if it should be re-added after being removed
function ShouldBeReadded(modifier_name)
  local modifiers = {
    ["modifier_troll_warlord_fervor"] = 3,
    ["modifier_slark_essence_shift"] = 2,
    ["modifier_lina_fiery_soul"] = 2,
    ["modifier_skeleton_king_mortal_strike"] = 2,
    ["modifier_axe_battle_hunger_self"] = 1,
    ["modifier_shredder_reactive_armor"] = 2,
    ["modifier_lion_finger_of_death_kill_counter"] = 5,
  }

  return modifiers[modifier_name]
end


-- Returns whether the item with the provided name should have its cooldown reset
-- Returns false for items that cause bugs when their cooldowns get reset
function ShouldResetItemCooldown(item_name)
  local unsafe_items = {
    ["item_ward_observer"] = true,
    ["item_ward_sentry"] = true,
    ["item_ward_dispenser"] = true,
    ["item_smoke_of_deceit"] = true,
  }

  return not unsafe_items[item_name]
end


-- Returns whether the provided entity is a monkey king clone
function IsMonkeyKingClone(entity)
  return entity:HasModifier("modifier_monkey_king_fur_army_soldier_hidden")
    or   entity:HasModifier("modifier_monkey_king_fur_army_soldier")
    or   entity:HasModifier("modifier_monkey_king_fur_army_soldier_inactive")
end


-- Returns whether the match has ended
function IsMatchEnded()
  return GameRules:State_Get() == DOTA_GAMERULES_STATE_POST_GAME
end


-- Clears all players' inventories and stashes
function ClearInventories()
  for i, playerID in pairs(GetPlayerIDs()) do
    local player = PlayerResource:GetPlayer(playerID)
    local player_entity = player:GetAssignedHero()

    if player_entity then
      for i=0,20 do
        local item = player_entity:GetItemInSlot(i)

        if item then
          item:Destroy()
        end
      end
    end
  end
end


-- Get all the items of each player
-- Returns a table with items of the form [item_name, item_charges, item_secondary_charges]
-- Ignores TP scrolls
function GetInventoryItems()
  all_inventories = {}
  for i, playerID in pairs(GetPlayerIDs()) do
    local player_inventory = {}
    local player_hero_handle = PlayerResource:GetSelectedHeroEntity(playerID)

    if player_hero_handle then
      for i=0,20 do
        local item = player_hero_handle:GetItemInSlot(i)

        if item then
          if not (item:GetAbilityName() == "item_tpscroll") then
            player_inventory[i] = {
              [1] = item:GetAbilityName(),
              [2] = item:GetCurrentCharges(),
              [3] = item:GetSecondaryCharges(),
            }
          end
          item:Destroy()
        end
      end
    end
    all_inventories[playerID] = player_inventory
  end
  return all_inventories
end


-- Returns the correct localization string for the name of the provided team
-- `winner` should be either DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS
function GetLocalizationTeamName(team)
  if team == DOTA_TEAM_GOODGUYS then
    return "#DOTA_GoodGuys"
  elseif team == DOTA_TEAM_BADGUYS then
    return "#DOTA_BadGuys"
  end
end


-- Removes all old hero entities, such as those left behind when giving players new heroes
-- NOTE: Do not call this until all spark wraiths have been removed or they will get stuck
function RemoveOldHeroes()
  local hero_names = {}
  local hero_entities = {}

  for i, id in pairs(GetPlayerIDs()) do
    local hero = PlayerResource:GetSelectedHeroEntity(id)

    if hero then
      hero_names[hero:GetName()] = true
      hero_entities[hero] = true
    end
  end

  local entity = Entities:First()
  while entity do
    if entity.IsHero and entity:IsHero() then
      if not IsDummyHero(entity) and not hero_entities[entity] then
        if not IsClone(entity) or not hero_entities[entity:GetCloneSource()] then
          UTIL_Remove(entity)
        end
      end
    end

    entity = Entities:Next(entity)
  end
end


-- Returns whether the player with the provided ID is a bot
function IsBot(id)
  return tostring(PlayerResource:GetSteamID(id)) == "0"
end


-- Sets the add bot button's enabled state to the provided value
function EnableAddBotButton(enabled)
  local data = {}
  data.enabled = enabled

  CustomGameEventManager:Send_ServerToAllClients("enable_add_bot_button", data)
end


-- Returns the multiplier for physical damage taken given an armor value
function GetPhysicalDamageMultiplier(armor_value)
  return 1 - ((0.052 * armor_value) / (0.9 + 0.048 * math.abs(armor_value)))
end


-- Returns whether the provided entity has any item in the table
-- Ignores backpack and stash
function HasAnyItem(entity, items)
  for i=0,5 do
    local item = entity:GetItemInSlot(i)

    if item and items[item:GetAbilityName()] then
      return true
    end
  end

  return false
end


-- Returns the dummy hero
function GetDummyHero()
  return Entities:FindByNameWithin(nil, DUMMY_HERO_NAME, DUMMY_HERO_POSITION, 250.0)
end


-- Returns whether the provided entity is the dummy hero
function IsDummyHero(entity)
  return entity:GetName() == DUMMY_HERO_NAME
    and (entity:GetAbsOrigin() - DUMMY_HERO_POSITION):Length2D() < 250.0
end


-- Returns whether the provided entity is taunted
function IsTaunted(entity)
  local taunt_modifiers = {
    ["modifier_axe_berserkers_call"] = true,
    ["modifier_troll_warlord_battle_trance"] = true,
    ["modifier_winter_wyvern_winters_curse"] = true,
    ["modifier_huskar_life_break_taunt"] = true,
    ["modifier_aether_remnant_pull"] = true,
  }

  for i,modifier in pairs(entity:FindAllModifiers()) do
    local modifier_name = modifier:GetName()

    if taunt_modifiers[modifier_name] then
      return true
    end
  end

  return false
end


-- Returns whether the provided entity is feared
function IsFeared(entity)
  local fear_modifiers = {
    ["modifier_dark_willow_debuff_fear"] = true,
    ["modifier_lone_druid_savage_roar"] = true,
    ["modifier_queenofpain_scream_of_pain_fear"] = true,
    ["modifier_terrorblade_fear"] = true,
    ["modifier_nevermore_requiem_fear"] = true,
    ["modifier_vengeful_spirit_wave_of_terror_fear"] = true,
  }

  for i,modifier in pairs(entity:FindAllModifiers()) do
    local modifier_name = modifier:GetName()

    if fear_modifiers[modifier_name] then
      return true
    end
  end

  return false
end


-- Returns whether the provided entity is a clone
function IsClone(entity)
  return entity:IsClone()
    or IsMonkeyKingClone(entity)
    or entity:FindModifierByName("modifier_arc_warden_tempest_double")
end