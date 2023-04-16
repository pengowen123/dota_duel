-- A base bot thinker implementation for other thinker classes to inherit from and customize as
-- needed
--
-- The required methods for a bot thinker, regardless of whether it inherits from `BotBase`, are:
-- - `New`
-- - `ShouldBuyScepter`
-- - `ShouldBuyShard`
-- - `ThinkShop`
-- - `Think`
-- - `ThinkHunt`
-- - `ThinkFight`
-- - `ThinkRun`
-- - `GetDesireHunt`
-- - `GetDesireFight`
-- - `GetDesireRun`
--
-- If inheriting from `BotBase`, the following methods and fields may be overridden or extended to
-- customize the bot's behavior:
-- - `BotBase:GetControllableUnits`
-- - `BotBase:GetAttackTarget`
-- - `BotBase:GetDisableTarget`
-- - `BotBase:GetPowerOfAvailableBuffs`
-- - All item `Think*` methods
-- - `BotBase.hunt_points`
-- - `BotBase.ability_think_functions`
-- - `BotBase.item_think_functions` (for adding/removing think functions only; existing think
--   functions can simply be overridden)
-- - `BotBase.buff_power`
-- - `BotBase.debuff_power`
-- - `BotBase.ability_modifiers`
--
-- In general, each hero's abilities and their respective buffs/debuffs should be added to
-- `ability_think_functions`, `buff_power`, `debuff_power`, and `ability_modifiers` (using
-- `table.insert` to avoid deleting existing entries unless overriding a default value).

BotBase = {}
BotBase.__index = BotBase


-- Initializes a subclass of `BotBase` that inherits its methods (which can be overridden)
function BotBase:InitializeSubclass(subclass)
  for k, v in pairs(BotBase) do
    if k ~= "__index" then
      subclass[k] = v
    end
  end
end

-- Returns a new thinker for the bot with the given player ID
function BotBase:New(player_id)
  bot = {}
  setmetatable(bot, self)

  -- The bot's player ID
  bot.player_id = player_id
  -- The bot's team
  bot.team = PlayerResource:GetTeam(bot.player_id)
  -- The slots of items to cast and swap into the backpack on round start
  bot.backpack_swap_slots = {}
  -- Handles to the bot's demonicon units, separated into `melee` and `ranged` sublists
  bot.demonicon_units = {}
  -- A list of all units controllable by the bot, which are not guaranteed to be valid
  bot.units = {}
  -- The current list of enemies to consider as potential targets
  bot.enemies = {}
  -- An iterator over random points to search for the enemy at while in hunt mode,
  -- cached to allow choosing unique points across think ticks
  bot.hunt_points = RandomHuntPoints:New(false, nil)
  -- The enemy that the bot is currently attacking, if any
  bot.attack_target = nil
  -- The enemy that the bot is currently trying to disable, if any
  bot.disable_target = nil
  -- A list of the bot's summoned units that are currently busy (i.e., casting a spell)
  -- `IsBusy` covers most cases, but this catches cases that it misses (mainly when multiple actions
  -- may be issued to a unit in a single game tick)
  bot.busy_units = {}

  -- Think functions for usage of individual abilities
  bot.ability_think_functions = {}

  -- Think functions for usage of individual items
  bot.item_think_functions = {
    ["item_satanic"] = self.ThinkSatanic,
    ["item_bloodthorn"] = self.ThinkBloodthorn,
    ["item_nullifier"] = self.ThinkNullifier,
    ["item_solar_crest"] = self.ThinkSolarCrest,
    ["item_sheepstick"] = self.ThinkSheepstick,
    ["item_mjollnir"] = self.ThinkMjollnir,
    ["item_ex_machina"] = self.ThinkExMachina,
  }

  -- The contribution to the bot's desire to fight from each buff on the bot's hero
  bot.buff_power = {
    ["modifier_item_satanic_unholy"] = 7.5,
    ["modifier_sheepstick_debuff"] = 5.0,
    ["modifier_item_nullifier_mute"] = 2.5,
  }
  -- The contribution to the bot's desire to fight from each debuff on the attack target
  bot.debuff_power = {
    ["modifier_bloodthorn_debuff"] = 5.0,
  }
  -- The modifiers associated with each ability or item, used to compute the power of abilities and
  -- items that are off cooldown
  bot.ability_modifiers = {
    ["item_satanic"] = "modifier_item_satanic_unholy",
    ["item_bloodthorn"] = "modifier_bloodthorn_debuff",
    ["item_sheepstick"] = "modifier_sheepstick_debuff",
    ["item_nullifier"] = "modifier_item_nullifier_mute",
  }

  return bot
end


-- Returns whether the bot should buy Aghanim's scepter
function BotBase:ShouldBuyScepter()
  return true
end


-- Returns whether the bot should buy Aghanim's shard
function BotBase:ShouldBuyShard()
  return true
end


-- Purchases the items in the `items` and `backpack_swap_items` lists for the bot, with the latter
-- being swapped into the main inventory to be cast on round start (see `PurchaseBackpackSwapItems`)
-- A demonicon is automatically purchased and swapped into the neutral item slot if the team does
-- not have one yet, which reduces the number of available backpack swap slots by one
function BotBase:PurchaseItems(hero, items, backpack_swap_items)
  PurchaseItems(hero, items, not DoesTeamHaveItem(self.team, "item_demonicon"))
  self.backpack_swap_slots = PurchaseBackpackSwapItems(hero, backpack_swap_items)
end


-- Checks whether the Disruptor glimpse cheat is predicted to occur, and adds a BKB to the backpack
-- swap items to be cast on round start if so
function BotBase:CheckDisruptorCheat(backpack_swap_items, predictions)
  if predictions["disruptor_cheat"] and DoesEnemyTeamHaveDisruptor(self.team) then
    table.insert(backpack_swap_items, "item_black_king_bar")
  end
end


-- Purchases items for the bot during the buy phase
function BotBase:ThinkShop(hero, predictions)
  local items = {}
  -- Items to cast on round start and swapped into the backpack
  local backpack_swap_items = {}

  self:CheckDisruptorCheat(backpack_swap_items, predictions)
  self:PurchaseItems(hero, items, backpack_swap_items)
end


-- Returns the target to attack, or nil if none is found
function BotBase:GetAttackTarget(hero, current_mode, observation_state)
  return GetAttackTarget(hero, self.enemies, DAMAGE_TYPE_PHYSICAL)
end


-- Returns the target to use disables on, or nil if none is found
function BotBase:GetDisableTarget(hero, current_mode, observation_state)
  return GetDisableTarget(hero, self.enemies)
end


-- Performs start-of-round actions
function BotBase:ThinkRoundStart(hero)
  print("round start")
  -- Reset unit handles
  self.units = {}
  self.enemies = {}
  self.attack_target = nil
  self.disable_target = nil
  self.busy_units = {}

  -- TODO: investigate printing 0 while still buying and swapping properly, and sometimes not
  print("backpack items: ", #self.backpack_swap_slots)
  print("items:")
  for i=0,5 do
    local item = hero:GetItemInSlot(i)
    print(item and item:GetName())
  end

  -- Cast round start items and swap them into the backpack
  self.demonicon_units = CastDemonicon(hero, true)
  CastAndBackpackItems(hero, self.backpack_swap_slots)

  -- Use all units to search for the enemy

  -- Necessary because `self.units` is not populated yet
  local units = self:GetControllableUnits(hero)
  -- Only highground positions are searched initially
  local hg_hunt_points = RandomHuntPoints:New(true, nil)
  -- `force_choose_new_points` is set to true here to clear any old position goals from the units
  MoveUnitsToHuntPoints(units, hg_hunt_points, true)
end


-- Performs general actions for any mode (always called before mode-specific think functions)
function BotBase:Think(hero, current_mode, observation_state)
  -- Update controllable unit list
  self.units = self:GetControllableUnits(hero)
  -- Update potential target list
  self.enemies = GetPotentialTargets(hero, ENEMY_SEARCH_RADIUS, true)
  -- Reset busy unit list
  self.busy_units = {}

  -- Get enemies to target
  self.attack_target = self:GetAttackTarget(hero, current_mode, observation_state)
  self.disable_target = self:GetDisableTarget(hero, current_mode, observation_state)

  -- Think for summoned units' abilities
  self:ThinkUnitAbilities(hero, current_mode, observation_state)

  -- Think for abilities and items
  self:ThinkItems(hero, current_mode, observation_state)
  self:ThinkAbilities(hero, current_mode, observation_state)
end


-- Performs actions for the hunt mode
function BotBase:ThinkHunt(hero, observation_state)
  print("hunt")

  -- Use all units to search for the enemy
  MoveUnitsToHuntPoints(self.units, self.hunt_points, false)
end


-- Performs actions for the fight mode
function BotBase:ThinkFight(hero, observation_state)
  print("fight")

  -- Attack the attack target with all units
  self:AttackTargetWithAllUnits()
end


-- Performs actions for the run mode
function BotBase:ThinkRun(hero, observation_state)
  print("run")

  if not self:IsBusy(hero) then
    local kite_point = GetKitePoint(
      hero:GetAbsOrigin(),
      GetAvoidPoints(hero, 1600.0),
      nil,
      nil,
      false,
      KITE_DIRECTION_CLOCKWISE
    )

    hero:MoveToPosition(kite_point)
  end

  if not HasBladeMailActive(self.attack_target) then
    -- Attack the attack target with all other units if it doesn't have blademail active
    self:AttackTargetWithAllUnits({ hero })
  else
    -- Run away with all units otherwise
    self:MoveAllUnitsToPosition(hero:GetAbsOrigin(), { hero })
  end
end


-- Returns the bot's desire to be in the hunt mode
function BotBase:GetDesireHunt(hero, current_mode, observation_state)
  local desire = 0.0

  -- If there are no visible enemies, look for them
  if #self.enemies == 0 then
    desire = desire + 1000.0
  end

  return desire
end


-- Returns the bot's desire to be in the fight mode
function BotBase:GetDesireFight(hero, current_mode, observation_state)
  local desire = 0.0

  -- If there are visible enemies, fight them
  if #self.enemies > 0 then
    desire = desire + 10.0
  end

  -- Prefer to fight when cooldowns are available or active
  desire = desire + self:GetPowerOfAvailableBuffs(hero)

  if self.attack_target then
    -- Prefer to fight when the attack target is disabled
    if IsFullyDisabled(self.attack_target) then
      desire = desire + 5.0
    end

    -- Prefer to fight when the attack target is on low health
    desire = desire + GetMissingHealthPercent(self.attack_target) / 3
  end

  return desire
end


-- Returns the bot's desire to be in the run mode
function BotBase:GetDesireRun(hero, current_mode, observation_state)
  local desire = 0.0

  -- Prefer to run when disabled
  if IsFullyDisabled(hero) then
    desire = desire + 100.0
  end

  -- Prefer to run when unable to attack
  if hero:IsDisarmed() or hero:IsAttackImmune() then
    desire = desire + 20.0
  end

  -- Prefer to run when restricted from casting abilities or items
  if hero:IsSilenced() then
    desire = desire + 10.0
  end

  if hero:IsMuted() then
    desire = desire + 10.0
  end

  -- Prefer to run when on low health
  desire = desire + GetMissingHealthPercent(hero) / 4

  -- Prefer to run when taking a lot of damage
  if observation_state["high_burst_damage"] then
    desire = desire + 20.0
  end

  -- Prefer to run when enemies have powerful temporary buffs
  for _, entity in pairs(self.enemies) do
    if IsMajorEntity(entity) and HasPowerfulStallableBuff(entity) then
      desire = desire + 10.0
    end
  end

  -- TODO: + for being inside thinker zone

  return desire
end


-- Adds the unit to the internal list of busy units for the current think tick
-- This prevent its actions from being canceled by later actions in the tick when used in
-- conjunction with `self.IsBusy`
function BotBase:SetBusy(entity)
  table.insert(self.busy_units, entity)
end


-- Returns whether the entity is currently busy
-- Similar to `IsBusy`, but additionally checks the internal list of busy units to cover units that
-- were manually marked as busy with `SetBusy`
function BotBase:IsBusy(entity)
  return IsBusy(entity) or Contains(self.busy_units, entity)
end


-- Returns all controllable units owned by the bot, which are not guaranteed to be valid
function BotBase:GetControllableUnits(hero)
  local units = {}

  -- Add the hero entity and all illusions/clones
  for _, entity in pairs(Entities:FindAllByClassname(hero:GetClassname())) do
    if entity:GetPlayerOwnerID() == self.player_id then
      table.insert(units, entity)
    end
  end

  -- Add summons
  for _, creep in pairs(self.demonicon_units.melee) do
    table.insert(units, creep)
  end

  for _, creep in pairs(self.demonicon_units.ranged) do
    table.insert(units, creep)
  end

  return units
end


-- Attacks the current attack target with all controllable units if one exists, except for those
-- in `exclude_units` and those that are busy
function BotBase:AttackTargetWithAllUnits(exclude_units)
  if self.attack_target then
    for _, entity in pairs(self.units) do
      if IsValidUnit(entity)
        and not self:IsBusy(entity)
        and not Contains(exclude_units, entity)
      then
        entity:MoveToTargetToAttack(self.attack_target)
      end
    end
  end
end


-- Moves all controllable units to the point, except for those in `exclude_units` and those that are
-- busy
function BotBase:MoveAllUnitsToPosition(point, exclude_units)
  for _, entity in pairs(self.units) do
    if IsValidUnit(entity)
      and not self:IsBusy(entity)
      and not Contains(exclude_units, entity)
    then
      entity:MoveToPosition(point)
    end
  end
end


-- Returns the total power of the bot's active or available buffs, debuffs, and other useful
-- cooldowns (based on the `buff_power`, `debuff_power`, and `ability_modifiers` fields)
-- This power represents the current strength of the bot in comparison to its default state (i.e.,
-- with no cooldowns active)
function BotBase:GetPowerOfAvailableBuffs(hero)
  local total = 0.0

  -- Sum power of buffs on the bot
  for _, modifier in pairs(hero:FindAllModifiers()) do
    local power = self.buff_power[modifier:GetName()]

    if power then
      total = total + power
    end
  end

  -- Sum power of debuffs on the attack target
  if self.attack_target then
    for _, modifier in pairs(self.attack_target:FindAllModifiers()) do
      local power = self.debuff_power[modifier:GetName()]

      if power then
        total = total + power
      end
    end
  end

  -- Sum power of available cooldowns
  for i=0,5 do
    local ability = hero:GetAbilityByIndex(i)
    local cooldown_ready = ability and (ability:GetCooldownTimeRemaining() == 0)
    local buff_name = ability and self.ability_modifiers[ability:GetAbilityName()]

    if cooldown_ready and buff_name then
      total = total + (self.buff_power[buff_name] or self.debuff_power[buff_name])
    end
  end

  for _, i in pairs({ 0, 1, 2, 3, 4, 5, NEUTRAL_ITEM_SLOT }) do
    local item = hero:GetItemInSlot(i)
    local cooldown_ready = item and (item:GetCooldownTimeRemaining() == 0)
    local buff_name = item and self.ability_modifiers[item:GetAbilityName()]

    if cooldown_ready and buff_name then
      total = total + (self.buff_power[buff_name] or self.debuff_power[buff_name])
    end
  end

  return total
end


-- Performs actions with the bot's abilities (based on the `ability_think_functions` field)
function BotBase:ThinkAbilities(hero, current_mode, observation_state)
  for _, think in pairs(self.ability_think_functions) do
    think(self, hero, current_mode, observation_state)
  end
end


-- Performs actions with the bot's items
function BotBase:ThinkItems(hero, current_mode, observation_state)
  for _, i in pairs({ 0, 1, 2, 3, 4, 5, NEUTRAL_ITEM_SLOT }) do
    local item = hero:GetItemInSlot(i)

    if item then
      local name = item:GetName()
      local think = self.item_think_functions[name]

      if think then
        think(self, item, hero, current_mode, observation_state)
      elseif not item:IsPassive() then
        print("no think function found for item:", name)
      end
    end
  end
end


-- Performs actions for the satanic item for the bot
function BotBase:ThinkSatanic(item, hero, current_mode, observation_state)
  local target = self.attack_target

  if target and CanCastAbility(hero, item) then
    -- Cast satanic if in danger of dying
    local wants_to_use = IsInAttackRange(hero, target)
      and not target:IsAttackImmune()
      and (hero:GetHealthPercent() < 25
        or observation_state["high_burst_damage"])

    if wants_to_use then
      hero:CastAbilityImmediately(item, self.player_id)
    end
  end
end


-- Performs actions for the bloodthorn item for the bot
function BotBase:ThinkBloodthorn(item, hero, current_mode, observation_state)
  local target = self.attack_target

  if target and CanCastAbility(hero, item, target) then
    -- Cast bloodthorn on the attack target if currently attacking it and it is unlikely to have
    -- aeon disk ready
    local wants_to_use = IsMajorEntity(target)
      and hero:IsAttacking()
      and IsLikelyNonIllusion(target)
      and not HasBuffForDuration(target, "modifier_bloodthorn_debuff", THINK_INTERVAL)
      and not IsAeonDiskRisk(target)

    if wants_to_use then
      hero:CastAbilityOnTarget(target, item, self.player_id)
      self:SetBusy(hero)
    end
  end
end


-- Performs actions for the nullifier item for the bot
function BotBase:ThinkNullifier(item, hero, current_mode, observation_state)
  local target = self.attack_target

  if target and CanCastAbility(hero, item, target) then
    -- Cast nullifier if the attack target is attack immune and no demonicon purge is available, or
    -- if it may have aeon disk available or active
    local needs_ethereal_dispel = target:IsAttackImmune()
      and IsInAttackRange(hero, target)
      -- Prefer using demonicon purges over nullifier for purging ethereal blade
      and (self:GetDemoniconUnitWithPurge() == nil)

    local wants_to_use = IsMajorEntity(target)
      and IsLikelyNonIllusion(target)
      and not HasBuffForDuration(target, "modifier_item_nullifier_mute", THINK_INTERVAL)
      and (needs_ethereal_dispel
        or (hero:IsAttacking() and IsAeonDiskRisk(target)))

    if wants_to_use then
      hero:CastAbilityOnTarget(target, item, self.player_id)
      self:SetBusy(hero)
    end
  end
end


-- Performs actions for the solar crest item for the bot
function BotBase:ThinkSolarCrest(item, hero, current_mode, observation_state)
  if CanCastAbility(hero, item) then
    -- Cast solar crest on a nearby ally hero within the cast range
    local cast_range = GetCastRange(hero, item)
    local filter = function(entity)
      return entity:IsHero()
        and not entity:IsIllusion()
        and not (entity == hero)
    end
    local allies = GetAllies(hero, cast_range, filter)

    for _, target in pairs(allies) do
      local wants_to_use =
        not HasBuffForDuration(target, "modifier_item_solar_crest_armor_addition", THINK_INTERVAL)

      if wants_to_use then
        hero:CastAbilityOnTarget(target, item, self.player_id)
        self:SetBusy(hero)
      end
    end
  end
end


-- Performs actions for the sheepstick item for the bot
function BotBase:ThinkSheepstick(item, hero, current_mode, observation_state)
  local target = self.disable_target or self.attack_target

  if target and CanCastAbility(hero, item, target) then
    -- Disable the disable target if it's not already disabled and is unlikely to have aeon disk
    -- ready
    local wants_to_use = IsMajorEntity(target)
      and IsLikelyNonIllusion(target)
      and not IsFullyDisabledForDuration(target, THINK_INTERVAL)
      and not IsAeonDiskRisk(target)

    -- If disabling the attack target, only do so when in attack range and if it's attackable
    if target == self.attack_target then
      wants_to_use = wants_to_use and IsInAttackRange(hero, target) and not target:IsAttackImmune()
    end

    if wants_to_use then
      hero:CastAbilityOnTarget(target, item, self.player_id)
      self:SetBusy(hero)
    end
  end
end


-- Performs actions for the mjollnir item for the bot
function BotBase:ThinkMjollnir(item, hero, current_mode, observation_state)
  if CanCastAbility(hero, item) then
    -- Cast mjollnir if taking damage
    local wants_to_use = observation_state["taking_damage"]
      and not hero:HasModifier("modifier_item_mjollnir_static")

    if wants_to_use then
      hero:CastAbilityOnTarget(hero, item, self.player_id)
      self:SetBusy(hero)
    end
  end
end


function BotBase:ThinkExMachina(item, hero, current_mode, observation_state)
  if CanCastAbility(hero, item) then
    -- Cast ex machina if enough important items are on cooldown
    local items_to_refresh = {
      ["item_sheepstick"] = true,
      ["item_satanic"] = true,
      ["item_bloodthorn"] = true,
    }

    local items_on_cooldown = 0

    for _, i in pairs({ 0, 1, 2, 3, 4, 5, NEUTRAL_ITEM_SLOT }) do
      local item = hero:GetItemInSlot(i)

      if item and items_to_refresh[item:GetName()] and (item:GetCooldownTimeRemaining() > 0) then
        items_on_cooldown = items_on_cooldown + 1
      end
    end

    local wants_to_use = items_on_cooldown >= 2

    if wants_to_use then
      hero:CastAbilityImmediately(item, self.player_id)
    end
  end
end


-- Returns a demonicon unit with its purge ability available, or nil if none exists
function BotBase:GetDemoniconUnitWithPurge()
  for _, entity in pairs(self.demonicon_units.ranged) do
    if IsValidUnit(entity) then
      local purge = entity:FindAbilityByName("necronomicon_archer_purge")

      if CanCastAbility(entity, purge) then
        return entity
      end
    end
  end
end


-- Performs actions with the bot's summoned unit's abilities
function BotBase:ThinkUnitAbilities(hero, current_mode, observation_state)
  -- Get the next demonicon archer with an available purge ability
  local archer = self:GetDemoniconUnitWithPurge()

  if (not archer) or self:IsBusy(archer) then
    return
  end

  local purge = archer:FindAbilityByName("necronomicon_archer_purge")

  if current_mode == MODE_FIGHT then
    local target = self.attack_target

    if target and CanCastAbility(archer, purge, target) then
      -- Purge the attack target if it's attack immune or has aeon disk active
      local wants_to_use = target
        and IsMajorEntity(target)
        and IsLikelyNonIllusion(target)
        and (target:IsAttackImmune() or HasAeonDiskBuff(target))

      if wants_to_use then
        archer:CastAbilityOnTarget(target, purge, self.player_id)
        self:SetBusy(archer)
      end
    end
  elseif current_mode == MODE_RUN then
    for _, entity in pairs(self.enemies) do
      local threat_range = GetThreatRange(entity)
      -- Purge enemies near the bot that aren't already disabled if the bot itself is not disabled
      -- This helps the bot escape
      local wants_to_use = IsMajorEntity(entity)
        and IsLikelyNonIllusion(entity)
        and not IsFullyDisabled(hero)
        and (hero:GetRangeToUnit(entity) <= threat_range)
        and not (IsFullyDisabled(entity) or IsWeaklyDisabled(entity))

      if wants_to_use and CanCastAbility(archer, purge, entity) then
        archer:CastAbilityOnTarget(entity, purge, self.player_id)
        self:SetBusy(archer)
        break
      end
    end
  end
end
