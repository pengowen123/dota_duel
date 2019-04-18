-- Controls the rematch system to let players play against each other again

require('utils')
require('rematch_timer')

-- Constants

-- Stores whether each player has voted to rematch
vote_rematch_data = {}


-- A listener for when a player votes to rematch
function OnVoteRematch(event_source_index, args)
	local id = args["id"]

	vote_rematch_data[id] = true

	local data = {}
	data.id = id

	CustomGameEventManager:Send_ServerToAllClients("player_vote_rematch_lua", data)

	if AllVotedRematch() then
		rematch_timer = 0
		SendRematchTimerUpdateEvent()
		-- Reset ready-up data
		InitVoteRematchData()

		-- Restart the game after after a delay (to make the transition less sudden)
		local rematch_delay = 3
		Timers:CreateTimer(rematch_delay, RestartGame)

    Notifications:ClearBottomFromAll()
    Notifications:BottomToAll({
      text = "#duel_restarting",
      duration = 3,
      vars = {
        reason = text,
        team = team,
      }
    })
	end
end


-- Initializes the ready up data
function InitVoteRematchData()
	vote_rematch_data = {}

	for i, id in pairs(GetPlayerIDs()) do
		vote_rematch_data[id] = false
	end
end


-- Returns whether all players have voted to rematch
function AllVotedRematch()
	for i, vote in pairs(vote_rematch_data) do
		if not vote then
			return false
		end
	end

	return true
end


-- Restarts the game
function RestartGame()
	-- GameRules:ResetToHeroSelection()
	SendToServerConsole("dota_launch_custom_game duel1v1_updated duel1v1")
end