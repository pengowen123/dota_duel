-- Tracking for match statistics


STAT_SERVER = "https://dota-duel-stat-tracking.firebaseio.com/"
if IsInToolsMode() then
  STAT_SERVER = STAT_SERVER .. "db-testing"
else
  STAT_SERVER = STAT_SERVER .. GetDedicatedServerKeyV2("dota-duel-db-1.0")
end
STAT_SERVER = STAT_SERVER .. "/"

-- A team won 5 rounds
VICTORY_REASON_ROUNDS = 0
-- A team reached surrendered
VICTORY_REASON_SURRENDER = 1
-- A team disconnected
VICTORY_REASON_DISCONNECT = 2
-- A player didn't pick a hero
VICTORY_REASON_NO_HERO = 3


game_stats = {
  match_id = tostring(GameRules:GetMatchID()),
  map = GetMapName(),
  player_count = 0,
  bot_player_count = 0,
  players = {},
  duration = nil,
  round_count = 0,
  rounds = {},
}

game_stats_short = {
  match_id = game_stats.match_id,
  players = {},
}

-- Player stats from current match (keys are player IDs)
player_stats = {}
-- Player stats from stat tracking server (keys are player IDs)
player_stats_from_db = {}


-- Gathers and sends the stats for the current match to the stat tracking server
-- Doesn't send the data when in tools mode
function GatherAndSendMatchStats()
  if not IsServer() then
    return
  end

  GatherMatchStats()

  if not ShouldMatchBeTracked() then
    return
  end

  -- Send data for the match
  local post_error_msg = "Failed to send match data to stat tracking server"
  SendStats("POST", "matches.json", game_stats, post_error_msg)
  SendStats("POST", "matches_short.json", game_stats_short, post_error_msg)

  local bot_in_game = false
  for player_id, steam_id in pairs(GetPlayerSteamIDs()) do
    bot_in_game = bot_in_game or IsBot(player_id)
  end

  -- Update individual player stats
  for player_id, steam_id in pairs(GetPlayerSteamIDs()) do
    local get_error_msg = "Failed to send player data to stat tracking server"

    local callback = function(obj)
      local new_player_stats = {
        wins = obj.wins + player_stats[player_id].wins,
        losses = obj.losses + player_stats[player_id].losses,
      }

      SendStats("PUT", GetPlayerURL(steam_id), new_player_stats, get_error_msg)
    end

    -- Update only the bot's stats in bot matches (so that players can't abuse them for wins)
    if (not bot_in_game) or IsBot(player_id) then
      GetPlayerStats(player_id, callback)
    end
  end
end


-- Sends the provided data to the url at the stat tracking server
function SendStats(method, url, data, error_msg)
  if not IsServer() then
    return
  end

  local req = CreateHTTPRequestScriptVM(method, STAT_SERVER .. url)

  local encoded_data = json.encode(data)
  req:SetHTTPRequestRawPostBody("application/json", encoded_data)

  local callback = function(res)
    if res.StatusCode ~= 200 then
      local message = error_msg .. "\nStatus code: " .. tostring(res.StatusCode)
      SendServerMessage(message)
    end
  end

  req:Send(callback)
end


-- Gathers stats for the current match
function GatherMatchStats()
  if not IsServer() then
    return
  end

  game_stats.duration = GameRules:GetDOTATime(true, true)
  game_stats.player_count = 0
  game_stats.bot_player_count = 0
  game_stats.players = GetPlayerSteamIDs()
  game_stats_short.players = game_stats.players
  game_stats.round_count = #game_stats.rounds

  for i, player_id in pairs(GetPlayerIDs()) do
    if ShouldTrackStatsForPlayer(player_id) then
      game_stats.player_count = game_stats.player_count + 1

      if IsBot(player_id) then
        game_stats.bot_player_count = game_stats.bot_player_count + 1
      end
    end
  end

  if game_stats.player_count <= 1 then
    return
  end

  local message = ""
  message = message .. "Match Statistics\n"
  message = message .. "------------------\n"
  message = message .. "match_id: " .. tostring(game_stats.match_id) .. "\n"
  message = message .. "map: " .. tostring(game_stats.map) .. "\n"
  message = message .. "duration: " .. tostring(game_stats.duration) .. "\n"
  message = message .. "players: " .. GetArrayString(game_stats.players) .. "\n"
  message = message .. "player_count: " .. tostring(game_stats.player_count) .. "\n"
  message = message .. "bot_player_count: " .. tostring(game_stats.bot_player_count) .. "\n"
  message = message .. "round_count: " .. tostring(game_stats.round_count) .. "\n"
  message = message .. "rounds: [\n"
  for i, round in pairs(game_stats.rounds) do
    message = message .. "{\n"
    message = message .. "\tscore_radiant: " .. tostring(round.score_radiant) .. "\n"
    message = message .. "\tscore_dire: " .. tostring(round.score_dire) .. "\n"
    message = message .. "\twinner: " .. GetWinnerString(round.winner) .. "\n"
    message = message .. "\tvictory_reason: " .. GetVictoryReasonString(round.victory_reason) .. "\n"
    message = message .. "\theroes_radiant: " .. GetArrayString(round.heroes_radiant) .. "\n"
    message = message .. "\theroes_dire: " .. GetArrayString(round.heroes_dire) .. "\n"
    message = message .. "\tplayers_radiant: " .. GetArrayString(round.players_radiant) .. "\n"
    message = message .. "\tplayers_dire: " .. GetArrayString(round.players_dire) .. "\n"
    message = message .. "}"

    if i ~= #game_stats.rounds then
      message = message .. ","
    end

    message = message .. "\n"
  end

  message = message .. "]"

  SendServerMessage(message)
end


-- Requests the data for the provided player from the database and calls `callback` with it
-- Uses cached data when available
function GetPlayerStats(player_id, callback)
  local steam_id = tostring(PlayerResource:GetSteamID(player_id))
  local player_url = GetPlayerURL(steam_id)
  local get_req = CreateHTTPRequestScriptVM("GET", STAT_SERVER .. player_url)

  -- Check if data has already been retrieved from the DB
  if player_stats_from_db[player_id] then
    callback(player_stats_from_db[player_id])
    return
  end

  local callback_internal = function(res)
    if res.StatusCode ~= 200 then
      local message = "Failed to get player data from stat tracking server: " .. tostring(res.StatusCode)
      SendServerMessage(message)
      return
    end

    local obj, pos, err = json.decode(res.Body)

    if not obj then
      -- Initialize player stats for new players
      obj = InitialPlayerStats()
    end

    player_stats_from_db[player_id] = obj

    callback(obj)
  end

  get_req:Send(callback_internal)
end


-- Returns the URL of the table for the provided player relative to the address in STAT_SERVER
function GetPlayerURL(steam_id)
  return "players/" .. tostring(steam_id) .. ".json"
end


-- Adds the current game to the match stats
-- Requires the reason why the current game ended (see VICTORY_REASON_*)
function AddCurrentGameStats(victory_reason)
  if not IsServer() then
    return
  end

  -- Don't add current game stats more than once
  if added_current_game_stats then
    return
  end

  added_current_game_stats = true

  local round = {
    heroes_radiant = {},
    heroes_dire = {},
    players_radiant = {},
    players_dire = {},
    score_radiant = GetRadiantKills(),
    score_dire = GetDireKills(),
    winner = game_result,
    victory_reason = victory_reason,
  }

  for i, player_id in pairs(GetPlayerIDs()) do
    local team = PlayerResource:GetTeam(player_id)

    if ShouldTrackStatsForPlayer(player_id) then
      local steam_id = tostring(PlayerResource:GetSteamID(player_id))
      local hero = PlayerResource:GetSelectedHeroEntity(player_id)
      local hero_name = "none"

      if hero then
        hero_name = hero:GetName()
      end

      -- Add each player's hero to the appropriate team hero list
      if team == DOTA_TEAM_GOODGUYS then
        round.heroes_radiant[player_id] = hero_name
        round.players_radiant[player_id] = steam_id
      elseif team == DOTA_TEAM_BADGUYS then
        round.heroes_dire[player_id] = hero_name
        round.players_dire[player_id] = steam_id
      end

      -- Initialize missing stats
      if not player_stats[player_id] then
        player_stats[player_id] = InitialPlayerStats()
      end

      -- Track wins/losses for each player
      if team == round.winner then
        player_stats[player_id].wins = player_stats[player_id].wins + 1
      else
        player_stats[player_id].losses = player_stats[player_id].losses + 1
      end
    end
  end

  table.insert(game_stats.rounds, round)
end


-- Gathers stats for all players, and updates the stats UI for the provided player, or for all
-- players if none is provided
function UpdatePlayerStatsUI(update_ui_only_for_player)
  local bot_in_game = false
  for player_id, steam_id in pairs(GetPlayerSteamIDs()) do
    bot_in_game = bot_in_game or IsBot(player_id)
  end

  -- Prevents sending unnecessary update events
  local sent_full_update_event = false

  for player_id, steam_id in pairs(GetPlayerSteamIDs()) do
    local callback = function(obj)
      -- Everything is finished once a full update event has been sent
      if sent_full_update_event then
        return
      end

      local data = {
        players = {},
      }

      -- Whether all player data is included in the update event
      local full_update = true

      -- Collect currently available player stats to display
      for player_id, steam_id in pairs(GetPlayerSteamIDs()) do
        if player_stats_from_db[player_id] then
          -- Copy player stats from cache
          data.players[player_id] = {
            wins = player_stats_from_db[player_id].wins,
            losses = player_stats_from_db[player_id].losses,
          }

          -- Initialize missing stats
          if not player_stats[player_id] then
            player_stats[player_id] = InitialPlayerStats()
          end

          -- Don't display updates to stats locally if they won't be updated in the DB
          -- NOTE: ShouldMatchBeTracked can return false initially, then true later if a bot is added,
          --       therefore causing matches played before the bot was added to be incorrectly tracked
          --       for the player.
          --       This is prevented only because player stats are not tracked in bot matches
          --       If it is ever an issue, the matches can be filtered in GatherAndSendMatchStats and
          --       this can be changed to use the filtered stats
          if ((not bot_in_game) or IsBot(player_id)) and ShouldMatchBeTracked() then
            -- Display current player stats added to stats from the DB (live updates without extra DB requests)
            data.players[player_id].wins = data.players[player_id].wins + player_stats[player_id].wins
            data.players[player_id].losses = data.players[player_id].losses + player_stats[player_id].losses
          end
        else
          -- Use new player data while waiting for real data to come in
          full_update = false
          data.players[player_id] = InitialPlayerStats()
        end
      end

      if full_update then
        sent_full_update_event = true
      end

      if update_ui_only_for_player ~= nil then
        CustomGameEventManager:Send_ServerToPlayer(update_ui_only_for_player, "update_player_stats", data)
      else
        CustomGameEventManager:Send_ServerToAllClients("update_player_stats", data)
      end
    end

    GetPlayerStats(player_id, callback)
  end
end


-- Returns initial stats for a new player
function InitialPlayerStats()
  return {
    wins = 0,
    losses = 0,
  }
end


-- Returns the name of the provided team
-- `team` should be either DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS
function GetWinnerString(team)
  if team == DOTA_TEAM_GOODGUYS then
    return "radiant"
  elseif team == DOTA_TEAM_BADGUYS then
    return "dire"
  end
end


-- Returns an array of strings as a single string
function GetArrayString(list)
  local result = "["

  for i, str in pairs(list) do
    result = result .. str

    if i ~= #list then
      result = result .. ", "
    end
  end

  result = result .. "]"

  return result
end


-- Returns the provided victory reason as a string (VICTORY_REASON_*)
function GetVictoryReasonString(reason)
  if reason == VICTORY_REASON_ROUNDS then
    return "VICTORY_REASON_ROUNDS"
  elseif reason == VICTORY_REASON_SURRENDER then
    return "VICTORY_REASON_SURRENDER"
  elseif reason == VICTORY_REASON_DISCONNECT then
    return "VICTORY_REASON_DISCONNECT"
  elseif reason == VICTORY_REASON_NO_HERO then
    return "VICTORY_REASON_NO_HERO"
  end
end


-- Returns pairs containing the player ID and 64-bit Steam ID of each player
-- Only includes players that should have their stats tracked (see ShouldTrackStatsForPlayer)
function GetPlayerSteamIDs()
  local ids = {}

  for i, player_id in pairs(GetPlayerIDs()) do
    if ShouldTrackStatsForPlayer(player_id) then
      ids[player_id] = tostring(PlayerResource:GetSteamID(player_id))
    end
  end

  return ids
end


-- Returns whether the player is not a spectator or dummy hero
function IsActualPlayer(player_id)
  local team = PlayerResource:GetTeam(player_id)
  return (team == DOTA_TEAM_GOODGUYS) or (team == DOTA_TEAM_BADGUYS)
end


-- Returns whether the player is a bot AI added through the add bot button
-- Returns false for bots added with -createhero or other means
function IsRealBot(player_id)
  if global_bot_controller then
    return global_bot_controller.bot_id == player_id
  else
    return false
  end
end


-- Returns whether to track stats for the player
function ShouldTrackStatsForPlayer(player_id)
  return IsActualPlayer(player_id)
    -- Only include bots added through the add bot button
    and ((not IsBot(player_id)) or IsRealBot(player_id))
end


-- Returns whether to track stats for the current match
function ShouldMatchBeTracked()
  local dont_track = false

  -- Don't track solo games (they are probably for testing, and are not worth tracking anyways)
  dont_track = dont_track or (GetPlayerCount() <= 1)

  -- Don't track local lobbies or games with cheats (unless in tools mode)
  dont_track = dont_track or ((not IsInToolsMode()) and (GameRules:IsCheatMode() or not IsDedicatedServer()))

  return not dont_track
end


-- Returns how many players will have their stats tracked
function GetPlayerCount()
  local count = 0

  for i, player_id in pairs(GetPlayerIDs()) do
    if ShouldTrackStatsForPlayer(player_id) then
      count = count + 1
    end
  end

  return count
end