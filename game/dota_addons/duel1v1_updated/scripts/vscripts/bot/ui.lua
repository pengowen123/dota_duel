-- A listener for when a player adds a bot
function OnAddBot(event_source_index, args)
  EnableAddBotButton(false)

  if not CanAddBot() then
    return
  end

  -- Create the bot and make a dummy hero for it (will be replaced)
  Tutorial:AddBot("npc_dota_hero_abaddon", "", "", false)

  local bot_hero_name = MakeBotHeroChoice()

  local on_real_hero_loaded = function()
    local bot_id = nil
    local player_id = nil

    for i, id in pairs(GetPlayerIDs()) do
      if IsBot(id) then
        bot_id = id
      else
        player_id = id
      end
    end

    ForceReadyUp(bot_id)
    ForceVoteRematch(bot_id)

    -- This may not be necessary, but it doesn't hurt
    PlayerResource:SetUnitShareMaskForPlayer(bot_id, player_id, 1, false)
    PlayerResource:SetUnitShareMaskForPlayer(bot_id, player_id, 2, false)
    PlayerResource:SetUnitShareMaskForPlayer(bot_id, player_id, 4, false)

    LevelUpPlayers()

    local settings = {}

    global_bot_controller = BotController:New(bot_id, player_id, settings)
  end

  -- Waits for the dummy hero to finish loading, then selects the real hero for the bot
  local check_bot_hero = function()
    for i, id in pairs(GetPlayerIDs()) do
      if IsBot(id) then
        local bot_hero = PlayerResource:GetSelectedHeroEntity(id)

        if bot_hero then
          -- If the dummy bot hero has loaded, select the real one for the bot
          SelectNewBotHero(bot_hero_name, on_real_hero_loaded)
        else
          -- Otherwise, check again in 0.5 seconds
          return 0.5
        end
      end
    end
  end

  Timers:CreateTimer(0.1, check_bot_hero)
end