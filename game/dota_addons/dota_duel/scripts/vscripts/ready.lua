-- Controls the ready-up system to let players start rounds early

require('utils')

-- Constants

-- Stores whether each player has readied up
ready_up_data = {}


-- A listener for when a player readies up
function OnReadyUp(event_source_index, args)
	-- Don't allow readying up except during the buy phase
	if game_state ~= GAME_STATE_BUY then
		return
	end

	local id = args["id"]

	local team = PlayerResource:GetTeam(id)
	if (team == DOTA_TEAM_GOODGUYS) or (team == DOTA_TEAM_BADGUYS) then
		ready_up_data[id] = true

		local data = {}
		data.id = id

		CustomGameEventManager:Send_ServerToAllClients("player_ready_lua", data)

		if AllReady() then
			EnableAddBotButton(false)
			StartRoundEarly()
			SendTimerUpdateEvent()
			-- Reset ready-up data
			InitReadyUpData()
		end
	end
end


-- Initializes the ready up data
function InitReadyUpData()
	ready_up_data = {}

	for i, id in pairs(GetPlayerIDs()) do
		ready_up_data[id] = false

		-- Force bots to ready up (only necessary for testing; the custom bots do this themselves)
		if IsBot(id) then
			ForceReadyUp(id)
		end
	end
end


-- Readies up for the player with the provided ID
function ForceReadyUp(id)
	ready_up_data[id] = true

	local data = {}
	data.id = id

	CustomGameEventManager:Send_ServerToAllClients("player_ready_lua", data)
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


-- Starts the round after ROUND_START_DELAY seconds (to make the transition to the round less
-- sudden)
function StartRoundEarly()
	if round_start_timer > ROUND_START_DELAY then
		SetRoundStartTimer(ROUND_START_DELAY)
	end
end
