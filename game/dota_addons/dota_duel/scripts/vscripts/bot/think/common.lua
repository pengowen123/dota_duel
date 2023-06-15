-- Common bot logic


-- Indicates that the kite points should be selected to move around the arena in a clockwise pattern
KITE_DIRECTION_CLOCKWISE = 0
-- Indicates that the kite points should be selected to move around the arena in a counterclockwise
-- pattern
KITE_DIRECTION_COUNTERCLOCKWISE = 1


-- Returns whether the team opposite to `team` has a hero that spawns many illusions
illusion_heroes = {
  ["npc_dota_hero_phantom_lancer"] = true,
  ["npc_dota_hero_naga_siren"] = true,
}
function DoesEnemyTeamHaveIllusionHero(team)
  for hero, _ in pairs(GetEnemyHeroNames(team)) do
    if illusion_heroes[hero] then
      return true
    end
  end

  return false
end


-- Returns whether the NPC is fully disabled
function IsFullyDisabled(npc)
  return npc:IsStunned()
    or (npc:IsSilenced() and npc:IsMuted())
    or npc:IsHexed()
    or IsTaunted(npc)
    or IsFeared(npc)
end


-- Returns whether the NPC is considered disabled in a way that is dispellable or otherwise not as
-- strong as a stun/doom
function IsWeaklyDisabled(npc)
  return (not IsFullyDisabled(npc))
    and (
      npc:IsSilenced()
        or npc:IsDisarmed()
        or npc:IsRooted()
        or IsSlowed(npc)
    )
end


-- Returns whether the NPC is considered fully disabled and will continue to be so for at least
-- `duration` seconds
function IsFullyDisabledForDuration(npc, duration)
  if not IsFullyDisabled(npc) then
    return false
  end

  -- The states applied to the NPC by any modifier for at least `duration` seconds
  local state = {}

  -- Check doom manually (the duration is on the aura modifier itself, which applies no states and
  -- therefore is not detected)
  local doom = npc:FindModifierByName("modifier_doom_bringer_doom")

  if doom then
    local aura_npc = doom:GetAuraOwner()

    if aura_npc then
      local doom_aura = aura_npc:FindModifierByName("modifier_doom_bringer_doom_aura_enemy")
        or aura_npc:FindModifierByName("modifier_doom_bringer_doom_aura_self")

      if doom_aura and doom_aura:GetRemainingTime() >= duration then
        return true
      end
    end
  end

  -- Check all modifiers on the NPC
  for _, modifier in pairs(npc:FindAllModifiers()) do
    if modifier:GetRemainingTime() >= duration then
      modifier:CheckStateToTable(state)

      -- Check whether the states result in the NPC being fully disabled (same as `IsFullyDisabled`)
      if state[MODIFIER_STATE_STUNNED_STR]
        or state[MODIFIER_STATE_HEXED_STR]
        or (state[MODIFIER_STATE_SILENCED_STR] and state[MODIFIER_STATE_MUTED_STR])
        or state[MODIFIER_STATE_TAUNTED_STR]
        or state[MODIFIER_STATE_FEARED_STR]
      then
        return true
      end
    end
  end

  return false
end


-- Returns whether the NPC is slowed
function IsSlowed(npc)
  return npc:GetIdealSpeed() < npc:GetIdealSpeedNoSlows()
end


-- Returns whether the NPC is stunned in a way that may be bypassed by stun-ignoring abilities
function IsStunnedBypassable(npc)
  return npc:IsStunned() or IsTaunted(npc)
end


-- Consumes Aghanim's Scepter for the NPC if it does not already have it
function ConsumeAghanimsScepter(npc)
  if not HasConsumedScepter(npc) then
    npc:AddItemByName("item_ultimate_scepter_2")
  end
end


-- Consumes Aghanim's Shard for the NPC if it does not already have it
function ConsumeAghanimsShard(npc)
  if not HasScepterShard(npc) then
    npc:AddItemByName("item_aghanims_shard")
  end
end


-- Purchases the items in `items` for the NPC, backpacking its neutral item for a demonicon for
-- use on round start if `add_demonicon` is true
-- `items` must not have more than 9 items (1 equipped neutral item, 6 equipped normal items, and 2
-- backpacked items), but if `add_demonicon` is false, then 3 backpacked items are allowed
function PurchaseItems(npc, items, add_demonicon)
  -- Clear the npc's inventory first to make room
  ClearInventory(npc)

  for _, item in pairs(items) do
    npc:AddItemByName(item)
  end

  if add_demonicon then
    local neutral_item = npc:GetItemInSlot(NEUTRAL_ITEM_SLOT)

    if neutral_item then
      -- Swap the neutral item to the last backpack slot if one is equipped
      npc:SwapItems(8, NEUTRAL_ITEM_SLOT)
    end

    -- Add the demonicon
    npc:AddItemByName("item_demonicon")
  end
end


-- Returns a list of all empty slots in the NPC's inventory and backpack, starting from `start_slot`
function GetEmptySlots(npc, start_slot)
  if start_slot == nil then
    start_slot = 0
  end

  local empty_slots = {}

  for i=start_slot,8 do
    if npc:GetItemInSlot(i) == nil then
      table.insert(empty_slots, i)
    end
  end

  return empty_slots
end


-- Purchases the backpack swap items in `items` for the NPC, swapping them into the inventory for
-- use when the round starts. Returns a map of swapped inventory slots to be swapped again after the
-- items are cast, where the values are the slots of the items to be cast.
-- `items` must not contain more elements than the NPC has empty backpack slots.
function PurchaseBackpackSwapItems(npc, items)
  local slots = {}

  -- Find empty slots in the NPC's inventory
  local empty_slots = GetEmptySlots(npc)
  local empty_backpack_slots = GetEmptySlots(npc, 6)
  local has_empty_main_inventory_slot = #empty_slots > #empty_backpack_slots

  -- Check whether there is enough room to purchase and swap the items
  if #empty_backpack_slots < #items then
    print("not enough backpack slots for backpack swap items")
    return {}
  end

  -- Add the items
  for i, backpack_slot in pairs(empty_backpack_slots) do
    local item = items[i]

    if item then
      -- Add the item
      npc:AddItemByName(item)

      -- Swap it into the correct backpack slot if necessary (handles empty main inventory slots)
      if has_empty_main_inventory_slot then
        -- The first empty slot is where items end up if the main inventory is not full
        local first_empty_slot = empty_slots[1]
        npc:SwapItems(first_empty_slot, backpack_slot)
      end

      -- Swap it into the main inventory (starting with the first main inventory slot)
      -- The actual swap takes place later to avoid invalidating `empty_slots` by modifying the
      -- inventory
      local main_inventory_slot = i - 1
      slots[backpack_slot] = main_inventory_slot
    end
  end

  -- Actually perform the swaps (calculated above)
  for a, b in pairs(slots) do
    npc:SwapItems(a, b)
  end

  return slots
end


-- Casts the non-targeted items in the specified inventory slots of the NPC and then swaps them to
-- the backpack. The keys of `item_slots` are used as the backpack slots to swap the items into
-- after casting.
function CastAndBackpackItems(npc, item_slots)
  for backpack_slot, main_inventory_slot in pairs(item_slots) do
    local item = npc:GetItemInSlot(main_inventory_slot)

    if item then
      -- Cast the item
      npc:CastAbilityImmediately(item, npc:GetPlayerOwnerID())
      -- Swap it into its corresponding backpack slot
      npc:SwapItems(backpack_slot, main_inventory_slot)
    end
  end
end


-- Returns whether any player on `team` has the specified item in their inventory
function DoesTeamHaveItem(team, item_name)
  for _, entity in pairs(GetPlayerEntities()) do
    if entity:GetTeam() == team then
      if entity:HasItemInInventory(item_name) then
        return true
      end
    end
  end

  return false
end


-- Casts demonicon for the NPC if it's in its neutral item slot and returns a table of handles to
-- the spawned units. Also swaps the demonicon with the first neutral item found in the NPC's
-- backpack if `swap_after` is true.
--
-- The `melee` subtable of the return value contains all melee units, and the `ranged` subtable
-- contains all ranged units.
function CastDemonicon(npc, swap_after)
  -- Cast demonicon
  local neutral_item = npc:GetItemInSlot(NEUTRAL_ITEM_SLOT)

  if neutral_item and neutral_item:GetName() == "item_demonicon" then
    npc:CastAbilityImmediately(neutral_item, npc:GetPlayerOwnerID())

    if swap_after then
      -- Swap the bot's real neutral item back to the neutral slot if one exists
      for i=6,8 do
        local item = npc:GetItemInSlot(i)

        if item and IsNeutralItem(item) and not (i == NEUTRAL_ITEM_SLOT) then
          npc:SwapItems(i, NEUTRAL_ITEM_SLOT)
          break
        end
      end
    end
  end

  return GetDemoniconUnits(npc:GetPlayerOwnerID())
end


-- Returns a table containing all demonicon units owned by the given player
-- The `melee` subtable contains all melee units, and the `ranged` subtable contains all ranged
-- units
function GetDemoniconUnits(player_id)
  local units = {
    melee = {},
    ranged = {},
  }

  for i, entity in pairs(Entities:FindAllByClassname("npc_dota_creep")) do
    if entity.GetPlayerOwnerID and entity:GetPlayerOwnerID() == player_id then
      if entity:GetUnitName() == "npc_dota_necronomicon_warrior_3" then
        table.insert(units.melee, entity)
      elseif entity:GetUnitName() == "npc_dota_necronomicon_archer_3" then
        table.insert(units.ranged, entity)
      end
    end
  end

  return units
end


-- Returns the threat range of the provided NPC, based on their ability range, attack range, and
-- movement speed
function GetThreatRange(npc)
  -- All attacking units gain bonus attack range that seems to be based on the target's hull radius,
  -- which is assumed to be the same for all heroes here
  local attack_range = npc:Script_GetAttackRange() + npc:GetHullRadius()

  -- Increase melee attack range to account for their own hull radius
  if npc:GetAttackCapability() == DOTA_UNIT_CAP_MELEE_ATTACK then
    attack_range = attack_range + npc:GetHullRadius()
  end

  -- Find the max cast range of any non-global ability
  local cast_range = 0
  for i=0,5 do
    local ability = npc:GetAbilityByIndex(i)

    if ability then
      local range = ability:GetCastRange(npc:GetAbsOrigin(), npc)

      -- Global abilities have a cast range of zero, but it is checked just to be safe
      if (range < 3000) and (range > cast_range) then
        cast_range = range
      end
    end
  end

  -- Include items in the search
  for i=0,5 do
    local item = npc:GetItemInSlot(i)

    if item then
      local range = item:GetCastRange(npc:GetAbsOrigin(), npc)

      if range > cast_range then
        cast_range = range
      end
    end
  end

  -- Add the NPC's bonus cast range
  cast_range = cast_range + npc:GetCastRangeBonus()

  -- Pick the larger of the two ranges
  local base_range = attack_range

  if cast_range > attack_range then
    base_range = cast_range
  end

  -- Add the NPC's potential travel distance in one second to the range to account for unreactable
  -- movement
  local unreactable_time = 1
  local movement_speed = npc:GetIdealSpeed()

  return base_range + movement_speed * unreactable_time
end


-- Returns a list of units on `team` within `radius` units of `point`, with an optional filter
-- applied
function GetUnits(team, point, radius, filter)
  local entities = {}

  local entity = Entities:First()
  while entity do
    -- NOTE: `FindAllInSphere` is dysfunctional, so the distance is manually checked for each entity
    if DistanceToPoint(entity, point) <= radius then
      if IsValidUnit(entity) and (entity:GetTeam() == team)
        and ((not filter) or filter(entity))
      then
        table.insert(entities, entity)
      end
    end

    entity = Entities:Next(entity)
  end

  -- The order of the entities is randomized to prevent implicit dependencies on entity index
  return RandomizeList(entities)
end


-- Returns whether `entity` is a special high-priority target (e.g., supernova egg and tombstone)
special_high_priority_targets = {
  ["npc_dota_phoenix_sun"] = true,
  ["npc_dota_unit_tombstone4"] = true,
}
function IsSpecialHighPriorityTarget(entity)
  return entity.GetUnitName and special_high_priority_targets[entity:GetUnitName()] ~= nil
end


-- Returns whether `entity` is a major entity (e.g., heroes, clones, and certain ward-type units)
function IsMajorEntity(entity)
  return entity.IsHero
    and (entity:IsHero()
      or entity:GetClassname() == "npc_dota_lone_druid_bear"
      or IsSpecialHighPriorityTarget(entity)
    )
end


-- Returns whether `entity` is a minor entity (e.g., creeps and wards)
function IsMinorEntity(entity)
  return not IsMajorEntity(entity)
end


-- Returns a list of allied units of `npc` within `radius` units of it, including `npc`, with an
-- optional filter applied
function GetAllies(npc, radius, filter)
  local position = npc:GetAbsOrigin()

  return GetUnits(npc:GetTeam(), position, radius, filter)
end


-- Returns a list of major visible enemies of `npc` (e.g., heroes, clones, and certain ward-type
-- units) within `radius` units of it
function GetMajorEnemies(npc, radius)
  local enemy_team = GetOppositeTeam(npc:GetTeam())
  local position = npc:GetAbsOrigin()
  local filter = function(entity)
    return IsVisible(entity) and IsMajorEntity(entity)
  end

  return GetUnits(enemy_team, position, radius, filter)
end


-- Returns a list of minor visible enemies of `npc` (e.g., creeps and wards) within
-- `radius` units of it
function GetMinorEnemies(npc, radius)
  local enemy_team = GetOppositeTeam(npc:GetTeam())
  local position = npc:GetAbsOrigin()
  local filter = function(entity)
    return IsVisible(entity) and not IsMajorEntity(entity)
  end

  return GetUnits(enemy_team, position, radius, filter)
end


-- Returns a list of 2-element lists containing the positions and threat ranges of each major
-- visible enemy of `npc`
function GetEnemyPositionsAndRanges(npc)
  local result = {}

  for _, entity in pairs(GetMajorEnemies(npc, ENEMY_SEARCH_RADIUS)) do
    local position = entity:GetAbsOrigin()
    local threat_range = GetThreatRange(entity)
    table.insert(result, { position, threat_range })
  end

  return result
end


-- Returns whether the point is outside the playable area of the arena (inaccessible areas are not
-- considered playable)
function IsPointOutsideArena(point)
  local height = GetGroundHeight(point, nil)

  return (height < 150) or (height > 500)
end


-- Adjusts `point` to stay within the arena, attempts to move it away from any lowground if
-- `prefer_highground` is true, and attempts to keep it within `constraint_radius` units of
-- `constraint_point` if the latter is provided
-- Adjusts points in the direction specified by `kite_direction` (see `KITE_DIRECTION_*`)
function ApplyPositionGoalBoundaries(
  point,
  prefer_highground,
  kite_direction,
  constraint_point,
  constraint_radius
)
  local point_height = GetGroundHeight(point, nil)

  -- The directions to check boundaries in, in 45 degree increments
  local directions = {
    Vector(1, 0, 0),
    Vector(1, 1, 0),
    Vector(0, 1, 0),
    Vector(-1, 1, 0),
    Vector(-1, 0, 0),
    Vector(-1, -1, 0),
    Vector(0, -1, 0),
    Vector(1, -1, 0),
  }
  local num_directions = #directions


  -- Returns whether the point is outside the arena, or on the lowground if `prefer_highground` is
  -- true, or outside `constraint_radius` of `constraint_point`
  local is_outside_boundaries = function(p)
    local h = GetGroundHeight(p, nil)
    return IsPointOutsideArena(p)
      or (prefer_highground and (h < point_height))
      or (constraint_point ~= nil and ((p - constraint_point):Length2D() > constraint_radius))
  end

  -- Applies the boundaries in the `i`th direction to `p` and returns the adjusted point
  local apply_boundaries_in_direction = function(i, p)
    -- The direction to check boundaries in
    local direction = directions[i]

    -- The test point to check whether the original point is close to the boundary in this direction
    local test_offset = direction * 300
    local test_point = p + test_offset

    -- Check if the test point is outside the boundary, and adjust the point and test point if so
    local new_point = p
    -- Whether any adjustments were applied in this direction
    local adjusted = false
    local n = 1

    while is_outside_boundaries(test_point) and (n <= 6) do
      adjusted = true

      -- Offset the point in the opposite direction, increasing the distance for each failure
      new_point = new_point - direction * 100 * n

      -- Move the test point to reflect the new point position
      test_point = new_point + test_offset
      n = n + 1
    end

    if adjusted then
      -- Also offset in an orthogonal direction to promote circular kiting for the bot, but only if
      -- adjustments in the current direction were actually made (otherwise, many random orthogonal
      -- adjustments may be made)
      local orthogonal_direction = directions[((i + 1) % num_directions) + 1]
      new_point = new_point + orthogonal_direction * 100
    end

    if is_outside_boundaries(new_point) then
      -- If this application failed to correct the point, just return the original and try the next
      -- direction
      return p
    else
      return new_point
    end
  end

  -- Directions may be checked in clockwise or counterclockwise order
  local i_start = 1
  local i_end = num_directions
  local increment = 1

  if kite_direction == KITE_DIRECTION_CLOCKWISE then
    i_start = num_directions
    i_end = 1
    increment = -1
  end

  -- Check boundaries in each direction
  for i = i_start, i_end, increment do
    point = apply_boundaries_in_direction(i, point)
  end

  return point
end


-- Returns the position to move to in order to stay a specified distance away from multiple points
-- The returned position will be within `constraint_radius` units of `constraint_point`
-- `avoid_points` should be a list of 2-element lists containing each point and its associated
-- distance
-- If `prefer_highground` is true, lower elevation points will be avoided if possible
-- If `kite_clockwise` is true, the returned positions will tend to move clockwise around the arena
-- The returned positions will tend to move in the the direction specified by `kite_direction` (see
-- `KITE_DIRECTION_*`)
function GetKitePoint(
  current_position,
  avoid_points,
  constraint_point,
  constraint_radius,
  prefer_highground,
  kite_direction
)
  -- TODO: fix bots getting cornered easily
  -- TODO: fix on classic map (look into raising exterior edge for easy out of bounds detection, or maybe add fixed arena bounds)
  -- TODO: fix with multiple enemies (average not very good)
  -- TODO: use DebugDrawSphere to test

  -- Points at the specified distance from each avoid point that lie directly between the point and
  -- the current position
  local edge_points = {}

  for _, p in pairs(avoid_points) do
    local point = p[1]
    local distance = p[2]
    -- Find the point exactly at the preferred distance from the point
    local edge = LerpToDistance(point, current_position, distance)
    table.insert(edge_points, edge)
  end

  -- Get the average of the points
  local average = edge_points[1]

  for i, p in pairs(edge_points) do
    -- The sum starts with the first point, so exclude it here
    if i ~= 1 then
      average = average + p
    end
  end

  if average ~= nil then
    average = average / #edge_points
  else
    average = current_position
  end

  -- Adjust the initial point to avoid violating boundaries
  local bounded = ApplyPositionGoalBoundaries(
    average,
    prefer_highground,
    kite_direction,
    constraint_point,
    constraint_radius
  )

  -- Add random noise to the position
  local noise = RandomVector(POSITION_GOAL_RANDOMNESS)
  bounded = bounded + noise

  -- Apply the constraint if specified
  local constrained = bounded

  if constraint_point then
    constrained = LerpToDistance(constraint_point, bounded, constraint_radius)
  end

  return constrained
end


-- Returns a list of 2-element lists containing points for the NPC to avoid and the distance to
-- maintain from them
-- The distances will all be `fixed_distance` if specified
function GetAvoidPoints(npc, fixed_distance)
  -- All significant enemies are to be avoided at their threat ranges
  local result = GetEnemyPositionsAndRanges(npc)

  -- Set the fixed avoid distance for each point if specified
  if fixed_distance ~= nil then
    for _, p in pairs(result) do
      p[2] = fixed_distance
    end
  end

  -- TODO: add ability thinker points

  return result
end


-- Returns the expected DPS of the NPC
function GetDPS(npc)
  local attack_speed = npc:GetAttackSpeed()

  -- Adjust the NPC's attack speed to account for illusions not getting a bonus from consumed moon
  -- shard (which is an oversight in the base game)
  -- Without this adjustment, sorting enemies by `GetDPS` will always result in the bot finding the
  -- real hero
  if npc:HasModifier("modifier_item_moon_shard_consumed") and npc:IsIllusion() then
    attack_speed = attack_speed + MOON_SHARD_CONSUMED_ATTACK_SPEED
  end

  -- TODO: maybe crit and evasion handling
  return npc:GetAverageTrueAttackDamage(nil) * attack_speed / npc:GetBaseAttackTime()
end


-- Returns the current effective health of the NPC against a certain damage type (one of
-- `DAMAGE_TYPE_*`)
function GetCurrentEHP(npc, damage_type)
  return npc:GetHealth() / GetDamageMultiplierForNPC(npc, damage_type)
end


-- Returns a list of all enemies to consider as potential targets within `radius` units of the NPC
-- Prioritizes major enemies (e.g., heroes and clones) over others if `prioritize_major` is true
function GetPotentialTargets(npc, radius, prioritize_major)
  local enemies = GetMajorEnemies(npc, radius)

  -- Only include minor enemies if not prioritizing major enemies or if there are no major enemies
  if (not prioritize_major) or (#enemies == 0) then
    for _, entity in pairs(GetMinorEnemies(npc, radius)) do
      table.insert(enemies, entity)
    end
  end

  return enemies
end


-- Returns the target on which the NPC should focus its damage output given the NPC's primary damage
-- type, or nil if none is found
function GetAttackTarget(npc, enemies_to_consider, damage_type)
  -- The filter to apply when choosing an attack target
  local filter = function(e)
    return true
  end

  -- The metric to use in comparing potential attack targets (will be maximized in the sort)
  local metric = function(e)
    -- TODO: tune this
    -- TODO: ignore wk aghs ghosts
    local score =
        1.0 * GetDPS(e)
      - 0.25 * GetCurrentEHP(e, damage_type)
      + 10.0 * GetMissingHealthPercent(e)
      + 3000.0 * GetNonIllusionConfidence(e)
      - 0.5 * npc:GetRangeToUnit(e)

    if IsLikelyNonIllusion(e) then
      score = score + 3000.0
    end

    if e:IsAttackImmune() or e:IsUntargetable() then
      score = score - 500.0
    end

    if IsSpecialHighPriorityTarget(e) then
      score = score + 1000.0
    end

    return score
  end

  local compare = function(a, b)
    print("metric, isreal, name:", b and metric(b), b and (not b:IsIllusion()), b and b:GetClassname())
    -- Choose the enemy with the highest metric value that also passes the filter
    return filter(b)
      and ((not a) or (metric(b) > metric(a)))
  end

  return MaxBy(enemies_to_consider, compare)
end


-- Returns the target on which the NPC should focus its disable output (stuns, slows, etc.) given
-- the NPC's primary damage type, or nil if none is found
-- TODO: convert this to metric system
--       lower metric for already disabled
--       lower metric for range
function GetDisableTarget(npc, enemies_to_consider)
  -- The filter to apply when choosing a disable target
  -- Only selects major enemies, as disabling minor ones is likely to be a waste
  local filter = function(e)
    return IsMajorEntity(e)
      -- Ignore ward-type units
      and not e:IsOther()
      -- Only spend disables on enemies that are unlikely to be illusions
      and IsLikelyNonIllusion(e)
  end

  -- Prioritize enemies that are channeling abilities
  for _, enemy in pairs(enemies_to_consider) do
    if IsMajorEntity(enemy) and enemy:IsChanneling() then
      return enemy
    end
  end

  -- Otherwise, choose the enemy with the highest DPS that also passes the filter
  local compare = function(a, b)
    return filter(b)
      and ((not a) or (GetDPS(b) > GetDPS(a)))
  end

  return MaxBy(enemies_to_consider, compare)
end


-- Moves each unit in `units` to random hunt points provided by the `hunt_points` iterator (see
-- `RandomHuntPoints`)
-- New points are only chosen for each unit once they have reached their existing goal point unless
-- `force_choose_new_points` is true, in which case new points are always chosen
-- The goal points for each entity may be read with their `GetInitialGoalPosition` method
function MoveUnitsToHuntPoints(units, hunt_points, force_choose_new_points)
  for _, entity in pairs(units) do
    if IsValidUnit(entity) and not IsBusy(entity) then
      local current_goal = entity:GetInitialGoalPosition()
      local choose_new_goal = force_choose_new_points

      -- Check whether the current goal has been reached and choose a new one if so
      if current_goal then
        -- NOTE: This works for newly-summoned units because their initial goal starts at or near
        --       their spawn position, causing this condition to be met immediately
        if DistanceToPoint(entity, current_goal) < POSITION_GOAL_REACHED_RADIUS then
          choose_new_goal = true
        end
      else
        -- If there is no current goal, choose a new one
        choose_new_goal = true
      end

      -- Choose a new goal point if necessary
      if choose_new_goal then
        local point = hunt_points:Next()
        entity:SetInitialGoalPosition(point)
      end

      -- Move the unit towards the goal point
      entity:MoveToPosition(entity:GetInitialGoalPosition())
    end
  end
end


-- Returns the number of heroes and controllable clones (but not illusions) among units in the list
function GetHeroAndCloneCount(units)
  local count = 0

  for _, entity in pairs(units) do
    -- Monkey King clones are excluded because they are not controllable
    if entity:IsHero() and (not entity:IsIllusion()) and (not IsMonkeyKingClone(entity)) then
      count = count + 1
    end
  end

  return count
end


-- Returns whether the NPC can cast the ability
-- If `target` is specified, whether it is targetable by the ability is also considered
function CanCastAbility(npc, ability, target)
  if IsFeared(npc) then
    return false
  end

  local pierces_spell_immune = 0 < bit.band(
    ability:GetAbilityTargetFlags(),
    DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES
  )
  local ignores_stuns = 0 < bit.band(
    ability:GetBehavior(),
    DOTA_ABILITY_BEHAVIOR_IGNORE_PSEUDO_QUEUE
  )

  -- The target may not be targeted if it is spell immune, unless the ability pierces spell immunity
  local can_target = (not target) or ((not target:IsMagicImmune()) or pierces_spell_immune)
  local npc_can_cast = (npc:GetMana() >= ability:GetManaCost(-1))
    -- The NPC cannot cast the ability if stunned, unless the ability may be used while stunned
    and ((not IsStunnedBypassable(npc)) or ignores_stuns)
  local ability_castable = false

  if ability:IsItem() then
    npc_can_cast = npc_can_cast and not npc:IsMuted()
    -- The item's state is checked to see whether it is in the backpack or on backpack cd
    ability_castable = (ability:GetCooldownTimeRemaining() == 0) and (ability:GetItemState() == 1)
  else
    npc_can_cast = npc_can_cast and not npc:IsSilenced()
    ability_castable = ability:GetCooldownTimeRemaining() == 0
  end

  return can_target and npc_can_cast and ability_castable
end


-- Returns whether the NPC has a powerful buff whose duration can be easily waited out by retreating
function HasPowerfulStallableBuff(npc)
  local stallable_buffs = {
    ["modifier_item_blade_mail_reflect"] = true,
    ["modifier_black_king_bar_immune"] = true,
    ["modifier_life_stealer_rage"] = true,
    ["modifier_luna_eclipse"] = true,
    ["modifier_medusa_stone_gaze"] = true,
    ["modifier_ursa_enrage"] = true,
    ["modifier_troll_warlord_battle_trance"] = true,
    ["modifier_crystal_maiden_freezing_field"] = true,
  }

  for _, modifier in pairs(npc:FindAllModifiers()) do
    if stallable_buffs[modifier:GetName()] then
      return true
    end
  end

  return false
end


-- Returns whether the NPC is casting a spell or attacking a target
function IsBusy(npc)
  -- Only consider the NPC to be attacking if its attack cooldown is ready
  local is_attacking = npc:IsAttacking() and (npc:TimeUntilNextAttack() < 0.01)
  local is_channeling = npc:IsChanneling()
  local is_casting = false

  local ability = npc:GetCurrentActiveAbility()

  if ability then
    -- NOTE: Using `IsInAbilityPhase` here results in the bot canceling its own actions because it
    --       does not consider turning to cast an ability to be busy
    is_casting = true
  end

  return is_attacking or is_channeling or is_casting
end


-- Returns whether `bot_unit` should follow the orders of `other_unit` instead of making its own
-- decisions in cases where there might be a loop when doing so (e.g., when choosing an attack
-- target based on an ally's attack target)
function ShouldFollowOrders(bot_unit, other_unit)
  local bot_id = bot_unit:GetPlayerOwnerID()
  local other_id = other_unit:GetPlayerOwnerID()

  -- Always follow player-controlled units, and enforce a strict ordering for bots to resolve
  -- bot-bot coordination conflicts
  return (bot_unit ~= other_unit) and ((not IsBot(bot_id)) or (bot_id >= other_id))
end


-- Returns whether the NPC has the given modifier and will continue to have it for at least
-- `duration` seconds
function HasBuffForDuration(npc, modifier_name, duration)
  local modifier = npc:FindModifierByName(modifier_name)

  return (modifier ~= nil) and (modifier:GetRemainingTime() > duration)
end


-- Returns whether the NPC currently has the Aeon Disk buff
function HasAeonDiskBuff(npc)
  return npc:HasModifier("modifier_item_aeon_disk_buff")
end


-- Returns whether the NPC may have an Aeon Disk proc available or active, in which case dispellable
-- debuffs should not be placed on them until it procs/expires
function IsAeonDiskRisk(npc)
  local aeon_disk = npc:FindItemInInventory("item_aeon_disk")
  local threshold = aeon_disk and aeon_disk:GetSpecialValueFor("health_threshold_pct")

  return HasAeonDiskBuff(npc) or (aeon_disk and (npc:GetHealthPercent() >= threshold))
end


-- Returns whether `target` is within the attack range of `attacker`
function IsInAttackRange(attacker, target)
  -- Units have a small bonus to attack range that seems to be based on their hull radius
  return attacker:GetRangeToUnit(target)
    < (attacker:Script_GetAttackRange() + attacker:GetHullRadius())
end


-- Returns whether the NPC currently has the blademail buff
function HasBladeMailActive(npc)
  return npc and npc:HasModifier("modifier_item_blade_mail_reflect")
end
