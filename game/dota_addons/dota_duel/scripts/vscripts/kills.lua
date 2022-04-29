-- Handling of the custom scoreboard system


-- Constants
MAX_KILLS = 5


-- Kills for the current match
kills = {}
-- Total kills of all matches
total_kills = {}


-- Initializes the custom scoreboard
function InitKills()
	total_kills.radiant = 0
	total_kills.dire = 0

	kills.radiant = 0
	kills.dire = 0

	CustomGameEventManager:Send_ServerToAllClients("score_update", kills)
end


-- Reset the scoreboard so all players have 0 kills
function ResetKills()
	kills.radiant = 0
	kills.dire = 0

	CustomGameEventManager:Send_ServerToAllClients("score_update", kills)
end


-- Returns how many kills the radiant team has
function GetRadiantKills()
	return kills.radiant
end


-- Returns how many kills the dire team has
function GetDireKills()
	return kills.dire
end


-- Gives one kill to radiant
function AwardRadiantKill()
	kills.radiant = kills.radiant + 1
	total_kills.radiant = total_kills.radiant + 1

	CustomGameEventManager:Send_ServerToAllClients("score_update", kills)
end


-- Gives on kill to dire
function AwardDireKill()
	kills.dire = kills.dire + 1
	total_kills.dire = total_kills.dire + 1

	CustomGameEventManager:Send_ServerToAllClients("score_update", kills)
end

-- Checks whether one or both teams have won and ends the game if so
function CheckTeamScores()
  -- Is nil if no player has won yet, DOTA_TEAM_* if a team has won, or DOTA_TEAM_NEUTRALS if both
  -- teams reached the max kills
  local winner = nil

  local radiant = GetRadiantKills()
  local dire = GetDireKills()

  if radiant >= MAX_KILLS and dire >= MAX_KILLS then
		winner = DOTA_TEAM_NEUTRALS
  elseif radiant >= MAX_KILLS then
    winner = DOTA_TEAM_GOODGUYS
  elseif dire >= MAX_KILLS then
    winner = DOTA_TEAM_BADGUYS
  end

  if winner then
		if winner == DOTA_TEAM_NEUTRALS then
	    EndGameDelayed(winner, VICTORY_REASON_DRAW, "#duel_draw", nil)
	  else
	    local team = GetLocalizationTeamName(winner)
			local vars = { team = team }
	    EndGameDelayed(winner, VICTORY_REASON_ROUNDS, "#duel_victory", vars)
		end
  end
end