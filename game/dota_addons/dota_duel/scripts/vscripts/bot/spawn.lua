-- Spawns a custom bot to fill each empty slot on both teams
function FillEmptySlotsWithBots()
  EnableAddBotButton(false)

  -- Load map data for use by the bots
  LoadMapData()

  -- Get the number of bots to spawn on each team
  local empty_slots_radiant = GameRules:GetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS)
    - PlayerResource:GetPlayerCountForTeam(DOTA_TEAM_GOODGUYS)

  local empty_slots_dire = GameRules:GetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS)
    - PlayerResource:GetPlayerCountForTeam(DOTA_TEAM_BADGUYS)

  -- Track when all bots have loaded so they can be notified
  local num_bots = empty_slots_radiant + empty_slots_dire
  local num_loaded = 0
  local on_load = function()
    num_loaded = num_loaded + 1

    if num_loaded == num_bots then
      -- Notify bots that all of them have loaded
      BotOnAllBotsLoaded()
    end
  end

  -- Spawn the bots
  for i=1,empty_slots_radiant do
    BotController:Spawn(DOTA_TEAM_GOODGUYS, on_load)
  end

  for i=1,empty_slots_dire do
    BotController:Spawn(DOTA_TEAM_BADGUYS, on_load)
  end

  -- Get the bots' stats
  UpdatePlayerStatsUI()

  -- Initialize the bots' think timer
  local think = function()
    BotOnThink()
    return THINK_INTERVAL
  end

  local args = {
    endTime = 1.0,
    callback = think,
  }

  -- Initialize the illusion data update timer
  InitializeIllusionDataUpdater()

  Timers:RemoveTimer("bot_think")
  Timers:CreateTimer("bot_think", args)
end
