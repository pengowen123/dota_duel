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

	-- To prevent reaching the item purchased limit
	ClearInventories()

	hero_load_state = {}
	for i, playerID in pairs(GetPlayerIDs()) do
		if hero_select_data[playerID] then
			hero_load_state[playerID] = false
		else
			hero_load_state[playerID] = true
		end
	end

	local no_new_heroes = true

	for i, playerID in pairs(GetPlayerIDs()) do
		local hero_name = hero_select_data[playerID]

		if hero_name then
			no_new_heroes = false

			SetGameState(GAME_STATE_HERO_LOAD)

			PrecacheUnitByNameAsync(hero_name, function()
				PlayerResource:ReplaceHeroWith(playerID, hero_name, 99999, 99999)

				TryOnGameInProgress(playerID)
			end)
		else
			-- Add TP scrolls if the player wasn't given a new hero
			local hero = PlayerResource:GetSelectedHeroEntity(playerID)
			local tp_scroll = CreateItem("item_tpscroll", hero, hero)
			tp_scroll:SetCurrentCharges(3)
			hero:AddItem(tp_scroll)
		end
	end

	-- If no new heroes were selected, start the game immediately
	if no_new_heroes then
		GameMode:OnGameInProgress()
	else
	  Notifications:ClearBottomFromAll()
	  Notifications:BottomToAll({
	    text = "#duel_loading_heroes",
	    duration = 100,
	  })
	end
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

	-- Reset the bot if it exists
	if global_bot_controller then
		global_bot_controller:Reset()
	end
end