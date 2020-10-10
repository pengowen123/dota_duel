-- Tracking for match statistics


STAT_SERVER = "https://dota-duel-stat-tracking.firebaseio.com/"
if IsInToolsMode() then
  STAT_SERVER = STAT_SERVER .. "db-testing"
else
  STAT_SERVER = STAT_SERVER .. GetDedicatedServerKeyV2("dota-duel-db-1.0")
end
STAT_SERVER = STAT_SERVER .. "/"

AUTHOR_STEAM_ID = "76561198115574919"

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
  author_in_game = false,
  player_count = 0,
  bot_player_count = 0,
  players = {},
  duration = nil,
  round_count = 0,
  rounds = {},
}

player_stats = {}


-- Gathers and sends the stats for the current match to the stat tracking server
-- Doesn't send the data when in tools mode
function GatherAndSendMatchStats()
  if not IsServer() then
    return
  end

  GatherMatchStats()

  -- Don't track matches played while developing the gamemode
  if IsInToolsMode() then
    return
  end

  -- Don't track solo games (they are probably for testing, and are not worth tracking anyways)
  if game_stats.player_count <= 1 then
    return
  end

  -- Send data for the match
  SendStats("POST", "matches.json", game_stats, "Failed to send match data to stat tracking server")

  -- Update individual player stats
  for i, steam_id in pairs(GetPlayerSteamIDs()) do
    local player_url = "players/" .. tostring(steam_id) .. ".json"
    local get_req = CreateHTTPRequestScriptVM("GET", STAT_SERVER .. player_url)

    local callback = function(res)
      if res.StatusCode ~= 200 then
        local message = "Failed to get player data from stat tracking server: " .. tostring(res.StatusCode)
        SendServerMessage(message)
      end

      local obj, pos, err = json.decode(res.Body)

      if not obj then
        -- Initialize player stats for new players
        obj = {
          wins = 0,
          losses = 0,
        }
      end

      local new_player_stats = {
        wins = obj.wins + player_stats[steam_id].wins,
        losses = obj.losses + player_stats[steam_id].losses,
      }

      SendStats("PUT", player_url, new_player_stats, "Failed to send player data to stat tracking server")
    end

    get_req:Send(callback)
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
  game_stats.round_count = #game_stats.rounds

  for i, player_id in pairs(GetPlayerIDs()) do
    local team = PlayerResource:GetTeam(player_id)

    if IsActualPlayer(player_id) then
      game_stats.player_count = game_stats.player_count + 1

      if tostring(PlayerResource:GetSteamID(player_id)) == AUTHOR_STEAM_ID then
        game_stats.author_in_game = true
      elseif IsBot(player_id) then
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
  message = message .. "author_in_game: " .. tostring(game_stats.author_in_game) .. "\n"
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


-- Adds the current game to the match stats
-- Requires the reason why the current game ended (see VICTORY_REASON_*)
function AddCurrentGameStats(victory_reason)
  if not IsServer() then
    return
  end

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

    if IsActualPlayer(player_id) then
      local steam_id = tostring(PlayerResource:GetSteamID(player_id))
      local hero = PlayerResource:GetSelectedHeroEntity(player_id)
      local hero_name = "none"

      if hero then
        hero_name = hero:GetName()
      end

      -- Add each player's hero to the appropriate team hero list
      if team == DOTA_TEAM_GOODGUYS then
        table.insert(round.heroes_radiant, hero_name)
        table.insert(round.players_radiant, steam_id)
      elseif team == DOTA_TEAM_BADGUYS then
        table.insert(round.heroes_dire, hero_name)
        table.insert(round.players_dire, steam_id)
      end

      if not player_stats[steam_id] then
        player_stats[steam_id] = {
          wins = 0,
          losses = 0,
        }
      end

      -- Track wins/losses for each player
      if team == round.winner then
        player_stats[steam_id].wins = player_stats[steam_id].wins + 1
      else
        player_stats[steam_id].losses = player_stats[steam_id].losses + 1
      end
    end
  end

  table.insert(game_stats.rounds, round)
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


-- Returns the 64-bit Steam ID of each player
function GetPlayerSteamIDs()
  local ids = {}

  for i, player_id in pairs(GetPlayerIDs()) do
    local team = PlayerResource:GetTeam(player_id)

    if IsActualPlayer(player_id) then
      table.insert(ids, tostring(PlayerResource:GetSteamID(player_id)))
    end
  end

  return ids
end


-- Returns whether the player is not a spectator or dummy hero
function IsActualPlayer(player_id)
  local team = PlayerResource:GetTeam(player_id)
  return (team == DOTA_TEAM_GOODGUYS) or (team == DOTA_TEAM_BADGUYS)
end