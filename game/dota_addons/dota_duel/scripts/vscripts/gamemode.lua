-- This is the primary barebones gamemode script and should be used to assist in initializing your game mode
BAREBONES_VERSION = "1.00"

-- Set this to true if you want to see a complete debug output of all events/processes done by barebones
-- You can also change the cvar 'barebones_spew' at any time to 1 or 0 for output/no output
BAREBONES_DEBUG_SPEW = false 

if GameMode == nil then
    DebugPrint( '[BAREBONES] creating barebones game mode' )
    _G.GameMode = class({})
end

-- This library allow for easily delayed/timed actions
require('libraries/timers')
-- This library can be used for advancted physics/motion/collision of units.  See PhysicsReadme.txt for more information.
require('libraries/physics')
-- This library can be used for advanced 3D projectile systems.
require('libraries/projectiles')
-- This library can be used for sending panorama notifications to the UIs of players/teams/everyone
require('libraries/notifications')
-- This library can be used for starting customized animations on units from lua
require('libraries/animations')
-- This library can be used for performing "Frankenstein" attachments on units
require('libraries/attachments')
-- This library can be used to synchronize client-server data via player/client-specific nettables
require('libraries/playertables')
-- This library can be used to create container inventories or container shops
require('libraries/containers')
-- This library provides a searchable, automatically updating lua API in the tools-mode via "modmaker_api" console command
require('libraries/modmaker')
-- This library provides an automatic graph construction of path_corner entities within the map
require('libraries/pathgraph')
-- This library (by Noya) provides player selection inspection and management from server lua
require('libraries/selection')

-- These internal libraries set up barebones's events and processes.  Feel free to inspect them/change them if you need to.
require('internal/gamemode')
require('internal/events')

-- settings.lua is where you can specify many different properties for your game mode and is one of the core barebones files.
require('settings')
-- events.lua is where you can specify the actions to be taken when any event occurs and is one of the core barebones files.
require('events')


-- Gamemode modules (not barebones)
require('rounds')
require('modifiers')
require('initialize')
require('ready')
require('round_timer')
require('round_timeout_timer')
require('rematch_timer')
require('rematch')
require('kills')
require('hero_select')
require('hero_select_timer')
require('surrender')
require('ui')
require('neutral_item_shop')
require('bot/bot')
require('stat_tracking')


-- Constants
DUMMY_HERO_POSITION = Vector(5000, -5000, 128)
DUMMY_HERO_NAME = "npc_dota_hero_lina"
-- When players are purchasing items before rounds
GAME_STATE_BUY = 1
-- When players are fighting in the arena
GAME_STATE_FIGHT = 2
-- When players are voting whether to rematch
GAME_STATE_REMATCH = 3
-- When players are selecting new heroes in between games
GAME_STATE_HERO_SELECT = 4
-- When heroes are being loaded for a rematch
GAME_STATE_HERO_LOAD = 5
-- When a team has won and a rematch was not voted for
GAME_STATE_END = 6

-- Global variables
game_state = GAME_STATE_BUY
all_players_connected = true
-- Whether the current round is the first round of the first game (false for first rounds of
-- rematches)
first_round = true
-- Whether AddCurrentGameStats was called this game (reset each rematch)
added_current_game_stats = false


-- Sets the game state
-- Also sets the music status
function SetGameState(new_state)
  Timers:RemoveTimer("set_music")

  new_state_str = tostring(new_state)

  if new_state == GAME_STATE_BUY then
    local set_music = function()
      -- NOTE: This doesn't work for some reason
      SetMusicStatus(DOTA_MUSIC_STATUS_EXPLORATION, 5.0)
    end

    local args = {
      endTime = 5.0,
      callback = set_music,
    }

    Timers:CreateTimer("set_music", args)

    new_state_str = "GAME_STATE_BUY"
  elseif new_state == GAME_STATE_FIGHT then
    new_state_str = "GAME_STATE_FIGHT"
    SetMusicStatus(DOTA_MUSIC_STATUS_BATTLE, 0.1)
  elseif new_state == GAME_STATE_REMATCH then
    new_state_str = "GAME_STATE_REMATCH"
    SetMusicStatus(DOTA_MUSIC_STATUS_NONE, 0.0)
  elseif new_state == GAME_STATE_HERO_SELECT then
    new_state_str = "GAME_STATE_HERO_SELECT"
  elseif new_state == GAME_STATE_HERO_LOAD then
    new_state_str = "GAME_STATE_HERO_LOAD"
  elseif new_state == GAME_STATE_END then
    new_state_str = "GAME_STATE_END"
  end

  print("SetGameState(" .. new_state_str .. ")")
  game_state = new_state
end


--[[
  This function should be used to set up Async precache calls at the beginning of the gameplay.

  In this function, place all of your PrecacheItemByNameAsync and PrecacheUnitByNameAsync.  These calls will be made
  after all players have loaded in, but before they have selected their heroes. PrecacheItemByNameAsync can also
  be used to precache dynamically-added datadriven abilities instead of items.  PrecacheUnitByNameAsync will 
  precache the precache{} block statement of the unit and all precache{} block statements for every Ability# 
  defined on the unit.

  This function should only be called once.  If you want to/need to precache more items/abilities/units at a later
  time, you can call the functions individually (for example if you want to precache units in a new wave of
  holdout).

  This function should generally only be used if the Precache() function in addon_game_mode.lua is not working.
]]
function GameMode:PostLoadPrecache()
end

--[[
  This function is called once and only once as soon as the first player (almost certain to be the server in local lobbies) loads in.
  It can be used to initialize state that isn't initializeable in InitGameMode() but needs to be done before everyone loads in.
]]
function GameMode:OnFirstPlayerLoaded()
end

--[[
  This function is called once and only once after all players have loaded into the game, right as the hero selection time begins.
  It can be used to initialize non-hero player state or adjust the hero selection (i.e. force random etc)
]]
function GameMode:OnAllPlayersLoaded()
end

--[[
  This function is called once and only once for every player when they spawn into the game for the first time.  It is also called
  if the player's hero is replaced with a new hero for any reason.  This function is useful for initializing heroes, such as adding
  levels, changing the starting gold, removing/adding abilities, adding physics, etc.

  The hero parameter is the hero entity that just spawned in
]]
function GameMode:OnHeroInGame(hero)
end

-- Called each time a new game starts (at the start of the match and each time a rematch starts)
function GameMode:OnGameInProgress()
  DebugPrint("[BAREBONES] The game has officially begun")

  Notifications:ClearBottomFromAll()

  SetGameState(GAME_STATE_BUY)
  GameRules:SetTimeOfDay(0.5)

  added_current_game_stats = false

  -- To prevent people from spawning outside the shop area
  ResetPlayers(true)

  InitNeutrals()
  InitReadyUpData()
  InitVoteRematchData()
  ResetKills()
  InitHeroSelectData()
  SetMusicStatus(DOTA_MUSIC_STATUS_NONE, 0.0)

  for i, player_id in pairs(GetPlayerIDs()) do
    -- Make the player lose if they didn't pick a hero
    if PlayerResource:GetSelectedHeroName(player_id) == "" then
      MakePlayerLose(player_id, "#duel_no_selected_hero", true, VICTORY_REASON_NO_HERO)
      return
    end
  end

  -- Hide the vote rematch UI and show the surrender UI
  CustomGameEventManager:Send_ServerToAllClients("start_game", nil)
  -- Reset the ready-up UI (necessary because players can ready-up while heroes are loading,
  -- preventing them from readying up again after the ready-up data is reset here)
  local data = {}
  data.enable_surrender = true
  CustomGameEventManager:Send_ServerToAllClients("end_round", data)

  -- Start the first round after 60 seconds
  -- TODO: try doing this before showing the ready-up UI to fix the "[!d:seconds]" bug (also in
  --       EndRound)
  local game_start_delay = 60
  SetRoundStartTimer(game_start_delay)

  -- Enable the add bot button
  local enable_button = function()
    -- EnableAddBotButton(true)
  end

  -- There must be a delay for events to be properly sent at the time this function is called
  Timers:CreateTimer(2.0, enable_button)

  -- Trigger bot actions for the match start after all heroes have loaded (handled by rematch
  -- system, but this is necessary for the first match)
  Timers:CreateTimer(function()
    -- Check that all players have a hero entity
    for _, id in pairs(GetPlayerIDs()) do
      -- If a hero doesn't exist for a player, wait a second before checking again
      if not PlayerResource:GetSelectedHeroEntity(id) then
        return 1.0
      end
    end

    BotOnMatchStart()
  end)
end

-- This function initializes the game mode and is called before anyone loads into the game
-- It can be used to pre-initialize any values/tables that will be needed later
function GameMode:InitGameMode()
  GameMode = self

  local gamemode_entity = GameRules:GetGameModeEntity()

  -- Disable neutral item stash (clearing it crashes the game so it is just disabled)
  gamemode_entity:SetNeutralStashEnabled(false)

  -- Disable neutral item drops
  gamemode_entity:SetAllowNeutralItemDrops(false)

  -- Disable default music (broken)
  GameRules:SetCustomGameAllowBattleMusic(false)
  GameRules:SetCustomGameAllowHeroPickMusic(true)
  GameRules:SetCustomGameAllowMusicAtGameStart(false)

  -- Set a small strategy time so that players don't have to wait
  -- It is non-zero to give players time to load everything and avoid crashes on low-end machines
  GameRules:SetStrategyTime(3.0)

  -- Disable pregame time for accurate match duration
  GameRules:SetPreGameTime(0.0)

  -- Make hero selection fast
  GameRules:SetHeroSelectPenaltyTime(0)
  GameRules:SetHeroSelectionTime(30)

  -- So picking is feasible with host_timescale at 10
  if IsInToolsMode() then
    GameRules:SetHeroSelectionTime(60)
  end

  -- Disable scan (the only alternative is resetting it every round, however that would affect the
  -- game balance too much)
  gamemode_entity:SetCustomScanCooldown(999999999.0)

  -- Initialize listeners
  ListenToGameEvent("entity_killed", OnEntityDeath, nil)
  CustomGameEventManager:RegisterListener("player_surrender_js", OnSurrender)
  CustomGameEventManager:RegisterListener("player_ready_js", OnReadyUp)
  CustomGameEventManager:RegisterListener("player_vote_rematch_js", OnVoteRematch)
  CustomGameEventManager:RegisterListener("player_select_hero_js", OnSelectHero)
  CustomGameEventManager:RegisterListener("add_bot", FillEmptySlotsWithBots)
  CustomGameEventManager:RegisterListener("bot_message_localized", OnBotSayAllChat)
  CustomGameEventManager:RegisterListener("player_ui_loaded", SetupUI)
  CustomGameEventManager:RegisterListener("player_purchase_neutral_item", OnPlayerPurchaseNeutralItem)

  InitKills()

  -- Give infinite gold
  Timers:CreateTimer(GivePassiveGold)

  -- Watch for player disconnect
  Timers:CreateTimer(WatchForDisconnect)

  -- Create a dummy hero used in DestroyDroppedGems
  local dummy = CreateUnitByName(
    DUMMY_HERO_NAME,
    DUMMY_HERO_POSITION,
    false,
    nil,
    nil,
    DOTA_TEAM_CUSTOM_3
  )
  local data = {}
  -- Make the dummy unable to affect gameplay
  dummy:AddNewModifier(dummy, nil, "modifier_stun", data)

  for i, entity in pairs(Entities:FindAllByName("ent_dota_shop")) do
    entity:SetShopType(0)
  end
end


-- Gives 99999 gold to all players
function GivePassiveGold()
  for i, playerID in pairs(GetPlayerIDs()) do
    PlayerResource:ModifyGold(playerID, 99999, true, DOTA_ModifyGold_GameTick)
  end

  return 1.0
end


-- A function that tests if a player has disconnected and makes them lose the game
-- Returns a number so it can be used in a timer
player_timeouts = {}
leavers = {
  [DOTA_TEAM_GOODGUYS] = 0,
  [DOTA_TEAM_BADGUYS] = 0,
}
leaver_ids = {}
function WatchForDisconnect(keys)
  local timeout = 120.0

  all_players_connected = true

  for i, playerID in pairs(GetPlayerIDs()) do
    local team = PlayerResource:GetTeam(playerID)

    if (team == DOTA_TEAM_GOODGUYS) or (team == DOTA_TEAM_BADGUYS) then
      local connection_state = PlayerResource:GetConnectionState(playerID)

      -- If a player disconnects for too long or abandons, make them lose and stop watching for disconnects
      if connection_state == DOTA_CONNECTION_STATE_DISCONNECTED then
        all_players_connected = false

        local c = player_timeouts[playerID]
        if c then
          player_timeouts[playerID] = c + 1.0

          print("Player " .. tostring(playerID) .. " disconnected for " .. tostring(player_timeouts[playerID]) .. " seconds")

          if player_timeouts[playerID] > timeout and leaver_ids[playerID] == nil then
            leavers[team] = leavers[team] + 1
            leaver_ids[playerID] = true
          end
        end
      else
        if connection_state == DOTA_CONNECTION_STATE_ABANDONED and leaver_ids[playerID] == nil then
          leavers[team] = leavers[team] + 1
          leaver_ids[playerID] = true
        else
          player_timeouts[playerID] = 0.0

          -- Allows reconnecting after the timeout if a teammate is still in the game
          if leaver_ids[playerID] then
            leaver_ids[playerID] = nil
            leavers[team] = leavers[team] - 1
          end
        end
      end
    end
  end

  for team, leaver_count in pairs(leavers) do
    -- So the game doesn't end when playing solo (such as when testing)
    if leaver_count > 0 then
      -- Make the team lose if all of its players have left
      if leaver_count >= PlayerResource:GetPlayerCountForTeam(team) then
        MakeTeamLose(team, "#duel_disconnect", false, VICTORY_REASON_DISCONNECT)
        return nil
      end
    end
  end

  return 1.0
end


-- Makes the provided player lose, and sends a notification to all players with the provided text
-- If allow_rematch is false, the UI will be hidden and the game will end after a few seconds
-- `victory_reason` should be one of VICTORY_REASON_*
function MakePlayerLose(playerID, text, allow_rematch, victory_reason)
  local team = PlayerResource:GetTeam(playerID)

  MakeTeamLose(team, text, allow_rematch, victory_reason)
end


-- Makes the provided team lose, and sends a notification to all players with the provided text
-- If allow_rematch is false, the UI will be hidden and the game will end after a few seconds
-- `victory_reason` should be one of VICTORY_REASON_*
function MakeTeamLose(team, text, allow_rematch, victory_reason)
  if IsMatchEnded() or game_state == GAME_STATE_REMATCH then
    return
  end

  local opposite_team = GetOppositeTeam(team)

  -- Spectators don't have an opposite team
  if not opposite_team then
    return
  end

  local opposite_team_name = GetLocalizationTeamName(opposite_team)

  -- Send a notification
  Notifications:ClearBottomFromAll()
  Notifications:BottomToAll({
    text = "#duel_player_lose",
    duration = 60,
    vars = {
      reason = text,
      team = opposite_team_name,
    }
  })

  -- Make the disconnected player lose
  game_result = opposite_team

  if allow_rematch then
    EndGameDelayed(game_result, victory_reason, nil, nil)
  else
    SetGameState(GAME_STATE_END)

    local end_game = function()
      AddCurrentGameStats(victory_reason)
      EndGame()
    end

    -- Has a delay to let players see the notification
    local end_game_delay = 3.0

    Timers:CreateTimer(end_game_delay, end_game)
  end
end


-- Shuffles all teams
function ShuffleTeams()
  if IsServer() then
    local player_ids = GetPlayerIDs()

    -- Unassign all players
    for i, player_id in pairs(player_ids) do
      PlayerResource:SetCustomTeamAssignment(player_id, DOTA_TEAM_NOTEAM)
    end

    -- Set random teams
    -- GetPlayerIDs only includes players on radiant/dire so it can't be used here
    for player_id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
      if PlayerResource:IsValidPlayerID(player_id) then
        local team = PlayerResource:GetTeam(player_id)

        if team == DOTA_TEAM_NOTEAM then
          -- Create a list of empty player slots to weight the teams properly
          local teams = {}

          for i=1,GetEmptyPlayerSlots(DOTA_TEAM_GOODGUYS) do
            table.insert(teams, DOTA_TEAM_GOODGUYS)
          end

          for i=1,GetEmptyPlayerSlots(DOTA_TEAM_BADGUYS) do
            table.insert(teams, DOTA_TEAM_BADGUYS)
          end

          -- Choose a random team from the list
          local random_team = teams[RandomInt(1, #teams)]
          PlayerResource:SetCustomTeamAssignment(player_id, random_team)
        end
      end
    end
  end
end


-- Returns the number of empty player slots on a team
function GetEmptyPlayerSlots(team)
  return GameRules:GetCustomGameTeamMaxPlayers(team) - PlayerResource:GetPlayerCountForTeam(team)
end
