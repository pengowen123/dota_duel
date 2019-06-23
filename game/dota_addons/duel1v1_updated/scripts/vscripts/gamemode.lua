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


-- Constants
game_ended = false


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

  -- Level up players with a delay because if a player picks at the last possible second
  -- they won't get levels if this is called instantly
  Timers:CreateTimer(0.1, LevelUpPlayers)
  Timers:CreateTimer(0.1, RemoveTPScroll)

  -- Hide the vote rematch UI
  CustomGameEventManager:Send_ServerToAllClients("start_game", nil)
  -- Show the surrender UI
  CustomGameEventManager:Send_ServerToAllClients("enable_surrender", nil)

  -- To prevent people from spawning outside the shop area
  ResetPlayers(true)

  InitNeutrals()
  InitReadyUpData()
  InitVoteRematchData()
  ResetKills()
  InitHeroSelectData()

  game_ended = false

  -- Start the first round after 60 seconds
  local game_start_delay = 60
  SetRoundStartTimer(game_start_delay)
end

-- This function initializes the game mode and is called before anyone loads into the game
-- It can be used to pre-initialize any values/tables that will be needed later
function GameMode:InitGameMode()
  GameMode = self

  -- Skip strategy time to save players time (it's useless in this gamemode)
  GameRules:SetStrategyTime(0.5)

  -- Initialize listeners
  ListenToGameEvent("entity_killed", OnEntityDeath, nil)
  CustomGameEventManager:RegisterListener("player_surrender_js", OnSurrender)
  CustomGameEventManager:RegisterListener("player_ready_js", OnReadyUp)
  CustomGameEventManager:RegisterListener("player_vote_rematch_js", OnVoteRematch)
  CustomGameEventManager:RegisterListener("player_select_hero_js", OnSelectHero)
  InitKills()

  -- Watch for player disconnect
  Timers:CreateTimer(WatchForDisconnect)

  -- Cause infinite respawn time
  GameRules:SetHeroRespawnEnabled(false)
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

  for i, playerID in pairs(GetPlayerIDs()) do
    local team = PlayerResource:GetTeam(playerID)

    local connection_state = PlayerResource:GetConnectionState(playerID)

    -- If a player disconnects, make them lose and stop watching for disconnects
    if connection_state == DOTA_CONNECTION_STATE_DISCONNECTED then
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

  local opposite_team = GetOppositeTeam(team)
  local opposite_team_name = GetLocalizationTeamName(opposite_team)

  -- Make the disconnected player lose
  -- Has a delay to let players see the notification
  local end_game = function()
    GameRules:MakeTeamLose(team)
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
