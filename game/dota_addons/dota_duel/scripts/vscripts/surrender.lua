-- The logic governing the surrender mechanism

-- A listener for the forfeit button
function OnSurrender(event_source_index, args)
  if IsMatchEnded() or (game_state == GAME_STATE_REMATCH) then
    return
  end

  local player_id = args["player_id"]

  local team = PlayerResource:GetTeam(player_id)
  if (team == DOTA_TEAM_GOODGUYS) or (team == DOTA_TEAM_BADGUYS) then
    -- This makes the entire team of the player lose
    local team = PlayerResource:GetTeam(player_id)
    local team_winner = GetOppositeTeam(team)

    local losing_team_name = GetLocalizationTeamName(team)
    local winning_team_name = GetLocalizationTeamName(team_winner)
    local vars = {
      reason = "#duel_surrender_notification",
      team = winning_team_name,
      losing_team = losing_team_name,
    }
    EndGameDelayed(team_winner, VICTORY_REASON_SURRENDER, "#duel_player_lose", vars)
  end
end
