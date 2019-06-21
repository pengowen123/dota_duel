-- The logic governing the surrender mechanism

-- A listener for the forfeit button
function OnSurrender(event_source_index, args)
	local player_id = args["player_id"]
	-- This makes the entire team of the player lose
	local team = PlayerResource:GetTeam(player_id)
	local team_winner = 0

	if team == 2 then
		team_winner = 1
	end

	EndGameDelayed(10, team_winner)
	game_ended = true
	CustomGameEventManager:Send_ServerToAllClients("end_game", nil)
end
