-- Observations made of the opponent during the round and predictions based on those observations
--
-- These provide the bots with adaptability so that they cannot be abused easily

require('bot/observations/hero_data')

Observations = {}
Observations.__index = Observations


-- Heroes with invisibility that can't be ignored
local invisibility_heroes = {
  ["npc_dota_hero_sand_king"] = true,
  ["npc_dota_hero_treant"] = true,
  ["npc_dota_hero_bounty_hunter"] = true,
  ["npc_dota_hero_clinkz"] = true,
  ["npc_dota_hero_mirana"] = true,
  ["npc_dota_hero_nyx_assassin"] = true,
  ["npc_dota_hero_riki"] = true,
  ["npc_dota_hero_templar_assassin"] = true,
  ["npc_dota_hero_weaver"] = true,
  ["npc_dota_hero_invoker"] = true,
  ["npc_dota_hero_visage"] = true,
  ["npc_dota_hero_windrunner"] = true,
}

-- Heroes with a special form of high evasion
-- Evasion is checked dynamically in `GatherObservations`, but special cases must handled here
local special_high_evasion_heroes = {
  -- Magnetic field is a form of high evasion but does not actually grant evasion directly
  ["npc_dota_hero_arc_warden"] = true,
}


-- Returns a new table of value trackers used to make observations
function NewTrackerTable()
  local trackers = {}

  -- The time elapsed since the last time "long interval" observations/trackers were checked/updated
  -- Used to perform certain updates with a constant frequency, regardless of the think interval
  trackers.elapsed = 0
  -- The last known HP value of the bot, updated once per second
  trackers.previous_hp = 0
  -- The number of seconds the bot has spent alive during the current round
  trackers.time_spent_alive = 0
  -- The number of seconds the bot has spent losing health during the current round
  trackers.time_spent_losing_health = 0
  -- The number of seconds the bot has been fully disabled for during the current round
  trackers.time_disabled = 0
  -- The number of seconds the bot has been weakly disabled for during the current round
  trackers.time_weakly_disabled = 0
  -- The number of seconds the longest disable lasted on the bot during the current round
  trackers.longest_disable = 0
  -- The number of seconds the current disable on the bot has lasted
  trackers.current_disable = 0
  -- The total amount of damage taken of each type during the current round
  trackers.damage_taken = {
    ["physical"] = 0,
    ["magic"] = 0,
    ["pure"] = 0,
  }

  return trackers
end


-- Returns a new `Observations` object with default prediction data
function Observations:Default()
  local observations = {}
  setmetatable(observations, Observations)

  -- Trackers for various values that some observations are based on
  -- Reset each round
  observations.trackers = NewTrackerTable()

  -- The observation data itself
  -- Each key is the name of an observation, and each value is a table containing the current
  -- predicted probability of the observation being true next round and a flag to be set if the
  -- observation was true in the current round
  -- All items are included as observations but are set dynamically
  observations.data = {
    -- General stats

    ["high_magic_damage"]        = { 0.5, false },
    ["high_pure_damage"]         = { 0.5, false },
    ["high_burst_damage"]        = { 0.5, false },
    ["invisibility"]             = { 0.5, false },
    ["spell_block"]              = { 0.5, false },
    ["high_evasion"]             = { 0.5, false },
    ["high_status_resistance"]   = { 0.5, false },

    -- Capabilities

    -- The bot was fully disabled for much of the time it spent fighting
    ["high_total_disable"]       = { 0.5, false },
    -- The bot was continuously fully disabled for a long time
    ["high_consecutive_disable"] = { 0.5, false },
    -- The bot was weakly disabled for much of the time it spent fighting
    ["high_weak_disable"]        = { 0.5, false },

    -- High-level strategies

    -- For disruptor cheating with glimpse
    ["disruptor_cheat"]          = { 0.5, false },

    -- Trackers only used for reading their current state
    ["taking_damage"]            = { 0.5, false },
  }

  -- The current state of each observation, specified as a remaining duration for which each is true
  -- `data` stores flags for whether each observation was true at any point during the round, while
  -- this is used to track whether they are currently true
  observations.current_state = {}

  return observations
end


-- Returns a new `Observations` object with pre-populated data based on the enemy hero picks
function Observations:WithHeroData(enemy_hero_names)
  local observations = Observations:Default()
  -- Used to average probabilities in case there are multiple enemy heroes
  local total_probabilities = {}

  for _, hero in pairs(enemy_hero_names) do
    -- Get data for each enemy hero
    local hero_data = HERO_OBSERVATION_DATA[hero]

    if hero_data then
      for k, v in pairs(hero_data) do
        if observations.data[k] ~= nil then
          -- Add the hero data's probability for this observation to the total
          if total_probabilities[k] == nil then
            -- Total probability and the number of heroes' data containing data for the observation
            total_probabilities[k] = { 0.0, 0}
          end

          total_probabilities[k][1] = total_probabilities[k][1] + v
          total_probabilities[k][2] = total_probabilities[k][2] + 1
        else
          print("unknown observation in hero data: ", k)
        end
      end
    end
  end

  -- Compute the average for each observation and insert it into the data
  for k, v in pairs(total_probabilities) do
    observations.data[k][1] = v[1] / v[2]
  end

  return observations
end


-- Resets the currently stored observations (but not the prediction data) to prepare for the next
-- round
-- Should be called between each round
function Observations:ResetObservations()
  -- Reset the observation flags
  for k, v in pairs(self.data) do
    self.data[k][2] = false
  end

  -- Reset the current state of the observations
  self.current_state = {}

  -- Reset the trackers as well
  self.trackers = NewTrackerTable()
end


-- Updates the current state of each observation (but not the observations themselves or prediction
-- data)
-- This resets the state of each observation whose sticky duration has expired
-- Should be called before gathering observations
-- `elapsed` is the time elapsed since this function was last called
function Observations:UpdateCurrentState(elapsed)
  -- Decrement the duration of each observation
  for k, v in pairs(self.current_state) do
    self.current_state[k] = self.current_state[k] - elapsed

    if self.current_state[k] <= 0.0 then
      self.current_state[k] = nil
    end
  end
end


-- Returns the current state of all observations, which stores whether each observation is currently
-- true
function Observations:GetCurrentState()
  return self.current_state
end


-- Returns a list of predictions based on all previous observations
function Observations:GetPredictions()
  local predictions = {}

  for k, v in pairs(self.data) do
    -- Set each observation to true with the associated probability
    if v[1] > RandomFloat(0, 1) then
      predictions[k] = true
    end
  end

  return predictions
end


-- Updates the prediction data based on the currently stored observations and then resets those
-- observations to prepare for the next round
-- Should be called between each round
function Observations:UpdatePredictions()
  for k, v in pairs(self.data) do
    -- Move OBSERVATION_LEARN_RATE percent of the way towards 0 or 1, depending on whether the
    -- observation was true the previous round
    -- This results in a simple prediction system: if an observation was made last round, it is
    -- more likely to be predicted next round, and if an observation was not made last round, then
    -- it is less likely to be predicted next round
    local current_probability = v[1]

    if v[2] then
      self.data[k][1] = current_probability + (1 - current_probability) * OBSERVATION_LEARN_RATE
    else
      self.data[k][1] = current_probability * (1 - OBSERVATION_LEARN_RATE)
    end
  end

  -- Reset observations to prepare for the next round
  self:ResetObservations()
end


-- Sets the observation to true
-- If `sticky_duration` is specified, the observation's current state will continue being true for
-- at least that many seconds
function Observations:SetObservation(name, sticky_duration)
  -- Initialize the observation first if it doesn't exist (needed for item observations)
  if self.data[name] == nil then
    self.data[name] = { 0.5, false }
  end

  -- Set the observation
  self.data[name][2] = true

  -- Also set the current state of the observation
  self.current_state[name] = sticky_duration or 0.0
end


-- Increments the counter for physical damage taken
-- `phys_multiplier` is the multiplier for physical damage taken, used to compute the base damage
-- before mitigatins
function Observations:AddPhysicalDamage(damage, phys_multiplier)
  -- Check the multiplier to avoid dividing by zero
  if phys_multiplier > 0 then
    self.trackers.damage_taken["physical"]
      = self.trackers.damage_taken["physical"] + damage / phys_multiplier
  end
end


-- Increments the counter for magic damage taken
-- `magic_multiplier` is the multiplier for magic damage taken, used to compute the base damage
-- before mitigatins
function Observations:AddMagicDamage(damage, magic_multiplier)
  -- Check the multiplier to avoid dividing by zero
  if magic_multiplier > 0 then
    self.trackers.damage_taken["magic"]
      = self.trackers.damage_taken["magic"] + damage / magic_multiplier
  end
end


-- Increments the counter for pure damage taken
function Observations:AddPureDamage(damage)
  self.trackers.damage_taken["pure"] = self.trackers.damage_taken["pure"] + damage
end


-- Updates the observation flags by looking at all visible units not on `bot_team`
-- `elapsed` is the time elapsed since this function was called last for the bot
function Observations:GatherObservations(bot_hero, elapsed)
  -- Update the current state of the observations
  self:UpdateCurrentState(elapsed)

  -- Update general trackers
  if bot_hero:IsAlive() then
    self.trackers.time_spent_alive = self.trackers.time_spent_alive + elapsed
  end

  -- Update some trackers less frequently to avoid issues with a short think interval
  local long_interval = 1
  self.trackers.elapsed = self.trackers.elapsed + elapsed

  if self.trackers.elapsed >= long_interval then
    self.trackers.elapsed = 0

    self.trackers.previous_hp = bot_hero:GetHealth()
  end

  -- Check the bot's health change over the last second
  local new_hp = bot_hero:GetHealth()
  local hp_change = new_hp - self.trackers.previous_hp

  -- Check if the bot is losing any amount of health
  if hp_change < 0 then
    -- This observation is made sticky to avoid flickering with a short think interval
    self:SetObservation("taking_damage", 1)
  end

  -- Increment the time spent losing health (done separately to respect the sticky observation time)
  if self.current_state["taking_damage"] then
    self.trackers.time_spent_losing_health
      = self.trackers.time_spent_losing_health + elapsed
  end

  -- Check if the bot is losing a high amount of health
  local high_hp_loss_threshold = bot_hero:GetMaxHealth() * HIGH_HP_LOSS_RATIO * long_interval
  if -hp_change > high_hp_loss_threshold then
    self:SetObservation("high_burst_damage", 1)
  end

  if IsFullyDisabled(bot_hero) then
    -- Increment current and total disable time
    self.trackers.time_disabled = self.trackers.time_disabled + elapsed
    self.trackers.current_disable = self.trackers.current_disable + elapsed
  else
    -- Update the longest disable time if necessary and reset the current disable time
    if self.trackers.current_disable > self.trackers.longest_disable then
      self.trackers.longest_disable = self.trackers.current_disable
    end

    self.trackers.current_disable = 0
  end

  if IsWeaklyDisabled(bot_hero) then
    self.trackers.time_weakly_disabled = self.trackers.time_weakly_disabled + elapsed
  end

  -- Gather observations on enemies
  -- All enemy units that observations should be gathered on
  local enemies = GetEntitiesToObserve(bot_hero)

  -- Gather observations for each unit
  for i, entity in pairs(enemies) do
    if entity:GetEvasion() > HIGH_EVASION then
      self:SetObservation("high_evasion")
    end

    if entity:GetStatusResistance() > HIGH_STATUS_RESISTANCE then
      self:SetObservation("high_status_resistance")
    end

    -- Gather item observations
    for _, i in pairs({ 0, 1, 2, 3, 4, 5, NEUTRAL_ITEM_SLOT }) do
      local item = entity:GetItemInSlot(i)

      if item then
        local name = item:GetName()
        -- All items have an associated simple observation
        self:SetObservation(name)

        -- Some items are also part of more general observations
        local dagon_item_names = {
          ["item_dagon"] = true,
          ["item_dagon_2"] = true,
          ["item_dagon_3"] = true,
          ["item_dagon_4"] = true,
          ["item_dagon_5"] = true,
        }

        local invisibility_item_names = {
          ["item_silver_edge"] = true,
          ["item_invis_sword"] = true,
        }

        local spell_block_item_names = {
          ["item_sphere"] = true,
          ["item_mirror_shield"] = true,
        }

        if name == "item_diffusal_blade" then
          self:SetObservation("mana_burn")
        elseif dagon_item_names[name] then
          self:SetObservation("dagon")
        elseif invisibility_item_names[name] then
          self:SetObservation("invisibility")
        elseif spell_block_item_names[name] then
          self:SetObservation("spell_block")
        end
      end
    end
  end
end


-- Finalizes observations for the current round (necessary because some observations can only be
-- determined after the round ends and all data for it is available)
function Observations:FinalizeCurrentRoundObservations(bot_hero, bot_team)
  local trackers = self.trackers

  -- Check hero-specific observations
  for hero_name, _ in pairs(GetEnemyHeroNames(bot_team)) do
    -- Check `mana_burn`
    if hero_name == "npc_dota_hero_antimage" then
      self:SetObservation("mana_burn")
    end

    -- Check `disruptor_cheat`
    if (hero_name == "npc_dota_hero_disruptor") and trackers.time_spent_alive < 5 then
      self:SetObservation("disruptor_cheat")
    end

    -- Check `invisibility` (also checked dynamically)
    if invisibility_heroes[hero_name] then
      self:SetObservation("invisibility")
    end

    -- Check `high_evasion` (also checked dynamically)
    if special_high_evasion_heroes[hero_name] then
      self:SetObservation("high_evasion")
    end
  end

  -- Check `high_total_disable` and `high_weak_disable`
  if trackers.time_spent_losing_health ~= 0 then
    local disable_ratio = trackers.time_disabled / trackers.time_spent_losing_health
    if disable_ratio > HIGH_TOTAL_DISABLE_RATIO then
      self:SetObservation("high_total_disable")
    end

    local weak_disable_ratio = trackers.time_weakly_disabled / trackers.time_spent_losing_health
    if weak_disable_ratio > HIGH_WEAK_DISABLE_RATIO then
      self:SetObservation("high_weak_disable")
    end

  end

  -- Check `high_consecutive_disable`
  if trackers.longest_disable > HIGH_CONSECUTIVE_DISABLE then 
    self:SetObservation("high_consecutive_disable")
  end

  -- Check damage type observations
  local physical = trackers.damage_taken["physical"]
  local magic = trackers.damage_taken["magic"]
  local pure = trackers.damage_taken["pure"]

  if magic > physical and magic > pure then
    self:SetObservation("high_magic_damage")
  elseif pure > physical and pure > magic then
    self:SetObservation("high_pure_damage")
  end
end


-- Returns a list of visible entities for the bot to gather observations on
function GetEntitiesToObserve(bot_hero)
  local bot_team = bot_hero:GetTeam()
  local enemies = {}

  -- All enemy heroes (main hero entities only)
  for _, id in pairs(GetPlayerIDs()) do
    local hero = PlayerResource:GetSelectedHeroEntity(id)
    if PlayerResource:GetTeam(id) ~= bot_team and bot_hero:CanEntityBeSeenByMyTeam(hero) then
      table.insert(enemies, hero)
    end
  end

  -- All enemy Spirit Bears
  for _, bear in pairs(Entities:FindAllByName("npc_dota_lone_druid_bear")) do
    if bear:GetTeam() ~= bot_team and bot_hero:CanEntityBeSeenByMyTeam(bear) then
      table.insert(enemies, bear)
    end
  end

  return enemies
end
