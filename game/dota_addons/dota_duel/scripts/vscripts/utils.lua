-- Utility functions


-- Constants
NEUTRAL_ITEM_SLOT = 16


monkey_king_clone_modifiers = {
  ["modifier_monkey_king_fur_army_soldier_hidden"] = true,
  ["modifier_monkey_king_fur_army_soldier"] = true,
  ["modifier_monkey_king_fur_army_soldier_inactive"] = true,
  ["modifier_monkey_king_fur_army_soldier_in_position"] = true,
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
-- Returns nil for teams other than DOTA_TEAM_GOODGUYS and DOTA_TEAM_BADGUYS
function GetOppositeTeam(team)
  if team == DOTA_TEAM_GOODGUYS then
    return DOTA_TEAM_BADGUYS
  elseif team == DOTA_TEAM_BADGUYS then
    return DOTA_TEAM_GOODGUYS
  end
end


-- Returns whether a timer with the given name exists
function TimerExists(name)
  return Timers.timers[name] ~= nil
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
  for _, modifier in pairs(entity:FindAllModifiers()) do
    if monkey_king_clone_modifiers[modifier:GetName()] then
      return true
    end
  end

  return false
end


-- Returns whether the match has ended
function IsMatchEnded()
  return (GameRules:State_Get() == DOTA_GAMERULES_STATE_POST_GAME) or (game_state == GAME_STATE_END)
end


-- Clears the inventory and stash of the entity
function ClearInventory(entity)
  if entity and entity.GetItemInSlot then
    for i=0,20 do
      local item = entity:GetItemInSlot(i)

      if item then
        item:Destroy()
      end
    end
  end
end


-- Returns the inventories of every player
-- Returns a list of tables, each with the same format as those returned by GetInventoryOfEntity
function GetPlayerInventories()
  all_inventories = {}
  for i, playerID in pairs(GetPlayerIDs()) do
    local player_hero_handle = PlayerResource:GetSelectedHeroEntity(playerID)

    all_inventories[playerID] = GetInventoryOfEntity(player_hero_handle)
  end
  return all_inventories
end


-- Gets the inventory of the entity
-- Returns a table with items containing the following fields: `name`, `charges`,
-- `secondary_charges`, `is_neutral_item`
-- The items are ordered by their index in the inventory
-- Ignores TP scrolls
function GetInventoryOfEntity(entity)
  local inventory = {}

  for i=0,20 do
    local item = entity:GetItemInSlot(i)

    if item then
      if not (item:GetAbilityName() == "item_tpscroll") then
        inventory[i] = {
          ["name"] = item:GetAbilityName(),
          ["charges"] = item:GetCurrentCharges(),
          ["secondary_charges"] = item:GetSecondaryCharges(),
          ["is_neutral_item"] = IsNeutralItem(item),
        }
      end
    end
  end

  return inventory
end


-- Sets the entity's inventory state to the provided table and adds 3 TP scrolls
-- All created items are owned by item_owner
-- The table should be in the format returned by GetInventoryItems
-- Clears the entity's inventory before adding items
function SetupInventory(entity, item_owner, inventory)
  ClearInventory(entity)

  -- Add TP scrolls
  local tp_scroll = CreateAndConfigureItem("item_tpscroll", item_owner)
  tp_scroll:SetCurrentCharges(3)
  entity:AddItem(tp_scroll)

  -- Occupies the neutral item slot while other neutral items are added
  local dummy_neutral_item = entity:AddItemByName("item_apex")

  -- Add neutral items
  for i=20,0,-1 do
    if i ~= NEUTRAL_ITEM_SLOT then
      local item_info = inventory[i]

      if item_info and (item_info["is_neutral_item"] == true) then
        local item = CreateAndConfigureItem(item_info["name"], item_owner)

        entity:AddItem(item)
        -- Swap with first backpack slot (it's where neutral items go if the neutral slot is filled)
        entity:SwapItems(6, i)
      end
    end
  end

  -- Add the real item to the neutral item slot
  dummy_neutral_item:Destroy()

  local real_neutral_item = inventory[NEUTRAL_ITEM_SLOT]

  if real_neutral_item then
    local item = CreateAndConfigureItem(real_neutral_item["name"], item_owner)
    entity:AddItem(item)
  end

  -- Add normal items
  for i = 20,0,-1 do
    local item = entity:GetItemInSlot(i)

    local item_info = inventory[i]

    -- Neutral items are handled separately
    if item_info and (item_info["is_neutral_item"] == false) then
      local item = CreateAndConfigureItem(item_info["name"], item_owner)

      if item_info["charges"] then
        item:SetCurrentCharges(item_info["charges"])
      end

      if item_info["secondary_charges"] then
        item:SetSecondaryCharges(item_info["secondary_charges"])
      end

      entity:AddItem(item)
      entity:SwapItems(0, i)
    end
  end
end


-- Clears the inventory of the entity
function ClearInventory(entity)
  for i=0,20 do
    local item = entity:GetItemInSlot(i)

    if item then
      item:Destroy()
    end
  end
end


-- Returns the correct localization string for the name of the provided team
-- `winner` should be either DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS
function GetLocalizationTeamName(team)
  -- TODO: replace with custom localization vars to bring back "Radiant" instead of "The Radiant"
  if team == DOTA_TEAM_GOODGUYS then
    return "#DOTA_GoodGuys"
  elseif team == DOTA_TEAM_BADGUYS then
    return "#DOTA_BadGuys"
  end
end


-- Removes all old hero entities, such as those left behind when giving players new heroes
-- NOTE: Do not call this until all spark wraiths have been removed or they will get stuck
-- TODO: try removing this and seeing if clear base works/can be fixed
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

  local old_heroes = {}
  local entity = Entities:First()
  while entity do
    if entity.IsHero and entity:IsHero() then
      if not IsDummyHero(entity) and not hero_entities[entity] then
        -- There doesn't seem to be a way to check whether clones belong to old heroes, so a
        -- time-based check is used here instead. This relies on SetPreviousRoundEndTime being
        -- called at the latest possible time before new heroes are created for players in order to
        -- catch all old heroes/clones. If SetPreviousRoundEndTime is called too early, some old
        -- heroes/clones will persist until the next time RemoveOldHeroes is called, but this
        -- shouldn't cause any issues.
        if entity:GetCreationTime() < PreviousRoundEndTime() then
          table.insert(old_heroes, entity)
        end
      end
    end

    entity = Entities:Next(entity)
  end

  -- Entities are removed in a separate loop to avoid iterator invalidation
  for i, old_hero in pairs(old_heroes) do
    UTIL_Remove(old_hero)
  end
end


-- Returns whether the player with the provided ID is a bot
function IsBot(id)
  return #tostring(PlayerResource:GetSteamID(id)) == 1
end


-- Sets the add bot button's enabled state to the provided value
function EnableAddBotButton(enabled)
  local data = {}
  data.enabled = enabled

  CustomGameEventManager:Send_ServerToAllClients("enable_add_bot_button", data)
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


-- Returns whether the provided entity is a clone
function IsClone(entity)
  local player_id = entity:GetPlayerOwnerID()

  if player_id then
    local player_hero = PlayerResource:GetSelectedHeroEntity(player_id)

    if not player_hero then
      return false
    end

    return (entity:GetName() == player_hero:GetName()) and (entity ~= player_hero) and not entity:IsIllusion()
  else
    return false
  end
end


-- Returns whether a 1v1 map is being played
function IsOneVsOneMap()
  return GameRules:GetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS) == 1
end


-- Returns whether a 1v1 game is being played, regardless of the map being played on
function IsOneVsOneGame()
  return PlayerResource:GetPlayerCountForTeam(DOTA_TEAM_GOODGUYS) == 1
    and PlayerResource:GetPlayerCountForTeam(DOTA_TEAM_BADGUYS) == 1
end


-- Returns whether the item is a neutral item
function IsNeutralItem(item)
  return item:IsNeutralDrop()
end


-- Calls `fn` with all items in the player's inventory and their bear's inventory
-- fn should be of type function(entity, item)
function MapInventoryItems(player_id, fn)
  local hero = PlayerResource:GetSelectedHeroEntity(player_id)

  for i=0,20 do
    local item = hero:GetItemInSlot(i)

    if item then
      fn(hero, item)
    end
  end

  for j, entity in pairs(Entities:FindAllByName("npc_dota_lone_druid_bear")) do
    if entity:GetOwnerEntity() == hero then
      for i=0,20 do
        local item = entity:GetItemInSlot(i)

        if item then
          fn(entity, item)
        end
      end
    end
  end
end


-- Returns whether the entity has consumed an aghanim's scepter
function HasConsumedScepter(entity)
  return entity:HasModifier("modifier_item_ultimate_scepter_consumed")
end


-- Returns whether the entity has consumed a scepter shard
function HasScepterShard(entity)
  return entity:HasModifier("modifier_item_aghanims_shard")
end


-- Sets the music status for all players
function SetMusicStatus(status, intensity)
  for i, player_id in pairs(GetPlayerIDs()) do
    local player = PlayerResource:GetPlayer(player_id)
    -- NOTE: Currently disabled because it is buggy
    -- TODO: investigate SetCustomGameAllowHeroPickMusic
    -- player:SetMusicStatus(status, intensity)
  end
end


-- Sends a message to all client consoles
function SendServerMessage(text)
  local data = {}
  data.text = text
  CustomGameEventManager:Send_ServerToAllClients("server_message", data)
end


-- Creates and returns an item owned by `owner`, setting its purchaser and disabling it as
-- necessary
-- This should always be used over CreateItem
function CreateAndConfigureItem(name, owner)
  local item = CreateItem(name, owner, owner)

  -- Make the item sellable (important for neutral items)
  item:SetPurchaser(owner)
  item:SetSellable(true)

  -- Disable seer stone to prevent abuse (will be re-enabled at round start)
  if item:GetAbilityName() == "item_seer_stone" then
    item:SetActivated(false)
  end

  return item
end


-- Kills the provided NPC, bypassing shallow grave and similar effects
-- Does not prevent reincarnation
function KillNPC(entity)
  ClearBuffs(entity)
  entity:Kill(nil, activator)
end


-- Replaces a player's hero with a new one and returns the new entity
function ReplaceHero(player_id, hero_name)
  -- Clear inventory to prevent reaching the items purchased limit
  local old_hero = PlayerResource:GetSelectedHeroEntity(player_id)

  if old_hero then
    -- If the player already has a hero entity, it can simply be replaced with the built-in function
    ClearInventory(old_hero)

    -- The new hero must be level 1 so that OnNPCSpawned will detect it as newly spawned
    return PlayerResource:ReplaceHeroWith(player_id, hero_name, 1, 1)
  else
    -- Otherwise, a new hero entity must be created and manually assigned
    local player = PlayerResource:GetPlayer(player_id)
    local hero = CreateHeroForPlayer(hero_name, player)

    hero:SetControllableByPlayer(player_id, false)
    -- Add stun modifier manually because the trigger takes a few seconds to add it for some reason
    hero:AddNewModifier(hero, nil, "modifier_stun", {})

    player:SetSelectedHero(hero_name)
    player:SetAssignedHeroEntity(hero)

    return hero
  end
end
