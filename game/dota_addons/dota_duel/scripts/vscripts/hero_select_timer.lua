-- A custom timer for starting the game after players select new heroes


-- Constants

hero_select_timer = 0
-- Stores which hero each player has selected
hero_select_data = {}
-- Stores whether the new hero for each player has loaded
hero_load_state = {}


-- Initializes the custom timer
function InitHeroSelectTimer()
	Timers:RemoveTimer("hero_select_timer")

	-- Count down the timer once per second, and send a timer update event (used in JS)
	local tick = function()
		CountDownHeroSelectTimer()
		SendHeroSelectTimerUpdateEvent()
		return 1.0
	end

	local args = {
		endTime = 1.0,
		callback = tick
	}

	Timers:CreateTimer("hero_select_timer", args)
end


-- Sets the hero select timer to the provided value (in seconds)
function SetHeroSelectTimer(seconds)
	hero_select_timer = seconds

	-- This is called again here so the countdown only starts after one second has passed
	-- Otherwise the countdown could happen before the first second passes and the timer becomes inaccurate
	InitHeroSelectTimer()
	SendHeroSelectTimerUpdateEvent()
end


-- Counts down the timer by one second
function CountDownHeroSelectTimer()
	if all_players_connected and (hero_select_timer > 0) then
		-- Count down one second
		hero_select_timer = hero_select_timer - 1

		-- When the timer reaches zero, start the game
		if hero_select_timer <= 0 then
			RestartGame()
		end
	end
end


-- Tell JS to update the number on the hero select UI
-- to show how many seconds are left before the game starts
function SendHeroSelectTimerUpdateEvent()
	local data = {}
	data.timer = hero_select_timer

	CustomGameEventManager:Send_ServerToAllClients("select_timer_update", data)
end


-- Restarts the game
function RestartGame()
	-- Hide the rematch UI and show the ready-up UI
	-- The former is done later in `OnGameInProgress`, but if it is immediately after replacing the
	-- heroes, it does not work
	-- Also set a flag to not show the surrender UI so that players can't surrender while heroes are
	-- loading
	CustomGameEventManager:Send_ServerToAllClients("start_game", nil)

	local data = {}
	data.enable_surrender = false

	CustomGameEventManager:Send_ServerToAllClients("end_round", data)

	hero_load_state = {}
	for i, playerID in pairs(GetPlayerIDs()) do
		if hero_select_data[playerID] then
			hero_load_state[playerID] = false
		else
			-- TODO: this seems redundant, as tryongameinprogress always sets this
			--       test that this is the case and remove it
			hero_load_state[playerID] = true
		end
	end

	SetGameState(GAME_STATE_HERO_LOAD)

	for i, playerID in pairs(GetPlayerIDs()) do
		local hero_name = hero_select_data[playerID]

		if hero_name == false then
			local hero = PlayerResource:GetSelectedHeroEntity(playerID)

			if hero then
				hero_name = hero:GetName()
			else
				-- Make the player lose again if they don't select a hero
				MakePlayerLose(playerID, "#duel_no_selected_hero", true, VICTORY_REASON_NO_HERO)
				-- Note that `OnGameInProgress` is never called in this case, which means this match's
				-- stats won't be tracked, but a player did not pick a hero, so it doesn't really matter
				return
			end
		end

		SetPreviousRoundEndTime()

		PrecacheUnitByNameAsync(hero_name, function()
			-- The hero must not be replaced on the same frame as the precache finishing to avoid the new
			-- one randomly being instantly deleted (which appears to be a dota bug)
			Timers:CreateTimer(0.1, function()
				ReplaceHero(playerID, hero_name)
				TryOnGameInProgress(playerID)
			end)
		end)
	end

	Notifications:ClearBottomFromAll()
	Notifications:BottomToAll({
		text = "#duel_loading_heroes",
		duration = 100,
	})
end


-- Runs `GameMode:OnGameInProgress` if all new heroes have loaded
function TryOnGameInProgress(playerID)
	hero_load_state[playerID] = true

	for i, state in pairs(hero_load_state) do
		if not state then
			return
		end
	end

	GameMode:OnGameInProgress()
end