-- The logic that controls the rounds, which makes up most of the gamemode.

require('utils')


-- Ends the round if a player died
function OnEntityDeath(event)
  local entity = EntIndexToHScript(event.entindex_killed)

  -- Only end the round if the entity is a hero and won't reincarnate
  if entity:IsRealHero() and not entity:IsReincarnating() then
    -- To allow for rounds to end in a draw, give projectiles and abilities time to finish
    -- This includes things like gyrocopter homing missle or ultimate, or an auto attack
    local first_reset_delay = 5.0

    Timers:CreateTimer(
      first_reset_delay,
      function()
        EndRound()
      end
    )
  end
end


-- Starts the next round, resetting all player entities and teleporting them to the arena
-- Also removes nightstalker's darkness
function StartRound()
  PrintTeamOnly("Round start")

  ResetNeutrals()
  ClearBases()

  local player_entities = GetPlayerEntities()

  for i, player_entity in pairs(player_entities) do
    ResetCooldowns(player_entity)
    ClearBuffs(player_entity)
    -- This must happen after buffs are cleared to also teleport invulnerable heroes such as those in Eul's Scepter
    TeleportEntityByTeam(player_entity, "arena_start_radiant", "arena_start_dire", true)
  end
end


-- Performs all end of round actions, such as resetting cooldowns
function EndRound()
  local round_start_delay = 30.0

  if not TimerExists("timer_start_round") then
    PrintTeamOnly(tostring(round_start_delay) .. " seconds to round start")
  end

  -- To avoid starting the round while one is being played (which happens if someone dies before the round starts, such as spectre
  -- haunting to the enemy base)
  Timers:RemoveTimer("timer_start_round")
  Timers:RemoveTimer("ten_second_message")

  local args = {
    endTime = round_start_delay,
    callback = StartRound
  }

  -- Start round after `round_start_delay` seconds
  Timers:CreateTimer("timer_start_round", args)

  local args_msg = {
    endTime = round_start_delay - 10.0,
    callback = function()
      PrintRoundStartMessage(10.0)
    end
  }

  Timers:CreateTimer("ten_second_message", args_msg)

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
-- NOTE: This can cause problems if a player gets removed, but if they are able to get into the arena when it is cleared,
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
function ClearBases()
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

    -- Don't refresh the cooldown of observer wards because it causes them to disappear
    if item and not IsObserverWard(item:GetAbilityName()) then
      -- Reset charges on items like drums of endurance
      local max_charges = item:GetInitialCharges()
      item:SetCurrentCharges(max_charges)

      item:EndCooldown()
    end
  end

  ResetCharges(entity)
end


-- Sets the charges on all charge-based abilities from the entity to the maximum value
-- Also sets shadow fiend's souls to 36
-- To prevent abuse, this will not give shadow fiend 46 souls if he has aghanim's scepter
function ResetCharges(entity)
  for i, modifier in pairs(entity:FindAllModifiers()) do
    local name = modifier:GetName()

    local max_charges = modifier_max_charges[name]

    if max_charges ~= nil then
      modifier:SetStackCount(max_charges)
    end
  end

  if entity:GetName() == "npc_dota_hero_nevermore" then
    local necromastery = entity:FindModifierByName("modifier_nevermore_necromastery")

    if necromastery ~= nil then
      necromastery:SetStackCount(36)
    end
  end
end


-- Removes all temporary buffs on the provided entity
function ClearBuffs(entity)
  local modifiers = entity:FindAllModifiers()

  for i, modifier in pairs(modifiers) do
    local is_troll_warlord_fervor = modifier:GetName() == "modifier_troll_warlord_fervor"

    -- Don't remove modifiers such as ones that represent abiltiies
    if IsSafeToRemove(modifier) then
      modifier:Destroy()
    end

    -- Troll fervor is both the stack count and the passive, so it must be removed to reset the stack count
    -- It is re-added here to prevent problems
    if is_troll_warlord_fervor then
      entity:AddNewModifier(entity, entity:GetAbilityByIndex(3), "modifier_troll_warlord_fervor", {})
    end
  end
end


-- Spawns neutrals at their neutral camps
function ResetNeutrals()
  SendToServerConsole("dota_spawn_neutrals")
end