-- Sets up the UI state
-- Called whenever a player connects and their UI first loads
-- All UI components are hidden by default and are re-enabled later by this
function SetupUI(event_source_index, args)
  local player_id = args["id"]
  local player = PlayerResource:GetPlayer(player_id)

  if game_state == GAME_STATE_BUY then
    CustomGameEventManager:Send_ServerToPlayer(player, "start_game", nil)
  elseif game_state == GAME_STATE_FIGHT then
    -- Hide the ready-up and surrender UIs
    CustomGameEventManager:Send_ServerToPlayer(player, "start_round", nil)
  elseif game_state == GAME_STATE_REMATCH then
    -- Hide the ready-up and surrender UIs and show the rematch UI
    CustomGameEventManager:Send_ServerToPlayer(player, "end_game", nil)
  elseif game_state == GAME_STATE_HERO_SELECT then
    -- Hide the ready-up and surrender UIs and show the hero select UI
    CustomGameEventManager:Send_ServerToPlayer(player, "all_voted_rematch", nil)
  elseif game_state == GAME_STATE_HERO_LOAD then
    -- Hide the surrender UI
    local data = {}
    data.enable_surrender = false

    CustomGameEventManager:Send_ServerToPlayer(player, "end_round", data)
  elseif game_state == GAME_STATE_END then
    -- UI is automatically all hidden in this state
  end

  CustomGameEventManager:Send_ServerToPlayer(player, "score_update", kills)

  local setup_votes = function()
    for id, ready in pairs(ready_up_data) do
      if ready then
        local data = {}
        data.id = id

        CustomGameEventManager:Send_ServerToPlayer(player, "player_ready_lua", data)
      end
    end

    for id, ready in pairs(vote_rematch_data) do
      if ready then
        local data = {}
        data.id = id

        CustomGameEventManager:Send_ServerToPlayer(player, "player_vote_rematch_lua", data)
      end
    end
  end

  -- Delayed so the previously sent events arrive first and don't overwrite the changes
  Timers:CreateTimer(1.0, setup_votes)
end