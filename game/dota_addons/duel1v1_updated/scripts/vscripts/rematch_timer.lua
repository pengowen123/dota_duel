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


-- Ends the game after the provided delay (in seconds)
-- `winner` should be 0 for radiant and 1 for dire
function EndGameDelayed(delay, winner)
	-- This is called again here so the countdown only starts after one second has passed
	-- Otherwise the countdown could happen before the first second passes and the timer becomes inaccurate
	InitRematchTimer()
	SendRematchTimerUpdateEvent()

	rematch_timer = delay
	
  if winner == 0 then
    game_result = DOTA_TEAM_GOODGUYS
  end

  if winner == 1 then
    game_result = DOTA_TEAM_BADGUYS
  end
end


-- Counts down the timer by one second
function CountDownRematchTimer()
	if rematch_timer > 0 then
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
	GameRules:SetGameWinner(game_result)
end


-- Tell JS to update the number on the vote rematch UI
-- to show how many seconds are left before the game ends
function SendRematchTimerUpdateEvent()
	local data = {}
	data.timer = rematch_timer

	CustomGameEventManager:Send_ServerToAllClients("rematch_timer_update", data)
end