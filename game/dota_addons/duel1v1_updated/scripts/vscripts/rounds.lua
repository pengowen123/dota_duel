-- The logic that controls the rounds, which makes up most of the gamemode.

require('utils')
require('neutrals')
require('round_timer')


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
-- Also removes nightstalker's darkness and hides the ready-up UI
function StartRound()
  -- Prevent the end round timer from teleporting players back to their base after the round starts
  -- Also remove the timer that kills everything in the arena
  Timers:RemoveTimer("reset_players")

  ClearArena()

  Timers:CreateTimer(0.5, SpawnAllNeutrals)

  local teleport_players = function()
    local player_entities = GetPlayerEntities()

    for i, player_entity in pairs(player_entities) do
      ResetCooldowns(player_entity)
      ClearBuffs(player_entity)
      -- This must happen after buffs are cleared to also teleport invulnerable heroes such as those in Eul's Scepter
      TeleportEntityByTeam(player_entity, "arena_start_radiant", "arena_start_dire", true)
    end
  end

  -- Only teleport the players after the clear_arena trigger has been disabled
  local teleport_delay = 1.0
  Timers:CreateTimer(teleport_delay, teleport_players)


  local hide_ui = function()
    CustomGameEventManager:Send_ServerToAllClients("start_round", nil)
  end

  -- Only hide the ready-up UI after players get teleported, to make the round start a smoother transition
  Timers:CreateTimer(teleport_delay, hide_ui)

  -- Wait for players to be teleported to the arena before clearing the bases
  local clear_base_delay = teleport_delay + 0.1
  Timers:CreateTimer(clear_base_delay, ClearBases)
end


-- Performs all end of round actions, such as resetting cooldowns
function EndRound()
  CustomGameEventManager:Send_ServerToAllClients("end_round", nil)
  InitReadyUpData()

  -- Start the round after 30 seconds
  local round_start_delay = 30
  SetRoundStartTimer(round_start_delay)
  
  -- Wait to clear the arena because certain heroes are able to dodge the teleport to base
  -- They will eventually be teleported again, so we wait until that happens to avoid killing the player
  -- accidentally

  -- Respawn all players (necessary because the barebones respawn time setting doesn't apply to deaths to neutrals)
  RespawnPlayers()

  -- To catch heroes like storm spirit when they are invulnerable, call ResetPlayers 15
  -- times with 1 second between each call
  ResetPlayers(true)
  local resets = 15
  local reset_delay = 1.0

  local reset = function()
    ResetPlayers(false)

    resets = resets - 1

    if resets == 0 then
      return nil
    end

    return reset_delay
  end

  local args = {
    endTime = i,
    callback = reset
  }
  
  Timers:CreateTimer("reset_players", args)
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


-- Forces all players to respawn
function RespawnPlayers()
  for i, playerID in pairs(GetPlayerIDs()) do
    local player_entity = PlayerResource:GetSelectedHeroEntity(playerID)

    player_entity:SetTimeUntilRespawn(1.0)
  end
end


-- Kills all entities in the arena
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
  local triggers = {}

  table.insert(triggers, Entities:FindByName(nil, "trigger_clear_base_radiant"))
  table.insert(triggers, Entities:FindByName(nil, "trigger_clear_base_dire"))

  for i, trigger in pairs(triggers) do
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
    if item and ShouldResetItemCooldown(item:GetAbilityName()) then
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
    local name = modifier:GetName()

    print("modifier name: " .. name)

    -- Don't remove modifiers such as ones that represent abiltiies
    if IsSafeToRemove(modifier) then
      modifier:Destroy()
    end

    -- Some modifiers are both the stack count and the passive, so they must be removed to reset the stack count
    -- However, removing them removes the passive as well so the modifier is re-added here to fix that
    local ability_origin = ShouldBeReadded(name)

    if ability_origin then
      entity:AddNewModifier(entity, entity:GetAbilityByIndex(ability_origin), name, {})
    end
  end
end