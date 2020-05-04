-- The logic governing the surrender mechanism

-- A listener for the forfeit button
function OnSurrender(event_source_index, args)
	local player_id = args["player_id"]

	local team = PlayerResource:GetTeam(player_id)
	if (team == DOTA_TEAM_GOODGUYS) or (team == DOTA_TEAM_BADGUYS) then
		-- This makes the entire team of the player lose
		local team = PlayerResource:GetTeam(player_id)
		local team_winner = GetOppositeTeam(team)

		EndGameDelayed(team_winner)

		text = "#duel_player_lose"
		losing_team_name = GetLocalizationTeamName(team)
		winning_team_name = GetLocalizationTeamName(team_winner)

		Notifications:ClearBottomFromAll()
		Notifications:BottomToAll({
			text = text,
			duration = 10,
			vars = {
				reason = "#duel_surrender_notification",
				team = winning_team_name,
				losing_team = losing_team_name,
			},
		})
	end
end
