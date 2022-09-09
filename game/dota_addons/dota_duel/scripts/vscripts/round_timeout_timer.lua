-- A custom timer for enforcing a time limit on each round


-- Constants
round_timeout_timer = 0


-- Initializes the custom timer
function InitRoundTimeoutTimer()
  -- 3 minutes is just long enough to cast ultimate with long cooldowns (and refresher with some
  -- CDR if not backpacked) twice
  round_timeout_timer = 180

  Timers:RemoveTimer("round_timeout_timer")

  -- Count down the timer once per second, and send a timer update event (used in JS)
  local tick = function()
    CountDownRoundTimeoutTimer()
    return 1.0
  end

  local args = {
    endTime = 1.0,
    callback = tick
  }

  Timers:CreateTimer("round_timeout_timer", args)
end


-- Counts down the timer by one second
function CountDownRoundTimeoutTimer()
  -- Stop the countdown if the round is already ending (i.e., a team lost the round)
  if round_timeout_timer > 0 and not is_round_ending and game_state == GAME_STATE_FIGHT then
    -- Count down one second
    round_timeout_timer = round_timeout_timer - 1
    SendRoundTimeoutTimerUpdateEvent()

    -- When the timer reaches zero, end the round
    if round_timeout_timer <= 0 then
      EndRoundOnTimeout()
    end
  end
end


-- Ends the round by timeout, awarding a point to both teams
function EndRoundOnTimeout()
  round_drew = true

  -- Doesn't actually catch reincarnating heroes, but their respawn time is set to the round end
  -- delay anyways so it still looks smooth
  for i, hero in pairs(GetPlayerEntities()) do
    KillNPC(hero)
  end

  AwardRadiantKill()
  AwardDireKill()

  CheckTeamScores()

  EndRoundDelayed()
end


-- Tell JS to update the number on the round timeout UI to show how many seconds are left before the
-- round ends on timeout
function SendRoundTimeoutTimerUpdateEvent()
  local data = {}
  data.timer = round_timeout_timer

  CustomGameEventManager:Send_ServerToAllClients("round_timeout_timer_update", data)
end
