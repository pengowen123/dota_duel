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
    ClearBuffs(player_entity)
    -- This must happen after buffs are cleared to also teleport invulernable heroes such as those in Eul's Scepter
    TeleportEntityByTeam(player_entity, "arena_start_radiant", "arena_start_dire", true)
    ClearBase()
  end
end


-- Performs all end of round actions, such as resetting cooldowns
function EndRound()
  -- To avoid starting the round while one is being played (which happens if someone dies before the round starts, such as spectre
  -- haunting to the enemy base)
  Timers:RemoveTimer("timer_start_round")

  local round_start_delay = 30.0
  PrintTeamOnly(tostring(round_start_delay) .. " seconds to round start")

  local args = {
    endTime = round_start_delay,
    callback = StartRound
  }

  Timers:CreateTimer("timer_start_round", args)

  -- Clear arena after 10 seconds
  local clear_arena_delay = 15.0
  Timers:CreateTimer(clear_arena_delay, ClearArena)

  -- To catch heroes like storm spirit when they are invulnerable, call ResetPlayers 15
  -- times with 1 second between each call
  local reset_delay = 1.0
  local resets = clear_arena_delay

  Timers:CreateTimer(
    function()
      -- Only center the camera the first time (if a player dodges the first teleport, the camera won't be centered at the base,
      -- but this should rarely happen)
      local center_camera = resets == clear_arena_delay
      ResetPlayers(center_camera)

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
    ResetCooldowns(player_entity)
    ClearBuffs(player_entity)
    -- This must happen after buffs are cleared to also teleport invulernable heroes such as those in Eul's Scepter
    ResetPosition(player_entity, center_camera)
  end
end


-- Removes all entities in the arena
-- NOTE: If this causes problems, maybe change the trigger to one that damages rather than removes
--       It should only be a problem if a player gets removed, but if they are able to get into the arena when it is cleared,
--		   that is a bug
function ClearArena()
  local trigger = Entities:FindByName(nil, "trigger_clear_arena")

  trigger:Enable()

  local disable = function()
    trigger:Disable()
  end

  local delay = 0.1

  Timers:CreateTimer(delay, disable)
end


-- Removes all entities in each base
function ClearBase()
  for i, trigger in pairs(Entities:FindAllByName("trigger_clear_base")) do
    trigger:Enable()

    local disable = function()
      trigger:Disable()
    end

    local delay = 0.1

    Timers:CreateTimer(delay, disable)
  end
end


-- Teleports an entity to its base and disjoints incoming projectiles
function ResetPosition(entity, center_camera)
  ProjectileManager:ProjectileDodge(entity)

  TeleportEntityByTeam(entity, "base_teleport_radiant", "base_teleport_dire", center_camera)
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