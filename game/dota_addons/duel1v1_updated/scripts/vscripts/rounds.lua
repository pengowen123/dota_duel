-- The logic that controls the rounds, which makes up most of the gamemode.

require('utils')
require('neutrals')
require('round_timer')
require('rematch_timer')
require('kills')
require('hero_select')


-- Tracks how many players are dead on each team
dead_players = {
  [DOTA_TEAM_GOODGUYS] = 0,
  [DOTA_TEAM_BADGUYS] = 0,
}

-- Ends the round if a player died
function OnEntityDeath(event)
  local entity = EntIndexToHScript(event.entindex_killed)

  -- Only count the death if the entity is a hero and won't reincarnate
  if entity:IsRealHero() then
    if entity:IsReincarnating() then
      if global_bot_controller then
        if entity:GetName() == "npc_dota_hero_skeleton_king" then
          if entity:GetTeam() == PlayerResource:GetTeam(global_bot_controller.bot_id) then
            global_bot_controller:OnReincarnate()
          end
        end
      end
    else
      if game_state == GAME_STATE_FIGHT then
        local team = entity:GetTeam()
        dead_players[team] = dead_players[team] + 1

        -- Fix respawn time to prevent respawns without calling SetHeroRespawnEnabled
        local set_respawn_time = function()
          SetRespawnTimes(999.0)
          return 1.0
        end

        local player_id = entity:GetPlayerOwnerID()

        -- Update respawn timer
        local update_respawn_timer = function()
          CustomGameEventManager:Send_ServerToAllClients("update_hero_lists", {})

          local hero = PlayerResource:GetSelectedHeroEntity(player_id)

          if hero and not hero:IsAlive() then
            return 1.0
          end
        end

        Timers:CreateTimer(0.1, update_respawn_timer)

        local args = {
          endTime = 0.0,
          callback = set_respawn_time
        }

        Timers:CreateTimer("set_respawn_time", args)

        -- End the round if all players on a team have died
        if dead_players[team] >= PlayerResource:GetPlayerCountForTeam(team) then
          dead_players[DOTA_TEAM_GOODGUYS] = 0
          dead_players[DOTA_TEAM_BADGUYS] = 0

          -- Is nil if no player has won yet, 0 if radiant won and 1 if dire won
          local winner = nil

          if team == DOTA_TEAM_GOODGUYS then
            AwardDireKill()
          elseif team == DOTA_TEAM_BADGUYS then
            AwardRadiantKill()
          end

          if GetRadiantKills() >= MAX_KILLS then
            winner = DOTA_TEAM_GOODGUYS
          end

          if GetDireKills() >= MAX_KILLS then
            winner = DOTA_TEAM_BADGUYS
          end

          if winner then
            EndGameDelayed(winner, VICTORY_REASON_ROUNDS)

            text = "#duel_victory"
            team = GetLocalizationTeamName(winner)

            Notifications:ClearBottomFromAll()
            Notifications:BottomToAll({
              text = text,
              duration = 10,
              vars = {
                team = team,
              }
            })
          end

          -- To allow for rounds to end in a draw, give projectiles and abilities time to finish
          -- This includes things like gyrocopter homing missle or ultimate, or an auto attack
          local first_reset_delay = 5.0

          Timers:RemoveTimer("set_respawn_time")
          SetRespawnTimes(first_reset_delay)

          Timers:CreateTimer(
            first_reset_delay,
            function()
              EndRound()
            end
          )
        end
      end
    end
  end
end


-- Prepares for a new round, clearing the arena and performing any other necessary cleanup
function PrepareNextRound()
  DestroyDroppedGems()
  ClearArena()
  DestroyAllTrees()
end


-- Starts the next round, resetting all player entities and teleporting them to the arena
-- Also removes nightstalker's darkness and hides the ready-up UI
function StartRound()
  if not (game_state == GAME_STATE_BUY) then
    return
  end

  -- Prevent the end round timer from teleporting players back to their base after the round starts
  Timers:RemoveTimer("reset_players")

  SetGameState(GAME_STATE_FIGHT)

  SpawnAllNeutrals()

  local player_entities = GetPlayerEntities()

  for i, player_entity in pairs(player_entities) do
    -- Buffs are cleared before cooldowns reset so tiny doesn't start the round with tree grab on
    -- cooldown if he used it in the fountain
    ClearBuffs(player_entity)
    ResetCooldowns(player_entity)

    for i, modifier in pairs(player_entity:FindAllModifiers()) do
      local name = modifier:GetName()

      if name == "modifier_stun" then
        modifier:Destroy()
      end
    end

    -- Keep spirit bears disabled and away from the shop so lone druid can't cheat
    if player_entity:GetName() == "npc_dota_lone_druid_bear" then
      player_entity:AddNewModifier(player_entity, nil, "modifier_bear_disable", {})

      local point = Vector(-12000, 12000, 0)

      -- Keep bears from separate teams in different places so they don't get vision of each other
      if player_entity:GetTeam() == DOTA_TEAM_BADGUYS then
        point = Vector(12000, 12000, 0)
      end

      FindClearSpaceForUnit(player_entity, point, false)
    else
      -- This must happen after buffs are cleared to also teleport invulnerable heroes such as those in Eul's Scepter
      TeleportEntityByTeam(player_entity, "arena_start_radiant", "arena_start_dire", true)
    end
  end

  -- Center players' cameras for convenience and to avoid confusion
  -- Must be done after a delay so it isn't done before players are teleported
  Timers:CreateTimer(0.1, CenterPlayerCameras)

  CustomGameEventManager:Send_ServerToAllClients("start_round", nil)

  -- Wait for players to be teleported to the arena before clearing the bases
  local clear_base_delay = 0.1
  Timers:CreateTimer(clear_base_delay, ClearBases)

  -- The hero select data gets reset randomly, this fixes it
  InitHeroSelectData()

  -- Makes rounds balanced for heroes like timbersaw
  RegrowAllTrees()

  DestroyRunes()

  -- Prevent broodmother from reusing webs between rounds
  DestroyWebs()

  -- Prevent the items purchased limit from being reached
  DestroyDroppedItems()

  -- Remove old hero entities
  -- Otherwise, they keep building up every round, eventually causing lag
  RemoveOldHeroes()

  if first_round then
    first_round = false
  end
end


-- Performs all end of round actions, such as resetting cooldowns
function EndRound()
  if game_state == GAME_STATE_BUY then
    return
  end

  InitReadyUpData()

  -- If a player has reached 5 kills, game_state will be GAME_STATE_REMATCH/GAME_STATE_HERO_SELECT
  if game_state == GAME_STATE_FIGHT then
    SetGameState(GAME_STATE_BUY)

    local data = {}
    data.enable_surrender = true
    CustomGameEventManager:Send_ServerToAllClients("end_round", data)

    -- Start the round after 30 seconds
    local round_start_delay = 30
    SetRoundStartTimer(round_start_delay)
  end

  -- Respawn all players
  -- RespawnPlayers()

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
    endTime = 0.5,
    callback = reset
  }

  Timers:CreateTimer("reset_players", args)

  -- To prevent reaching the item purchased limit because of items dropped on the ground
  ClearBases()
  DestroyDroppedItems()
  DestroyAllTrees()

  -- Stop the death music, otherwise it plays for a long time
  SetMusicStatus(DOTA_MUSIC_STATUS_PRE_GAME_EXPLORATION, 5.0)

  SetPreviousRoundEndTime()

  if game_state == GAME_STATE_BUY then
    -- Reset talents so players can try new ones
    ResetTalents()
  end
end


-- Resets the position, cooldowns and buffs of all players
function ResetPlayers()
  local player_entities = GetPlayerEntities()

  for i, player_entity in pairs(player_entities) do
    ResetCooldowns(player_entity)
    ClearBuffs(player_entity)

    for i, modifier in pairs(player_entity:FindAllModifiers()) do
      local name = modifier:GetName()
      if name == "leave_arena_modifier" then
        modifier:Destroy()
      end
    end

    -- Add modifier_stun in case the trigger doesn't add it (it is inconsistent sometimes)
    player_entity:AddNewModifier(player_entity, nil, "modifier_stun", {})

    -- This must happen after buffs are cleared to also teleport invulernable heroes such as those in Eul's Scepter
    ResetPosition(player_entity)
  end
end


-- Forces all players to respawn
-- NOTE: Calling this causes the dead music to play permanently
-- function RespawnPlayers()
--   for i, playerID in pairs(GetPlayerIDs()) do
--     local player_entity = PlayerResource:GetSelectedHeroEntity(playerID)

--     if player_entity then
--       player_entity:RespawnHero(false, false)
--     end
--   end
-- end


-- Sets the respawn time remaining for all dead players
function SetRespawnTimes(time)
  for i, player_id in pairs(GetPlayerIDs()) do
    local player_entity = PlayerResource:GetSelectedHeroEntity(player_id)

    if player_entity and not player_entity:IsAlive() then
      player_entity:SetTimeUntilRespawn(time)
    end
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
function ResetPosition(entity)
  ProjectileManager:ProjectileDodge(entity)

  TeleportEntityByTeam(entity, "base_teleport_radiant", "base_teleport_dire")
end


-- Resets the cooldowns of the entity's abilities
-- Also resets charges of charge-based abilities
function ResetCooldowns(entity)
  for i = 0, entity:GetAbilityCount() - 1 do
    local ability = entity:GetAbilityByIndex(i)

    if ability then
      ability:EndCooldown()
      ability:RefreshCharges()
    end
  end

  for i = 0, 25 do
    local item = entity:GetItemInSlot(i)

    -- Don't refresh the cooldown of observer wards because it causes them to disappear
    if item and ShouldResetItemCooldown(item:GetAbilityName()) then  
      -- Reset charges on items like drums of endurance
      local max_charges = item:GetInitialCharges()

      -- Give Urn and Spirit Vessel 100 charges
      if item:GetName() == "item_urn_of_shadows" or item:GetName() == "item_spirit_vessel" then
        max_charges = 100
      end

      -- Don't set charges on consumables so players can buy more
      if item:IsPermanent() then
        item:SetCurrentCharges(max_charges)
      end

      item:EndCooldown()
    end
  end

  ResetNecromastery(entity)
end


-- Sets shadow fiend's souls to maximum
function ResetNecromastery(entity)
  if entity:GetName() == "npc_dota_hero_nevermore" then
    local necromastery = entity:FindModifierByName("modifier_nevermore_necromastery")

    if necromastery ~= nil then
      max = 36

      if entity:HasScepter() then
        max = 46
      end

      necromastery:SetStackCount(max)
    end
  end
end


-- Removes all temporary buffs on the provided entity
-- NOTE: Probably made redundant by ResetTalents but kept around just in case
function ClearBuffs(entity)
  local modifiers = entity:FindAllModifiers()
  -- print("entity name: " .. entity:GetName())

  for i, modifier in pairs(modifiers) do
    local name = modifier:GetName()
    -- print("modifier: " .. name)

    -- Don't remove modifiers such as ones that represent abiltiies
    if IsSafeToRemove(modifier) then
      -- print("removing modifier: " .. name)
      modifier:Destroy()
    else
      -- print("not removing modifier: " .. name)
    end

    -- Reset undying reincarnation talent cooldown
    if name == "modifier_special_bonus_reincarnation" then
      modifier:ForceRefresh()
    end

    -- Some modifiers are both the stack count and the passive, so they must be removed to reset the stack count
    -- However, removing them removes the passive as well so the modifier is re-added here to fix that
    local ability_origin = ShouldBeReadded(name)

    if ability_origin then
      entity:AddNewModifier(entity, entity:GetAbilityByIndex(ability_origin), name, {})
    end
  end
end


-- Regrows all trees on the map
function RegrowAllTrees()
  for i, tree in pairs(Entities:FindAllByClassname("ent_dota_tree")) do
    tree:GrowBack()
  end
end


-- Destroys all trees on the map
function DestroyAllTrees()
  GridNav:DestroyTreesAroundPoint(Vector(0, 0, 0), 32000.0, false)
end


-- Destroys all webs from Spin Web
function DestroyWebs()
  for i, web in pairs(Entities:FindAllByClassname("npc_dota_broodmother_web")) do
    web:Kill(nil, web)
  end
end


-- Destroys all dropped items
function DestroyDroppedItems()
  for i, entity in pairs(Entities:FindAllByClassname("dota_item_drop")) do
    local item = entity:GetContainedItem()

    if item then
      -- Don't destroy gems (they are handles by DestroyDroppedGems)
      if item:GetAbilityName() ~= "item_gem" then
        item:Destroy()
        entity:Kill()
      end
    else
      entity:Kill()
    end
  end
end


-- Destroys all runes
function DestroyRunes()
  for i, rune in pairs(Entities:FindAllByClassname("dota_item_rune")) do
    rune:Kill()
  end
end


-- Resets the talents of all players
-- NOTE: While talents no longer need to be reset, this is a harder reset than ClearBuffs so it is
--       kept around for safety
function ResetTalents()
  local player_IDs = GetPlayerIDs()
  local player_items = GetPlayerInventories()
  local bear_items = {}
  local bear_moon_shards = {}

  -- Reset hero and copy over all the modifiers
  for i, playerID in pairs(player_IDs) do
    -- Get the hero name and the selected hero's entities
    local hero_name = PlayerResource:GetSelectedHeroName(playerID)
    local hero_entity = PlayerResource:GetSelectedHeroEntity(playerID)

    -- Cancel TP scrolls
    hero_entity:Interrupt()

    -- Check for permanent buffs
    local has_moon_shard = hero_entity:HasModifier("modifier_item_moon_shard_consumed")
    local has_scepter = hero_entity:HasModifier("modifier_item_ultimate_scepter_consumed")
    local has_scepter_shard = HasScepterShard(hero_entity)

    -- Collect modifiers and items for the spirit bear of this hero if it has one
    for i, entity in pairs(Entities:FindAllByName("npc_dota_lone_druid_bear")) do
      if entity:GetOwnerEntity() == hero_entity then
        bear_moon_shards[playerID] = entity:HasModifier("modifier_item_moon_shard_consumed")
        bear_items[playerID] = GetInventoryOfEntity(entity)
        ClearInventory(entity)

        -- Cancel TP scrolls
        entity:Interrupt()
      end
    end

    -- Replace the hero with a dummy
    local temp_hero_name = "npc_dota_hero_invoker"
    if temp_hero_name == hero_name then
      temp_hero_name = "npc_dota_hero_abaddon"
    end
    local dummy_hero = PlayerResource:ReplaceHeroWith(playerID, temp_hero_name, 99999, 99999)

    -- Clear the dummy hero's inventory
    -- It starts with a town portal scroll and if it is not destroyed, the items purchased limit
    -- is reduced by 1 every round
    ClearInventory(dummy_hero)

    -- Replace dummy with the original hero
    local new_hero = PlayerResource:ReplaceHeroWith(playerID, hero_name, 99999, 99999)

    -- Re-add aghanim's scepter and moon shard buffs
    if has_moon_shard then
      local moon_shard = new_hero:AddItemByName("item_moon_shard")
      -- Not sure what this is for, but setting it to 0 seems to work
      local player_index = 0
      new_hero:CastAbilityOnTarget(new_hero, moon_shard, player_index)
    end

    if has_scepter then
      new_hero:AddItemByName("item_ultimate_scepter_2")
    end

    if has_scepter_shard then
      new_hero:AddItemByName("item_aghanims_shard")
    end

    local re_add_items = function()
      local player_inventory = player_items[playerID]
      -- Remove items the player purchases before their old items are added back to avoid bugs
      ClearInventory(new_hero)

      SetupInventory(new_hero, new_hero, player_inventory)

      local bear_inventory = bear_items[playerID]

      if bear_inventory ~= nil then
        -- Summon a new bear automatically, otherwise the items and modifiers can't be added back
        new_hero:GetAbilityByIndex(0):CastAbility()

        for i, entity in pairs(Entities:FindAllByName("npc_dota_lone_druid_bear")) do
          if entity:GetOwnerEntity() == new_hero then
            -- Re-add moon shard buff
            if bear_moon_shards[playerID] then
              local moon_shard = entity:AddItemByName("item_moon_shard")
              local player_index = 0
              entity:CastAbilityOnTarget(entity, moon_shard, player_index)
            end

            local re_add_bear_items = function()
              SetupInventory(entity, new_hero, bear_inventory)
            end

            -- Re-add items from the bear's inventory half a second after summoning it
            Timers:CreateTimer(0.5, re_add_bear_items)
          end
        end
      end
    end

    -- Re-add items from inventory half a second after replacing the hero
    Timers:CreateTimer(0.5, re_add_items)

    -- Level up hero again (it is done in OnNPCSpawned, however it fails to catch some aghanim's
    -- scepter related abilities, such as Io spirits movement)
    Timers:CreateTimer(0.5, function() LevelEntityToMax(new_hero) end)
  end
end


-- Destroys all dropped gems of true sight
function DestroyDroppedGems()
  local collector = GetDummyHero()
  local gem_count = 0
  for i,entity in pairs(Entities:FindAllByClassname("dota_item_drop")) do
    gem_count = gem_count + 1
    local item = entity:GetContainedItem()

    if item and item:GetAbilityName() == "item_gem" then
      local pickup = function()
        FindClearSpaceForUnit(entity, collector:GetAbsOrigin(), false)

        collector:PickupDroppedItem(entity)

        local destroy_item = function()
          item:Destroy()
        end

        -- The gems must be destroyed after a delay or the vision doesn't get removed
        Timers:CreateTimer(0.1, destroy_item)
      end

      Timers:CreateTimer(gem_count * 0.1, pickup)
    end
  end
end


function CenterPlayerCameras()
  CustomGameEventManager:Send_ServerToAllClients("center_camera", nil)
end


-- Returns the last time a round or game ended
previous_round_end_time = 0
function PreviousRoundEndTime()
  return previous_round_end_time
end


function SetPreviousRoundEndTime()
  previous_round_end_time = GameRules:GetGameTime()
end