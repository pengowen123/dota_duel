-- A custom timer for ending the game


-- Constants

rematch_timer = 0
game_result = nil


-- Initializes the custom timer
function InitRematchTimer()
	Timers:RemoveTimer("rematch_timer")

	-- Count down the timer once per second, and send a timer update event (used in JS)
	local tick = function()
		CountDownRematchTimer()
		SendRematchTimerUpdateEvent()
		return 1.0
	end

	local args = {
		endTime = 1.0,
		callback = tick
	}

	Timers:CreateTimer("rematch_timer", args)
end


-- Ends the game after a delay and shows the rematch UI
-- `winner` should be either DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS
function EndGameDelayed(winner)
	if IsMatchEnded() or (game_state == GAME_STATE_REMATCH) then
		return
	end

	-- This is called again here so the countdown only starts after one second has passed
	-- Otherwise the countdown could happen before the first second passes and the timer becomes inaccurate
	InitRematchTimer()
	rematch_timer = 10
	SendRematchTimerUpdateEvent()

	game_result = winner
	SetGameState(GAME_STATE_REMATCH)

	CustomGameEventManager:Send_ServerToAllClients("end_game", nil)

	-- Make bots always vote to rematch
	for i, id in pairs(GetPlayerIDs()) do
		if IsBot(id) then
		  ForceVoteRematch(id)
		end
	end

	if global_bot_controller then
		local say = nil
		if kills.radiant == 0 and kills.dire >= 4 then
			say = function()
				global_bot_controller:SayAllChat("#duel_bot_gg_ez")
			end
		else
			say = function()
				global_bot_controller:SayAllChat("#duel_bot_gg")
			end
		end
		Timers:CreateTimer(2.0, say)
	end
end


-- Counts down the timer by one second if all players are connected
function CountDownRematchTimer()
	if all_players_connected and (rematch_timer > 0) then
		-- Count down one second
		rematch_timer = rematch_timer - 1

		-- When the timer reaches zero, end the game
		if rematch_timer <= 0 then
			EndGame()
		end
	end
end


-- Ends the game, awarding victory to the team stored in `game_result`
function EndGame()
	CustomGameEventManager:Send_ServerToAllClients("end_game_no_rematch", nil)
	SetGameState(GAME_STATE_END)
	GameRules:SetGameWinner(game_result)
end


-- Tell JS to update the number on the vote rematch UI
-- to show how many seconds are left before the game ends
function SendRematchTimerUpdateEvent()
	local data = {}
	data.timer = rematch_timer

	CustomGameEventManager:Send_ServerToAllClients("rematch_timer_update", data)
end
