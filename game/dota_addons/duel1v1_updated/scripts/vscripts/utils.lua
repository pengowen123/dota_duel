-- Utility functions


-- Constants

modifier_max_charges = {
  -- Shrapnel is handled in ResetCharges
  --["modifier_sniper_shrapnel_charge_counter"] = 3,
  ["modifier_ember_spirit_fire_remnant_charge_counter"] = 3,
  ["modifier_earth_spirit_stone_caller_charge_counter"] = 6,
  ["modifier_shadow_demon_demonic_purge_charge_counter"] = 3,
  ["modifier_bloodseeker_rupture_charge_counter"] = 2,
  ["modifier_broodmother_spin_web_charge_counter"] = 8,
  ["modifier_mirana_leap_charge_counter"] = 3,
  ["modifier_mirana_starfall_scepter_thinker"] = 1,
  ["modifier_tiny_toss_charge_counter"] = 3,
  ["modifier_ancient_apparition_cold_feet_charge_counter"] = 4,
  ["modifier_ember_spirit_sleight_of_fist_charge_counter"] = 2,
  ["modifier_gyrocopter_homing_missile_charge_counter"] = 3,
}


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
      table.insert(player_entities, entity)
    end
  end

  return player_entities
end


-- Returns a table containing all player IDs
function GetPlayerIDs()
  local players = {}

  for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
    if PlayerResource:IsValidPlayerID(playerID) then
      table.insert(players, playerID)
    end
  end

  return players
end


-- Teleports `entity` to the entity with the name `target_entity`, and centers the camer on the player's hero
function TeleportEntity(entity, target_entity_name)
  local point = Entities:FindByName(nil, target_entity_name):GetAbsOrigin()

  FindClearSpaceForUnit(entity, point, false)
  entity:Stop()
end


-- Teleports `entity` to the entity named `radiant_target_name` if `entity` is on the radiant team, or
-- to the entity named `dire_target_name` otherwise
function TeleportEntityByTeam(entity, radiant_target_name, dire_target_name, center_camera)
  local team = entity:GetTeam()

  if team == DOTA_TEAM_GOODGUYS then
    TeleportEntity(entity, radiant_target_name)
  end

  if team == DOTA_TEAM_BADGUYS then
    TeleportEntity(entity, dire_target_name)
  end

  if center_camera then
      SendToConsole("dota_camera_center")
  end
end


-- Returns the name ("Radiant" or "Dire") of the enemy team of the provided one
function GetOppositeTeamName(team)
  local opposite_team_name = "#DOTA_GoodGuys"

  if team == DOTA_TEAM_GOODGUYS then
    opposite_team_name = "#DOTA_BadGuys"
  end

  return opposite_team_name
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
    ["modifier_pudge_flesh_heap"] = true,
    ["modifier_death_prophet_exorcism"] = true,
    ["modifier_mirana_leap_charge_counter"] = true,
    ["modifier_mirana_starfall_scepter_thinker"] = true,
    ["modifier_skeleton_king_mortal_strike"] = true,
    ["modifier_axe_battle_hunger_self"] = true,
  }

  local unsafe = {
    ["modifier_sniper_shrapnel_charge_counter"] = true,
    ["modifier_bristleback_warpath"] = true,
  }

  local name = modifier:GetName()

  return (is_temporary or additional_modifiers[name])
    and modifier_max_charges[name] == nil
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
  }

  return modifiers[modifier_name]
end


-- Returns whether the item with the provided name should have its cooldown reset
-- Returns false for items that cause bugs when their cooldowns get reset
function ShouldResetItemCooldown(item_name)
  local unsafe_items = {
    ["item_ward_observer"] = true,
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