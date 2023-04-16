-- Utilities related to the bots


-- String versions of modifier states used because `CheckStateToTable` uses string keys
MODIFIER_STATE_STUNNED_STR = tostring(MODIFIER_STATE_STUNNED)
MODIFIER_STATE_HEXED_STR = tostring(MODIFIER_STATE_HEXED)
MODIFIER_STATE_SILENCED_STR = tostring(MODIFIER_STATE_SILENCED)
MODIFIER_STATE_MUTED_STR = tostring(MODIFIER_STATE_MUTED)
MODIFIER_STATE_TAUNTED_STR = tostring(MODIFIER_STATE_TAUNTED)
MODIFIER_STATE_FEARED_STR = tostring(MODIFIER_STATE_FEARED)


-- Returns whether the entity is a valid unit to control or target, which means it must:
-- - exist,
-- - be alive,
-- - be an NPC,
-- - and not be a special unit such as Wisp spirits or Monkey King clones
function IsValidUnit(entity)
  return (entity ~= nil)
    and not entity:IsNull()
    and entity:IsAlive()
    and entity.IsHero
    and not entity:IsBuilding()
    -- Exclude special units such as Wisp spirits, Elder Titan's spirit, Underlord's portal, and
    -- Death Ward
    and not entity:IsUnselectable()
    and not (entity:IsInvulnerable() and not entity:HasAttackCapability())
    and not (entity:IsOther() and entity:NoHealthBar())
    -- Exclude invisible special units such as thinkers and announcers
    and (entity:GetModelName() ~= "models/development/invisiblebox.vmdl")
end


-- Returns whether the entity is visible to any other team
function IsVisible(entity)
  return entity.CanBeSeenByAnyOpposingTeam and entity:CanBeSeenByAnyOpposingTeam()
end


-- Returns whether the player is one of the custom bots
-- Returns false for players and for bots added with -createhero or other means
function IsRealBot(player_id)
  for _, c in pairs(global_bot_controllers) do
    if player_id == c.id then
      return true
    end
  end

  return false
end


-- Returns whether the NPC is taunted
function IsTaunted(npc)
  return npc:GetForceAttackTarget() ~= nil
end


-- Returns whether the NPC is feared
function IsFeared(npc)
  return npc:IsCommandRestricted()
end


-- Returns the maximum value of a table using a comparison function
-- If the table is empty or the function never returns true, the return value will be nil
function MaxBy(t, fn)
  local length = #t
  if length == 0 then
    return nil
  end

  local value = nil
  for i=1,length do
    if fn(value, t[i]) then
      value = t[i]
    end
  end

  return value
end


-- Interpolates from `a` to `b` by `amount` (0 to 1)
function Interpolate(a, b, amount)
  return a + ((b - a) * amount)
end


-- Returns a point that lies directly between vectors `a` and `b`, at `distance` units from `a`
function LerpToDistance(a, b, distance)
  local amount = distance / (b - a):Length2D()
  return a:Lerp(b, amount)
end


-- Returns the distance between `entity` and `point`
function DistanceToPoint(entity, point)
  return (entity:GetAbsOrigin() - point):Length2D()
end


-- Returns whether `a` is closer to `point` than `b`
-- Returns true if `b` is nil
function IsCloser(a, b, point)
    return (not b) or ((a - point):Length2D() < (b - point):Length2D())
end


-- Returns a set of the names of all heroes on `team` (keys are the names)
function GetHeroNames(team)
  local names = {}

  print("a")
  print(PlayerResource:GetSelectedHeroEntity(0))
  print(PlayerResource:GetSelectedHeroEntity(1))
  print(PlayerResource:GetPlayerName(0))
  print(PlayerResource:GetPlayerName(1))
  print("b")

  for _, id in pairs(GetPlayerIDs()) do
    if PlayerResource:GetTeam(id) == team then
      local hero = PlayerResource:GetSelectedHeroEntity(id)

      if hero then
        names[hero:GetName()] = true
      else
        print("hero not found for:", id)
      end
    end
  end

  return names
end


-- Returns a set of the names of all heroes on the team opposite to `team` (keys are the names)
function GetEnemyHeroNames(team)
  return GetHeroNames(GetOppositeTeam(team))
end


-- Returns whether the team opposite to `team` has the hero on it
function DoesEnemyTeamHaveHero(team, hero_name)
  for hero, _ in pairs(GetEnemyHeroNames(team)) do
    if hero == hero_name then
      return true
    end
  end

  return false
end


-- Returns whether there is a Disruptor on the team opposite to `team`
function DoesEnemyTeamHaveDisruptor(team)
  return DoesEnemyTeamHaveHero(team, "npc_dota_hero_disruptor")
end


-- Returns whether there is a hero with a bash stunlock on the team opposite to `team`
function DoesEnemyTeamHaveBashLock(team)
  return DoesEnemyTeamHaveHero(team, "npc_dota_hero_slardar")
    or DoesEnemyTeamHaveHero(team, "npc_dota_hero_faceless_void")
end


-- Returns the multiplier for physical damage taken given an armor value
function GetPhysicalDamageMultiplier(armor_value)
  local f = 0.06
  return 1 - ((f * armor_value) / (1.0 + f * math.abs(armor_value)))
end


-- Returns the multiplier for physical damage taken by the NPC
function GetPhysicalDamageMultiplierForNPC(npc)
  local armor = npc:GetPhysicalArmorValue(false)
  return GetPhysicalDamageMultiplier(armor)
end


-- Returns the multiplier for magic damage taken by the NPC
function GetMagicDamageMultiplierForNPC(npc)
  return 1 - npc:GetMagicalArmorValue()
end


-- Returns the multiplier for damage taken by the NPC, where the damage has the specified type
-- (one of `DAMAGE_TYPE_*`)
function GetDamageMultiplierForNPC(npc, damage_type)
  if damage_type == DAMAGE_TYPE_PHYSICAL then
    return GetPhysicalDamageMultiplierForNPC(npc)
  elseif damage_type == DAMAGE_TYPE_MAGICAL then
    return GetMagicDamageMultiplierForNPC(npc)
  else
    return 1.0
  end
end


-- Returns the cast range of the ability when cast by the NPC
function GetCastRange(npc, ability)
  return ability:GetEffectiveCastRange(npc:GetAbsOrigin(), npc)
end


-- Returns whether a random chance of `a` in `b` is successful
function RandomChance(a, b)
  return RandomInt(1, b) <= a
end


-- Returns whether any value of the table is equal to `element`
function Contains(t, element)
  if not t then
    return false
  end

  for _, v in pairs(t) do
    if v == element then
      return true
    end
  end

  return false
end


-- Returns the percentage of max health that the NPC is missing
function GetMissingHealthPercent(npc)
  return 100 - npc:GetHealthPercent()
end


-- Randomizes the order of the list and returns it
function RandomizeList(list)
  local randomized = {}

  while #list > 0 do
    -- Insert a random element into the list and remove it from the original
    local i = RandomInt(1, #list)

    table.insert(randomized, list[i])
    table.remove(list, i)
  end

  return randomized
end
