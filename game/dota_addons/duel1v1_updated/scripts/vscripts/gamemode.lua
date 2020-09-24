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
require('rematch_timer')
require('rematch')
require('kills')
require('hero_select')
require('hero_select_timer')
require('surrender')
require('ui')
require('neutral_item_shop')
require('bot/bot')


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

game_state = GAME_STATE_BUY
all_players_connected = true



-- Sets the game state
function SetGameState(new_state)
  new_state_str = tostring(new_state)

  if new_state == GAME_STATE_BUY then
    new_state_str = "GAME_STATE_BUY"
  elseif new_state == GAME_STATE_FIGHT then
    new_state_str = "GAME_STATE_FIGHT"
  elseif new_state == GAME_STATE_REMATCH then
    new_state_str = "GAME_STATE_REMATCH"
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

--[[
  This function is called once and only once when the game completely begins (about 0:00 on the clock).  At this point,
  gold will begin to go up in ticks if configured, creeps will spawn, towers will become damageable etc.  This function
  is useful for starting any game logic timers/thinkers, beginning the first round, etc.
]]
function GameMode:OnGameInProgress()
  DebugPrint("[BAREBONES] The game has officially begun")

  Notifications:ClearBottomFromAll()

  SetGameState(GAME_STATE_BUY)

  -- Level up players with a delay because if a player picks at the last possible second
  -- they won't get levels if this is called instantly
  Timers:CreateTimer(0.5, LevelUpPlayers)
  Timers:CreateTimer(0.5, RemoveTPScroll)

  -- Hide the vote rematch UI and show the surrender UI
  CustomGameEventManager:Send_ServerToAllClients("start_game", nil)
  -- Reset the ready-up UI (necessary because players can ready-up while heroes are loading,
  -- preventing them from readying up again after the ready-up data is reset here)
  local data = {}
  data.enable_surrender = true
  CustomGameEventManager:Send_ServerToAllClients("end_round", data)

  -- To prevent people from spawning outside the shop area
  ResetPlayers(true)

  InitNeutrals()
  InitReadyUpData()
  InitVoteRematchData()
  ResetKills()
  InitHeroSelectData()

  -- Start the first round after 60 seconds
  local game_start_delay = 60
  SetRoundStartTimer(game_start_delay)

  -- Enable the add bot button if there is only one player and they are on the 1v1 map
  if CanAddBot() then
    local enable_button = function()
      EnableAddBotButton(true)
    end

    -- There must be a delay for events to be properly sent at the time this function is called
    Timers:CreateTimer(2.0, enable_button)
  end
end

-- This function initializes the game mode and is called before anyone loads into the game
-- It can be used to pre-initialize any values/tables that will be needed later
function GameMode:InitGameMode()
  GameMode = self

  -- Skip strategy time to save players time (it's useless in this gamemode)
  GameRules:SetStrategyTime(0.5)

  -- Make hero selection fast
  GameRules:SetHeroSelectPenaltyTime(0)
  GameRules:SetHeroSelectionTime(15)

  -- So picking is feasible with host_timescale at 10
  if IsInToolsMode() then
    GameRules:SetHeroSelectionTime(60)
  end

  -- Disable scan (the only alternative is resetting it every round, however that would affect the
  -- game balance too much)
  GameRules:GetGameModeEntity():SetCustomScanCooldown(999999999.0)

  -- Initialize listeners
  ListenToGameEvent("entity_killed", OnEntityDeath, nil)
  CustomGameEventManager:RegisterListener("player_surrender_js", OnSurrender)
  CustomGameEventManager:RegisterListener("player_ready_js", OnReadyUp)
  CustomGameEventManager:RegisterListener("player_vote_rematch_js", OnVoteRematch)
  CustomGameEventManager:RegisterListener("player_select_hero_js", OnSelectHero)
  CustomGameEventManager:RegisterListener("add_bot", OnAddBot)
  CustomGameEventManager:RegisterListener("bot_message_localized", OnBotSayAllChat)
  CustomGameEventManager:RegisterListener("player_ui_loaded", SetupUI)
  CustomGameEventManager:RegisterListener("player_purchase_neutral_item", OnPlayerPurchaseNeutralItem)
  InitKills()

  -- Give infinite gold
  Timers:CreateTimer(GivePassiveGold)

  -- Watch for player disconnect
  Timers:CreateTimer(WatchForDisconnect)

  -- Cause infinite respawn time
  GameRules:SetHeroRespawnEnabled(false)

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
        if player_timeouts[playerID] > timeout then
          leavers[team] = leavers[team] - 1
          leaver_ids[playerID] = nil
        end
      end
    end
  end

  for team, leaver_count in pairs(leavers) do
    -- So the game doesn't end when playing solo (such as when testing)
    if leaver_count > 0 then
      -- Make the team lose if all of its players have left
      if leaver_count >= PlayerResource:GetPlayerCountForTeam(team) then
        MakeTeamLose(team, "#duel_disconnect")
        return nil
      end
    end
  end

  return 1.0
end


-- Makes the provided player lose, and sends a notification to all players with the provided text
function MakePlayerLose(playerID, text)
  local team = PlayerResource:GetTeam(playerID)

  MakeTeamLose(team, text)
end


-- Makes the provided team lose, and sends a notification to all players with the provided text
function MakeTeamLose(team, text)
  if IsMatchEnded() then
    return
  end

  SetGameState(GAME_STATE_END)

  local opposite_team = GetOppositeTeam(team)
  local opposite_team_name = GetLocalizationTeamName(opposite_team)

  -- Make the disconnected player lose
  -- Has a delay to let players see the notification
  local end_game = function()
    game_result = opposite_team
    EndGame()
  end
  local end_game_delay = 3.0

  Timers:CreateTimer(end_game_delay, end_game)
  
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
end
