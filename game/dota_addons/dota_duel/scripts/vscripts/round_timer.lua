-- A custom timer for starting rounds, created to allow more flexible adjustment of the
-- timer while it is running

require('utils')


-- Constants

-- Must be at least 4 for:
-- Spark Wraith lingering vision to disappear
-- Glimpse to not send players to the center of the map
ROUND_START_DELAY = 4

round_start_timer = 0


-- Initializes the custom timer
function InitRoundStartTimer()
	Timers:RemoveTimer("round_timer")

	-- Count down the timer once per second, and send a timer update event (used in JS)
	local tick = function()
		CountDownTimer()
		SendTimerUpdateEvent()
		return 1.0
	end

	local args = {
		endTime = 1.0,
		callback = tick
	}

	Timers:CreateTimer("round_timer", args)
end


-- Sets the round start timer to the provided value (in seconds)
function SetRoundStartTimer(seconds)
	-- This is done at least 4 seconds before the round starts so that spark wraith vision has enough
	-- time to disappear
	if seconds <= ROUND_START_DELAY and game_state == GAME_STATE_BUY then
		PrepareNextRound()
	end

	-- This is done at least 1 second before the round starts so that MK clone vision has enough time
	-- to disappear
	if seconds <= 1 then
		RemoveOldHeroes()
	end

	-- This is called again here so the countdown only starts after one second has passed
	-- Otherwise the countdown could happen before the first second passes and the timer becomes inaccurate
	InitRoundStartTimer()
	round_start_timer = seconds
	SendTimerUpdateEvent()
end


-- Counts down the timer by one second
function CountDownTimer()	
	if round_start_timer > 0 and game_state == GAME_STATE_BUY then
		-- Count down one second
		round_start_timer = round_start_timer - 1

		-- This is done at least 4 seconds before the round starts so that spark wraith vision has enough
		-- time to disappear
		if round_start_timer == 15 or round_start_timer == ROUND_START_DELAY then
			PrepareNextRound()
		end

		-- This is done at least 1 second before the round starts so that MK clone vision has enough time
		-- to disappear
		if round_start_timer <= 1 then
			RemoveOldHeroes()
		end

		-- Disable add bot button so it can't be added during or right before a round
		if round_start_timer <= 10 then
			EnableAddBotButton(false)
		end

		-- When the timer reaches zero, start the round
		if round_start_timer <= 0 then
			StartRound()
		end
	end
end


-- Tell JS to update the number on the ready-up UI to show how many seconds are left before the
-- round starts
function SendTimerUpdateEvent()
	local data = {}
	data.timer = round_start_timer

	CustomGameEventManager:Send_ServerToAllClients("timer_update", data)
end