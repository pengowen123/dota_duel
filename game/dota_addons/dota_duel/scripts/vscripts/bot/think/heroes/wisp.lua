-- A bot implementation for Wisp


-- The target radius to use to keep the spirits at their max radius
MAX_SPIRITS_RADIUS = 10000
-- The maximum distance to stay at from the tethered unit
IDEAL_TETHER_RADIUS = 900.0


BotWisp = {}
BotWisp.__index = BotWisp
BotBase:InitializeSubclass(BotWisp)


function BotWisp:New(player_id)
  local bot = BotBase.New(self, player_id)

  bot.ability_think_functions = {
    self.ThinkTether,
    self.ThinkSpirits,
    self.ThinkOvercharge,
    self.ThinkRelocate,
  }

  -- The currently tethered unit, if any
  bot.tether_unit = nil

  bot.buff_power["modifier_wisp_tether"] = 2.5
  bot.buff_power["modifier_wisp_overcharge"] = 5.0

  bot.ability_modifiers["wisp_tether"] = "modifier_wisp_tether"
  bot.ability_modifiers["wisp_overcharge"] = "modifier_wisp_overcharge"

  return bot
end


function BotWisp:ThinkShop(hero, predictions)
  local items = {}
  -- Items to cast on round start and swapped into the backpack
  local backpack_swap_items = {}

  self:CheckDisruptorCheat(backpack_swap_items, predictions)

  -- Try to sneak up on the enemy if they are using perma-disable strategies
  if RandomChance(1, 4)
    or predictions["high_consecutive_disable"]
    or predictions["high_total_disable"]
  then
    table.insert(backpack_swap_items, "item_silver_edge")

    -- Avoid adding too many backpack swap items
    if #backpack_swap_items <= 1 then
      table.insert(backpack_swap_items, "item_smoke_of_deceit")
    end
  end

  local should_buy_sheepstick = predictions["high_consecutive_disable"]
    or predictions["high_total_disable"]
    or predictions["high_burst_damage"]
    or predictions["item_sheepstick"]
    or DoesEnemyTeamHaveBashLock(self.team)

  -- Neutral item
  if predictions["high_total_disable"] and not DoesEnemyTeamHaveBashLock(self.team) then
    table.insert(items, "item_mirror_shield")
  elseif predictions["spell_block"] and should_buy_sheepstick then
    table.insert(items, "item_ex_machina")
  else
    table.insert(items, "item_desolator_2")
  end

  -- Normal items
  table.insert(items, "item_assault")
  table.insert(items, "item_satanic")

  if DoesEnemyTeamHaveHero(self.team, "npc_dota_hero_spectre")
    or predictions["item_blade_mail"]
    or predictions["high_burst_damage"]
  then
    -- A second satanic is more useful for long-term sustain against burst damage and strong
    -- damage reflect
    table.insert(items, "item_satanic")
  else
    table.insert(items, "item_bloodthorn")
  end

  -- Counter evasion (bloodthorn normally works but may be dispelled)
  if predictions["high_evasion"] then
    table.insert(items, "item_monkey_king_bar")
  else
    table.insert(items, "item_greater_crit")
  end

  if DoesEnemyTeamHaveIllusionHero(self.team) then
    -- Counter illusions with mjollnir
    table.insert(items, "item_mjollnir")
    table.insert(items, "item_solar_crest")
  else
    if should_buy_sheepstick then
      -- Counter enemy disables or burst damage with a sheepstick to burst them down before they can
      -- attack
      table.insert(items, "item_sheepstick")

      if predictions["item_aeon_disk"] then
        table.insert(items, "item_nullifier")
      else
        table.insert(items, "item_greater_crit")
      end
    else
      -- Otherwise, use a more balanced build
      table.insert(items, "item_solar_crest")
      table.insert(items, "item_greater_crit")
    end
  end

  self:PurchaseItems(hero, items, backpack_swap_items)
end


-- Returns whether Wisp is tethered to a creep unit it controls
function BotWisp:IsTetheredToOwnCreep()
  return self.tether_unit
    and self.tether_unit:IsCreep()
    and (self.tether_unit:GetPlayerOwnerID() == self.player_id)
end


-- Returns whether Wisp is tethered to a hero unit
function BotWisp:IsTetheredToHero()
  return self.tether_unit and self.tether_unit:IsHero()
end


-- Returns the location of the tethered unit, if it exists
function BotWisp:GetTetherPoint()
  if self.tether_unit then
    return self.tether_unit:GetAbsOrigin()
  end
end


function BotWisp:GetAttackTarget(hero, current_mode, observation_state)
  if self.tether_unit
    and self.tether_unit:IsHero()
    and ShouldFollowOrders(hero, self.tether_unit)
    and self.tether_unit:GetAttackTarget()
  then
    -- Use the tethered unit's attack target if the unit is a hero
    return self.tether_unit:GetAttackTarget()
  else
    -- Use the default target otherwise
    return BotBase.GetAttackTarget(self, hero, current_mode, observation_state)
  end
end


function BotWisp:ThinkRoundStart(hero)
  -- Reset unit handles
  self.tether_unit = nil

  BotBase.ThinkRoundStart(self, hero)
end


function BotWisp:Think(hero, current_mode, observation_state)
  -- Update tether unit just in case (already done by `ThinkTether`, but in very rare cases it
  -- isn't)
  -- TODO: test that this is still necessary with thinktether change (permahex wisp and break tether manually)
  if not IsValidUnit(self.tether_unit) then
    self.tether_unit = nil
  end

  BotBase.Think(self, hero, current_mode, observation_state)
end


function BotWisp:ThinkHunt(hero, observation_state)
  BotBase.ThinkHunt(self, hero, observation_state)

  -- Have Wisp follow its tethered unit
  if self.tether_unit and ShouldFollowOrders(hero, self.tether_unit) then
    hero:MoveToPosition(self.tether_unit:GetAbsOrigin())
  end
end


function BotWisp:ThinkRun(hero, observation_state)
  if not self:IsBusy(hero) then
    local tether_point = nil
    local tether_radius = IDEAL_TETHER_RADIUS

    -- Stay within range of the tethered unit while running if it's a hero
    if self:IsTetheredToHero() then
      tether_point = self:GetTetherPoint()
    end

    local kite_point = GetKitePoint(
      hero:GetAbsOrigin(),
      GetAvoidPoints(hero, 1600.0),
      tether_point,
      tether_radius,
      false,
      KITE_DIRECTION_CLOCKWISE
    )

    hero:MoveToPosition(kite_point)
  end

  if not HasBladeMailActive(self.attack_target) then
    -- Attack the attack target with all other units if it doesn't have blademail active
    local tether_on_cooldown =
      hero:FindAbilityByName("wisp_tether"):GetCooldownTimeRemaining() > 0

    -- If tethered to a creep owned by Wisp and tether is on cooldown, have the creep follow Wisp
    -- to avoid breaking the tether
    local exclude_when_attacking = { hero }
    if self:IsTetheredToOwnCreep() and tether_on_cooldown then
      self.tether_unit:MoveToPosition(hero:GetAbsOrigin())
      table.insert(exclude_when_attacking, self.tether_unit)
    end

    self:AttackTargetWithAllUnits(exclude_when_attacking)
  else
    -- Run away with all units otherwise
    self:MoveAllUnitsToPosition(hero:GetAbsOrigin(), { hero })
  end
end


function BotWisp:GetDesireFight(hero, current_mode, observation_state)
  local desire = BotBase.GetDesireFight(self, hero, current_mode, observation_state)

  -- Prefer to fight more when tethered to a hero
  -- This makes Wisp more aggressive in non-1v1 games
  if self:IsTetheredToHero() then
    desire = desire + 10.0
  end

  return desire
end


function BotWisp:GetDesireRun(hero, current_mode, observation_state)
  local desire = BotBase.GetDesireRun(self, hero, current_mode, observation_state)

  -- Blademail is particularly dangerous for Wisp, so it is weighted higher
  if HasBladeMailActive(self.attack_target) then
    desire = desire + 10.0
  end

  return desire
end


-- Performs actions with the tether ability
function BotWisp:ThinkTether(hero, current_mode, observation_state)
  -- Detect when tether breaks
  if not hero:HasModifier("modifier_wisp_tether") then
    self.tether_unit = nil
  end

  if self:IsBusy(hero) then
    return
  end

  local tether = hero:FindAbilityByName("wisp_tether")

  if CanCastAbility(hero, tether) and (self.tether_unit == nil) then
    -- Choose a nearby ally to tether
    local cast_range = GetCastRange(hero, tether)
    local filter = function(entity)
      -- Don't tether to illusions, wards, or Wisp itself
      return not (entity:IsIllusion() or entity:IsOther() or (entity == hero))
    end
    local allies = GetAllies(hero, cast_range, filter)

    local compare = function(a, b)
      -- Choose the ally with the highest attack speed
      return (not a) or b:GetAttacksPerSecond() > a:GetAttacksPerSecond()
    end
    local tether_unit = MaxBy(allies, compare)

    -- Cast tether on the target if one was chosen
    if tether_unit then
      self.tether_unit = tether_unit
      hero:CastAbilityOnTarget(tether_unit, tether, self.player_id)
      self:SetBusy(hero)
    end
  end
end


-- Performs actions with the spirit abilities
function BotWisp:ThinkSpirits(hero, current_mode, observation_state)
  local spirits_in = hero:FindAbilityByName("wisp_spirits_in")
  local spirits_out = hero:FindAbilityByName("wisp_spirits_out")

  -- Set the target spirit radius
  local target_radius = nil
  if self.attack_target then
    -- Move spirits to the attack the target
    target_radius = hero:GetRangeToUnit(self.attack_target)
  else
    -- Passively keep spirits at max range when not fighting
    target_radius = MAX_SPIRITS_RADIUS
  end

  -- Get the current radius of the spirits
  local current_radius = nil

  for i, spirit in pairs(Entities:FindAllByClassname("npc_dota_wisp_spirit")) do
    if (spirit:GetPlayerOwnerID() == self.player_id) then
      current_radius = hero:GetRangeToUnit(spirit)
      -- Getting the last spirit avoids counting dead ones
      -- break
    end
  end

  if current_radius then
    -- Update the state of the spirit abilities to achieve the target radius
    if current_radius > target_radius then
      if not spirits_in:GetToggleState() then
        hero:CastAbilityToggle(spirits_in, self.player_id)
      end
    else
      if not spirits_out:GetToggleState() then
        hero:CastAbilityToggle(spirits_out, self.player_id)
      end
    end
  end
end


-- Performs actions with the overcharge ability
function BotWisp:ThinkOvercharge(hero, current_mode, observation_state)
  if self:IsBusy(hero) then
    return
  end

  local overcharge = hero:FindAbilityByName("wisp_overcharge")

  if CanCastAbility(hero, overcharge) then
    local unit = hero

    if self.tether_unit then
      unit = self.tether_unit
    end

    -- If the tether unit (or Wisp if no unit is tethered) is attacking a hero, cast overcharge
    if unit:IsAttacking() then
      local target = unit:GetAttackTarget()

      if target and IsMajorEntity(target) and not IsAeonDiskRisk(target) then
        hero:CastAbilityImmediately(overcharge, self.player_id)
      end
    end
  end
end


-- Performs actions with the relocate ability
function BotWisp:ThinkRelocate(hero, current_mode, observation_state)
  if self:IsBusy(hero) then
    return
  end

  local relocate = hero:FindAbilityByName("wisp_relocate")

  if CanCastAbility(hero, relocate) then
    if current_mode == MODE_RUN then
      -- If running away, pick a far away point and relocate to it unless tethered to a hero
      if not self:IsTetheredToHero() then
        local filter = function(point)
          return DistanceToPoint(hero, point) > 2000.0
        end
        local escape_point = RandomHuntPoints:New(false, filter):Next()

        hero:CastAbilityOnPosition(escape_point, relocate, self.player_id)
        self:SetBusy(hero)
      end
    else
      -- Otherwise, cast relocate onto the attack target if one exists and is far away
      if self.attack_target and hero:GetRangeToUnit(self.attack_target) > 2500.0 then
        -- Don't relocate if tethered to a creep, as it will be left behind
        if not (self.tether_unit and self.tether_unit:IsCreep()) then
          local target_position = self.attack_target:GetAbsOrigin()

          hero:CastAbilityOnPosition(target_position, relocate, self.player_id)
          self:SetBusy(hero)
        end
      end
    end
  end
end


function BotBase:ThinkSatanic(item, hero, current_mode, observation_state)
  local target = self.attack_target

  if target and CanCastAbility(hero, item) then
    -- Cast satanic if Wisp or the tethered unit is in danger of dying, or if Wisp cannot attack and
    -- has a cooldown active (to avoid wasting it)
    local wants_to_use = IsInAttackRange(hero, target)
      and not target:IsAttackImmune()
      and (hero:GetHealthPercent() < 25
        or observation_state["high_burst_damage"]
        or (self.tether_unit and (self.tether_unit:GetHealthPercent() < 50))
        or (hero:HasModifier("modifier_wisp_overcharge") and hero:IsAttackImmune()))

    if wants_to_use then
      hero:CastAbilityImmediately(item, self.player_id)
    end
  end
end


function BotWisp:ThinkSolarCrest(item, hero, current_mode, observation_state)
  if CanCastAbility(hero, item) then
    -- Cast solar crest on the tethered unit, or use default casting behavior otherwise
    local target = self.tether_unit

    if target then
      local wants_to_use =
        not HasBuffForDuration(target, "modifier_item_solar_crest_armor_addition", THINK_INTERVAL)

      if wants_to_use then
        hero:CastAbilityOnTarget(target, item, self.player_id)
        self:SetBusy(hero)
      else
        -- This only runs if a target exists but already has the solar crest buff
        -- The former check is necessary to prevent Wisp from casting solar crest on an ally hero
        -- before summoning demonicon units
        BotBase.ThinkSolarCrest(self, item, hero, current_mode, observation_state)
      end
    end
  end
end
