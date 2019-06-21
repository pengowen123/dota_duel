-- Controls the ready-up system to let players start rounds early

require('utils')

-- Constants

-- Stores whether each player has readied up
ready_up_data = {}


-- A listener for when a player readies up
function OnReadyUp(event_source_index, args)
	local id = args["id"]

	ready_up_data[id] = true

	local data = {}
	data.id = id

	CustomGameEventManager:Send_ServerToAllClients("player_ready_lua", data)

	if AllReady() then
		StartRoundEarly()
		SendTimerUpdateEvent()
		-- Reset ready-up data
		InitReadyUpData()
	end
end


-- Initializes the ready up data
function InitReadyUpData()
	ready_up_data = {}

	for i, id in pairs(GetPlayerIDs()) do
		ready_up_data[id] = false
	end
end


-- Returns whether all players have readied up
function AllReady()
	for i, ready in pairs(ready_up_data) do
		if not ready then
			return false
		end
	end

	return true
end


-- Starts the round after 3 seconds (to make the transition to the round less sudden)
function StartRoundEarly()
	if round_start_timer > 3 then
		SetRoundStartTimer(3)
	end
end
