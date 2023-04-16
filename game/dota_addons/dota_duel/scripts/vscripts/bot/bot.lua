-- Bot spawning and control logic

require('bot/constants')
require('bot/spawn')
require('bot/name')
require('bot/hero_pick')
require('bot/say')
require('bot/events')
require('bot/observations/observations')
require('bot/map_data')
require('bot/illusions')
require('bot/think/think')
require('bot/utils')


-- Globals

-- A list of all `BotController` instances
global_bot_controllers = {}

-- Mode enum for the thinking state of a bot
-- The bot is buying items during the buy phase
MODE_BUY = 1
-- The bot is performing any start of round actions, such as backpack swapping demonicon
MODE_ROUND_START = 2
-- The bot is searching the map for the opponent
MODE_HUNT = 3
-- The bot is actively fighting the opponent
MODE_FIGHT = 4
-- The bot is attempting to run away from the opponent
MODE_RUN = 5


-- A controller for an individual bot
BotController = {}
BotController.__index = BotController


-- Spawns a bot on the provided team and returns its player ID
-- Calls `callback` with the bot's hero when the bot is fully loaded
function BotController:Spawn(team, callback)
  -- Create the bot and its hero entity (to be replaced later)
  local hero_name = PickBotHero(team)

  -- Handle the hero pool being empty by not spawning bots
  if not hero_name then
    return
  end

  local name = PickBotName()
  local hero = GameRules:AddBotPlayerWithEntityScript(
    hero_name,
    name,
    team,
    -- Not sure what these two arguments do
    nil,
    true
  )
  local bot_player_id = hero:GetPlayerOwnerID()

  -- Teleport the hero back to the fountain (necessary because they spawn in the center of the map)
  ResetPosition(hero)

  Timers:CreateTimer(0.25, function()
    -- Replace the bot's hero to fix backpack swapping causing a cooldown despite the bot being in
    -- base, as well as the bot not being manually controllable in tools mode
    hero = ReplaceHero(bot_player_id, hero:GetName())

    -- Create a controller for the bot
    local controller = BotController:New(bot_player_id)

    -- Add it to the global list of bots
    table.insert(global_bot_controllers, controller)

    -- Ready up for the bot
    ForceReadyUp(bot_player_id)

    -- Make the bot say GLHF
    controller:SayAllChat("#duel_bot_glhf")

    -- Notify the caller that the bot is loaded
    if callback then
      callback(hero)
    end
  end)

  return bot_player_id
end


-- Creates a new bot controller for the provided player ID
function BotController:New(bot_player_id)
  local controller = {}
  setmetatable(controller, BotController)

  controller.id = bot_player_id
  controller.team = PlayerResource:GetTeam(bot_player_id)
  -- The current mode of the bot
  controller.mode = MODE_BUY
  -- The bot's hero handle
  controller.hero = PlayerResource:GetSelectedHeroEntity(bot_player_id)
  -- The thinker object for the bot that implements the bot's hero-specific logic
  controller.think = BotGetThinker(bot_player_id, controller.hero:GetName())
  -- The observation and prediction data to drive the bot's adaptation (to be set later after all
  -- heroes have been picked)
  controller.observations = nil

  return controller
end


-- Resets the bot controller's state
function BotController:Reset()
  local new = BotController:New(self.id)
  self.mode = new.mode
  self.hero = new.hero
  self.think = new.think
  -- Load hero data for the enemy again, as they may have picked different heroes
  self.observations = Observations:WithHeroData(GetEnemyHeroNames(self.team))
end


-- Makes the bot say `message` in all chat after it is localized (in player 0's language)
function BotController:SayAllChat(message)
  -- Instead of saying the message directly, send it to the Panorama UI to get localized first
  -- The localized message is then said in bot/say.lua
  -- Since there may be multiple players, player 0's language is used (no perfect solution is
  -- feasible here unfortunately)
  local player = PlayerResource:GetPlayer(0)

  if player then
    local data = {}
    data.message = message
    data.player_id = self.id
    CustomGameEventManager:Send_ServerToPlayer(player, "bot_message_raw", data)
  end
end


-- Called when the bot gets a new hero entity assigned to it (as each player's hero entity is
-- replaced frequently for various reasons)
function BotController:OnNewHeroEntity(hero)
  -- Update the hero handle
  self.hero = hero
  -- Perform shop actions for the bot (the bot gets a new hero after each round and at the start of
  -- the match, so this works)
  -- This must be done after a delay to allow time for `ResetTalents` to finish setting up the
  -- bot's inventory
  Timers:CreateTimer(1.0, function()
    -- Wait until observation data is available (after all heroes have loaded)
    if self.observations == nil then
      return 0.5
    end

    -- Get predictions for the next round
    local predictions = self.observations:GetPredictions()

    -- Clear the bot's inventory to provide a blank slate to `ThinkShop`
    ClearInventory(self.hero)

    -- Purchase scepter and shard for the bot if it wants them
    if self.think:ShouldBuyScepter() then
      ConsumeAghanimsScepter(hero)
    end

    if self.think:ShouldBuyShard() then
      ConsumeAghanimsShard(hero)
    end

    -- Purchase other items after a delay to allow time for scepter and shard to be consumed
    Timers:CreateTimer(0.25, function()
      self.think:ThinkShop(self.hero, predictions)
    end)
  end)
end


-- Called after all bots have been created and picked their heroes
function BotController:OnAllBotsLoaded()
  -- Initialize the observations object with the enemy heroes' data
  -- Must be done after all bots have loaded so that all enemy heroes are known
  print("bot id ", self.id, " loaded")
  self.observations = Observations:WithHeroData(GetEnemyHeroNames(self.team))
end


-- Performs round start actions
function BotController:OnRoundStart()
  -- Update the state (the next transition after this occurs with the first think tick in
  -- `UpdateMode`)
  self.mode = MODE_ROUND_START
  -- Perform hero-specific actions
  self.think:ThinkRoundStart(self.hero)
end


-- Performs round end actions
function BotController:OnRoundEnd()
  -- Update the state and predictions
  self.mode = MODE_BUY
  self.observations:FinalizeCurrentRoundObservations()
  self.observations:UpdatePredictions()
end


-- Called when the game fully ends
function BotController:OnGameEnd()
  -- Make the bot say gg
  self:SayAllChat("#duel_bot_gg")
end


-- Called when the bot's hero entity takes damage
-- `damage` is the damage amount, and `source_ability` is the ability that caused the damage, if one
-- exists
function BotController:OnHurt(damage, source_ability)
  -- Update damage counters (not 100% accurate because damage type is not always provided/accurate,
  -- but it should be good enough in most cases)

  -- Only increment damage counters during the round
  -- All living heroes are immediately killed when the round timer runs out, so the damage
  -- instance must be ignored in that case as well
  if self.mode == MODE_BUY or round_drew then
    return
  end

  -- Get the hero's resistance values for each damage type
  local phys_multiplier = GetPhysicalDamageMultiplierForNPC(self.hero)
  local magic_multiplier = GetMagicDamageMultiplierForNPC(self.hero)

  if source_ability then
    -- If there is a source ability, try to get its damage type
    local damage_type = source_ability:GetAbilityDamageType()

    if damage_type == DAMAGE_TYPE_PHYSICAL then
      self.observations:AddPhysicalDamage(damage, phys_multiplier)
    elseif (damage_type == DAMAGE_TYPE_MAGICAL) or (damage_type == DAMAGE_TYPE_NONE) then
      -- Assume sources with no damage type to be magic damage
      -- This happens with items, which are mostly magic damage (there is no way to tell otherwise
      -- anyways)
      self.observations:AddMagicDamage(damage, magic_multiplier)
    elseif damage_type == DAMAGE_TYPE_PURE then
      self.observations:AddPureDamage(damage)
    end
  else
    -- Otherwise, the source is probably an auto-attack, which means it's probably at least mostly
    -- physical damage
    self.observations:AddPhysicalDamage(damage, phys_multiplier)
  end
end


-- Changes to the mode with the highest desire value according to the bot's thinker, or does nothing
-- if the bot is in `MODE_BUY`
function BotController:UpdateMode(observation_state)
  if self.mode == MODE_BUY then
    return
  end

  -- Get desire values
  local desires = {
    [MODE_HUNT] = self.think:GetDesireHunt(self.hero, self.mode, observation_state),
    [MODE_FIGHT] = self.think:GetDesireFight(self.hero, self.mode, observation_state),
    [MODE_RUN] = self.think:GetDesireRun(self.hero, self.mode, observation_state),
  }

  -- print("fight: ", desires[MODE_FIGHT], ", run: ", desires[MODE_RUN])

  -- Find the most desired mode
  local max_mode = nil
  local max_desire = nil

  for mode, desire in pairs(desires) do
    if max_desire == nil or desire > max_desire then
      max_mode = mode
      max_desire = desire
    end
  end

  self.mode = max_mode
end

-- Called every `THINK_INTERVAL` seconds
function BotController:Think()
  -- Call the mode's respective think function if the round is ongoing and has not ended in a draw
  -- (the latter check is necessary to prevent the bot from observing its health loss when it is
  -- forcibly killed)
  if self.mode ~= MODE_BUY and not round_drew then
    -- Make observations about the enemy for later use
    self.observations:GatherObservations(self.hero, THINK_INTERVAL)
    local observation_state = self.observations:GetCurrentState()

    -- Switch to the thinker's desired mode
    self:UpdateMode(observation_state)

    -- Think for general actions
    self.think:Think(self.hero, self.mode, observation_state)

    -- Think for the current mode
    if self.mode == MODE_HUNT then
      self.think:ThinkHunt(self.hero, observation_state)
    elseif self.mode == MODE_FIGHT then
      self.think:ThinkFight(self.hero, observation_state)
    elseif self.mode == MODE_RUN then
      self.think:ThinkRun(self.hero, observation_state)
    end
  end
end
