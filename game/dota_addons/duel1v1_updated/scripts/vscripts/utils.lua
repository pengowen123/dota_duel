-- Utility functions


-- Returns a table containing handles to all player entities
function GetPlayerEntities()
  local player_entities = {}

  local entity = Entities:First()

  for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
    if PlayerResource:IsValidPlayerID(playerID) then
      local entity = PlayerResource:GetSelectedHeroEntity(playerID)

      if entity then
        table.insert(player_entities, entity)
      end
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


function GetEnemyPlayer(team)
  local player_entities = GetPlayerEntities()

  for i, player_entity in pairs(player_entities) do
    if player_entity:GetTeam() ~= team then
      return player_entity
    end
  end
end