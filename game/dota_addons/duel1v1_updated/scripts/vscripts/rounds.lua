-- The logic that controls the rounds, which makes up most of the gamemode.

require('utils')


-- Ends the round if the entity that died was a player
function OnEntityDeath(event)
  local entity = EntIndexToHScript(event.entindex_killed)

  if entity:IsRealHero() then
    EndRound()
  end
end


-- Starts the next round, resetting all player entities and teleporting them to the arena
function StartRound()
  PrintTeamOnly("Round start")

  local player_entities = GetPlayerEntities()

  for i, player_entity in pairs(player_entities) do
    ResetCooldowns(player_entity)
    TeleportEntityByTeam(player_entity, "arena_start_radiant", "arena_start_dire")
    ClearBuffs(player_entity)
  end
end


-- Performs all end of round actions, such as resetting cooldowns
function EndRound()
  local round_start_delay = 30.0
  PrintTeamOnly(tostring(round_start_delay) .. " seconds to round start")
  Timers:CreateTimer(round_start_delay, StartRound)

  -- Clear arena after 10 seconds
  local clear_arena_delay = 15.0
  Timers:CreateTimer(clear_arena_delay, ClearArena)


  -- To catch heroes like storm spirit or puck when they are invulnerable, call ResetPlayers 15
  -- times with 1 second between each call
  local reset_delay = 1.0
  local resets = clear_arena_delay

  Timers:CreateTimer(
    function()
      -- Only center the camera the first time (if a player dodges the first teleport, the camera won't be centered, but this should rarely happen)
      local center_camera = resets == clear_arena_delay
      ResetPlayers(resets < clear_arena_delay)

      resets = resets - 1

      if resets == 0 then
        reset_delay = nil
      end

      return reset_delay
    end
  )
end


-- Resets the position, cooldowns and buffs of all players
function ResetPlayers(center_camera)
  local player_entities = GetPlayerEntities()

  for i, player_entity in pairs(player_entities) do
    ResetPosition(player_entity, center_camera)
    ResetCooldowns(player_entity)
    ClearBuffs(player_entity)
  end
end


-- Removes all entities in the arena
-- NOTE: If this causes problems, maybe change the trigger to one that damages rather than removes
--       It should only be a problem if a player gets removed, but if they are able to get into the arena when it is cleared,
--		 there is a bug and changing the trigger won't help (instead of being removed they will die, causing the round to start twice)
function ClearArena()
  local trigger = Entities:FindByName(nil, "trigger_clear_arena")

  trigger:Enable()

  local disable = function()
    trigger:Disable()
  end

  local delay = 0.1

  Timers:CreateTimer(delay, disable)
end


-- Teleports an entity to its base and disjoints incoming projectiles
function ResetPosition(entity, center_camera)
  ProjectileManager:ProjectileDodge(entity)

  TeleportEntityByTeam(entity, "base_teleport_radiant", "base_teleport_dire")

  if center_camera then
      SendToConsole("dota_camera_center")
  end
end


-- Resets the cooldowns of the entity's abilities
function ResetCooldowns(entity)
  for i = 0, entity:GetAbilityCount() - 1 do
    local ability = entity:GetAbilityByIndex(i)

    if ability then
      ability:EndCooldown()
    end
  end

  for i = 0, 15 do
    local item = entity:GetItemInSlot(i)

    if item then
      -- Reset charges on items like drums of endurance
      local max_charges = item:GetInitialCharges()
      item:SetCurrentCharges(max_charges)

      item:EndCooldown()
    end
  end
end


-- Removes all temporary buffs on the provided entity
function ClearBuffs(entity)
  local modifiers = entity:FindAllModifiers()

  for i, modifier in pairs(modifiers) do
    -- Don't remove permanent modifiers (prevent item and passive stats from being removed)
    if modifier:GetDuration() ~= -1 then
      modifier:Destroy()
    end
  end
end