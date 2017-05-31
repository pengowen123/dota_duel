-- Utility functions


-- Constants

modifier_max_charges = {
  ["modifier_sniper_shrapnel_charge_counter"] = 3,
  ["modifier_ember_spirit_fire_remnant_charge_counter"] = 3,
  ["modifier_earth_spirit_stone_caller_charge_counter"] = 6,
  ["modifier_shadow_demon_demonic_purge_charge_counter"] = 3,
  ["modifier_bloodseeker_rupture_charge_counter"] = 2,
}


-- Returns a table containing handles to all player entities
function GetPlayerEntities()
  local player_entities = {}

  local entity = Entities:First()

  for i, playerID in pairs(GetPlayers()) do
    local entity = PlayerResource:GetSelectedHeroEntity(playerID)

    if entity then
      table.insert(player_entities, entity)
    end
  end

  -- Also add all meepo clones because the above code won't find them
  for i, entity in pairs(Entities:FindAllByName("npc_dota_hero_meepo")) do
    if entity:IsClone() then
      table.insert(player_entities, entity)
    end
  end

  return player_entities
end


-- Returns a table containing all player IDs
function GetPlayers()
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


-- Prints the message to allies only chat for all players
function PrintTeamOnly(message)
  GameRules:SendCustomMessage(message, DOTA_TEAM_GOODGUYS, 1)
end


-- Returns the name ("Radiant" or "Dire") of the enemy team of the provided one
function GetOppositeTeamName(team)
  local opposite_team_name = "Radiant"

  if team == DOTA_TEAM_GOODGUYS then
    opposite_team_name = "Dire"
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
  -- NOTE: Troll warlord's fervor is not safe to remove
  --       It has to be removed to reset the stack count, but it must be re-added after removal
  local additional_modifiers = {
    ["modifier_troll_warlord_fervor"] = true,
    ["modifier_legion_commander_duel_damage_boost"] = true,
    ["modifier_silencer_int_steal"] = true,
    ["modifier_life_stealer_infest"] = true,
    ["modifier_night_stalker_darkness"] = true,
  }

  local name = modifier:GetName()

  return (is_temporary or additional_modifiers[name] ~= nil)
    and modifier_max_charges[name] == nil
end


-- Prints "x seconds to round start" where `x` is the provided value
function PrintRoundStartMessage(seconds)
  PrintTeamOnly(tostring(seconds) .. " seconds to round start")
end


-- Returns whether the provided item name is that of an observer ward or observer and sentry ward stack
function IsObserverWard(item_name)
  return item_name == "item_ward_observer" or item_name == "item_ward_dispenser"
end