-- Non-cheating illusion detection for the bots


-- A map of each visible, living NPC to its non-illusion confidence score from its enemies'
-- perspective (see `GetNonIllusionConfidence`)
-- NPCs are only registered in this table when information is gathered about them or
-- `GetNonIllusionConfidence` is called on them, and are unregistered upon the enemy team losing
-- vision of them
non_illusion_scores = {}
-- The number of NPCs currently in `non_illusion_scores` on each team
non_illusion_scores_length = {
  [DOTA_TEAM_GOODGUYS] = 0,
  [DOTA_TEAM_BADGUYS] = 0,
}

-- Whether each team has the ability to create illusions of heroes other than themselves (e.g., with
-- shadow demon disruption)
can_create_nonself_illusions = {
  [DOTA_TEAM_GOODGUYS] = false,
  [DOTA_TEAM_BADGUYS] = false,
}

-- Heroes capable of creating illusions of heroes other than themselves
nonself_illusion_heroes = {
  ["npc_dota_hero_chaos_knight"] = true,
  ["npc_dota_hero_dark_seer"] = true,
  ["npc_dota_hero_grimstroke"] = true,
  ["npc_dota_hero_morphling"] = true,
  ["npc_dota_hero_shadow_demon"] = true,
}

-- Heroes capable of creating illusions of themselves
illusion_heroes = {
  ["npc_dota_hero_anti_mage"] = true,
  ["npc_dota_hero_bane"] = true,
  ["npc_dota_hero_chaos_knight"] = true,
  ["npc_dota_hero_grimstroke"] = true,
  ["npc_dota_hero_hoodwink"] = true,
  ["npc_dota_hero_morphling"] = true,
  ["npc_dota_hero_naga_siren"] = true,
  ["npc_dota_hero_phantom_lancer"] = true,
  ["npc_dota_hero_rubick"] = true,
  ["npc_dota_hero_shadow_demon"] = true,
  ["npc_dota_hero_spectre"] = true,
  ["npc_dota_hero_terrorblade"] = true,
  ["npc_dota_hero_vengefulspirit"] = true,
}

-- Items capable of creating illusions
illusion_items = {
  ["item_manta"] = true,
  ["item_illusionsts_cape"] = true,
}

-- Modifiers for illusions that are visible to enemies
visible_illusion_modifiers = {
  ["modifier_terrorblade_conjureimage"] = true,
  ["modifier_vengefulspirit_hybrid_special"] = true,
  ["modifier_darkseer_wallofreplica_illusion"] = true,
  ["modifier_darkseer_normal_punch_illusion"] = true,
  ["modifier_grimstroke_scepter_buff"] = true,
}

-- Heroes whose illusions replicate ability cast animations, obfuscating which unit is the real hero
obfuscated_illusion_cast_heroes = {
  ["npc_dota_hero_chaos_knight"] = true,
  ["npc_dota_hero_phantom_lancer"] = true,
}

-- Abilities that do not reveal the caster as a real hero when used
non_revealing_abilities = {
  ["chaos_knight_phantasm"] = true,
  ["naga_siren_ensnare"] = true,
  ["naga_siren_mirror_image"] = true,
  ["sniper_take_aim"] = true,
  ["terrorblade_metamorphosis"] = true,
}

-- Items that reveal the caster as a real hero when used
revealing_items = {
  ["item_blink"] = true,
  ["item_arcane_blink"] = true,
  ["item_overwhelming_blink"] = true,
  ["item_swift_blink"] = true,
}

-- Modifiers that reveal the parent NPC as a real hero
revealing_modifiers = {
  ["modifier_black_king_bar_immune"] = true,
  ["modifier_item_satanic_unholy"] = true,
  ["modifier_item_silver_edge_windwalk"] = true,
  ["modifier_item_invisibility_edge_windwalk"] = true,
  ["modifier_abaddon_borrowed_time"] = true,
}

-- Abilities that cause all information about the caster to be lost
unrevealing_abilities = {
  ["chaos_knight_phantasm"] = true,
  ["item_manta"] = true,
  ["naga_siren_mirror_image"] = true,
}


-- Resets entity illusion data
-- Should be called between each round
function ResetIllusionData()
  non_illusion_scores = {}
  non_illusion_scores_length[DOTA_TEAM_GOODGUYS] = 0
  non_illusion_scores_length[DOTA_TEAM_BADGUYS] = 0
end


-- Initializes the illusion data updater that regularly updates the illusion data
function InitializeIllusionDataUpdater()
  local update = function()
    UpdateIllusionData()

    return ILLUSION_DATA_UPDATE_INTERVAL
  end

  local args = {
    endTime = 1.0,
    callback = update,
  }

  Timers:RemoveTimer("illusion_data_update")
  Timers:CreateTimer("illusion_data_update", args)
end


-- Updates the illusion data, cleaning up dead or invalid entities and updating non-illusion
-- confidence scores based on current observations
-- Should be called frequently
function UpdateIllusionData()
  local num_radiant = 0
  local num_dire = 0

  for k, v in pairs(non_illusion_scores) do
    -- Invalid units are removed, and if a unit becomes non-visible, all information about it is lost
    if (not IsValidUnit(k)) or (not IsVisible(k)) or IsOutOfGameNonVisibly(k) then
      -- Clean up dead/deleted/non-visible entities
      non_illusion_scores[k] = nil
    else
      -- Check whether the entity's state reveals any information
      CheckRevealingState(k)

      local team = k:GetTeam()

      -- Count the number of entities in the data on each team
      if team == DOTA_TEAM_GOODGUYS then
        num_radiant = num_radiant + 1
      elseif team == DOTA_TEAM_BADGUYS then
        num_dire = num_dire + 1
      end
    end
  end

  non_illusion_scores_length[DOTA_TEAM_GOODGUYS] = num_radiant
  non_illusion_scores_length[DOTA_TEAM_BADGUYS] = num_dire
end


-- Returns whether the NPC is out of the game in a non-visible way (e.g., doppelganger)
-- This does not include when the NPC is in astral imprisonment, for example, because its position
-- is still fully visible
function IsOutOfGameNonVisibly(npc)
  return npc:HasModifier("modifier_phantomlancer_dopplewalk_phase")
end


-- Checks whether the NPC's current state (e.g., modifiers, channeling status) reveals it as a real
-- hero or illusion
function CheckRevealingState(npc)
  -- Channeling can only be done by real heroes
  if npc:IsChanneling() then
    if npc:IsIllusion() then
      -- Hoodwink and bane illusions are the exceptions, but they are effectively visible
      -- illusions anyways
      non_illusion_scores[npc] = 0.0
    else
      non_illusion_scores[npc] = 1.0
    end
  end

  -- Check for any revealing modifiers on the entity
  for _, modifier in pairs(npc:FindAllModifiers()) do
    if revealing_modifiers[modifier:GetName()] then
      non_illusion_scores[npc] = 1.0
    end
  end
end


-- Updates the per-team illusion creation capability table
-- Should be called at the beginning of each match or rematch, after all heroes have loaded
function CheckTeamIllusionCapabilities()
  can_create_nonself_illusions[DOTA_TEAM_GOODGUYS] = false
  can_create_nonself_illusions[DOTA_TEAM_BADGUYS] = false

  for hero, _ in pairs(GetHeroNames(DOTA_TEAM_GOODGUYS)) do
    if nonself_illusion_heroes[hero] then
      can_create_nonself_illusions[DOTA_TEAM_GOODGUYS] = true
      break
    end
  end

  for hero, _ in pairs(GetHeroNames(DOTA_TEAM_BADGUYS)) do
    if nonself_illusion_heroes[hero] then
      can_create_nonself_illusions[DOTA_TEAM_BADGUYS] = true
      break
    end
  end
end


-- Returns whether it is possible for the NPC to be an illusion
function CanBeIllusion(npc)
  -- Only entities considered to be heroes can create illusions
  if not npc:IsHero() then
    return false
  end

  -- Check if the NPC itself or an ally can create illusions of it
  if can_create_nonself_illusions[npc:GetTeam()] or illusion_heroes[npc:GetName()] then
    return true
  end

  -- Check if the NPC has an item that can create illusions
  -- Backpack slots must be checked as well because manta style can be swapped into the backpack
  -- during the transformation time, removing it from the illusions' inventories
  -- TODO: abstract this kind of loop out (rg "0, 1, 2")
  for _, i in pairs({ 0, 1, 2, 3, 4, 5, 6, 7, 8, NEUTRAL_ITEM_SLOT }) do
    local item = npc:GetItemInSlot(i)

    if item and illusion_items[item:GetName()] then
      return true
    end
  end

  return false
end


-- Returns whether the NPC is an illusion that is visible to enemies (e.g., wall of replica illusions)
function IsVisibleIllusion(npc)
  if not npc:IsIllusion() then
    return false
  end

  for _, modifier in pairs(npc:FindAllModifiers()) do
    if visible_illusion_modifiers[modifier:GetName()] then
      return true
    end
  end

  return false
end


-- Returns the initial non-illusion confidence score for the NPC from its enemies' perspective
-- (see `GetNonIllusionConfidence`)
-- This is only the initial value for newly-observed NPCs; this value is later updated in the
-- illusion data
function GetInitialNonIllusionConfidence(npc)
  if not CanBeIllusion(npc) then
    -- If it's impossible for the NPC to be an illusion, the confidence score is 1
    return 1.0
  elseif IsVisibleIllusion(npc) then
    -- If the NPC is a visible illusion, the confidence score is 0
    return 0.0
  else
    -- Otherwise, only a slight confidence can be had that the NPC is not an illusion
    return 0.25
  end
end


-- Returns the current non-illusion confidence score for the NPC from its enemies' perspective
-- A score of 0 means the NPC is an illusion, a score of 1 means the NPC is not an illusion, and
-- scores in between indicate varying levels of confidence that the NPC is not an illusion
-- Also registers the NPC in the illusion data if not already registered
function GetNonIllusionConfidence(npc)
  -- If no score has been recorded for the NPC, compute its initial score
  if not non_illusion_scores[npc] then
    non_illusion_scores[npc] = GetInitialNonIllusionConfidence(npc)
  end

  return non_illusion_scores[npc]
end


-- Returns whether the non-illusion confidence score for the NPC is either 0 or 1 from its enemies'
-- perspective, which indicates that it is absolute and will not change
function IsNonIllusionConfidenceAbsolute(score)
  return (score == 0.0) or (score == 1.0)
end


-- Returns whether the NPC is likely to not be an illusion from its enemies' perspective, as
-- defined by `LIKELY_NON_ILLUSION_THRESHOLD`
function IsLikelyNonIllusion(npc)
  return GetNonIllusionConfidence(npc) >= LIKELY_NON_ILLUSION_THRESHOLD
end


-- Called when an ability is used
-- Checks whether the ability cast is revealing and updates the illusion data for the caster
-- appropriately
function IllusionsOnAbilityUsed(caster, ability)
  -- Only consider abilities cast by visible heroes
  if caster:IsHero() and IsVisible(caster) then
    -- The only illusions that can cast abilities are those from hoodwink, bane, and vengeful
    -- spirit, which are effectively visible illusions anyways
    if caster:IsIllusion() then
      non_illusion_scores[caster] = 0.0
    else
      local name = ability:GetAbilityName()

      -- Certain abilities cause all information about the caster to be lost
      if unrevealing_abilities[name] then
        non_illusion_scores[caster] = nil
        return
      end

      if ability:IsItem() then
        -- Only certain items are considered revealing
        if revealing_items[name] then
          non_illusion_scores[caster] = 1.0
        end
      elseif not (obfuscated_illusion_cast_heroes[caster:GetName()]
          -- Ability casts can only be obfuscated if there is more than one unit
          and non_illusion_scores_length[caster:GetTeam()] > 1)
        and not non_revealing_abilities[name]
      then
        -- If the hero's illusions don't replicate ability cast animations and the ability is not an
        -- exception, consider the ability cast to be revealing
        non_illusion_scores[caster] = 1.0
      end
    end
  end
end


-- Called when an NPC is hurt
-- Compares the damage taken to the expected damage taken and updates the illusion data for the hurt
-- NPC or attacker appropriately
function IllusionsOnNPCHurt(hurt, attacker, damage, source_ability)
  -- Only consider damage instances on visible, non-neutral units
  if IsValidUnit(hurt)
    and IsVisible(hurt)
    and not (attacker:GetTeam() == DOTA_TEAM_NEUTRALS)
    and not (hurt:GetTeam() == DOTA_TEAM_NEUTRALS)
  then
    local is_auto_attack = source_ability == nil
    -- The ratio of the actual damage to the expected damage
    local damage_ratio = 1.0

    if is_auto_attack then
      -- NOTE: This doesn't account for magic damage in auto attacks, but it shouldn't be that big
      -- of an issue
      local actual = damage / GetPhysicalDamageMultiplierForNPC(hurt)
      local expected = attacker:GetAverageTrueAttackDamage(nil)

      -- Ignore when the attacker has zero damage
      if expected > 0 then
        damage_ratio = actual / expected
      end
    elseif source_ability:GetAbilityName() == "item_mjollnir" then
      -- No abilities other than mjollnir are considered because doing so in a general way appears
      -- to be impossible, and mjollnir is the most important ability for illusion detection anyways
      local actual = damage / GetMagicDamageMultiplierForNPC(hurt)
      -- Static charge is also detected as mjollnir, but the damage is not much higher, so it is
      -- not handled differently
      local expected = source_ability:GetSpecialValueFor("chain_damage")
      damage_ratio = actual / expected
    else
      return
    end

    -- Daedalus increases the max normal damage ratio
    -- Other crit abilities aren't considered because their proc chance is generally low
    local has_daedalus = false
    for i=0,5 do
      local item = attacker:GetItemInSlot(i)

      if item and item:GetName() == "item_greater_crit" then
        has_daedalus = true
        break
      end
    end

    -- Check whether the damage taken was suspiciously high (evidence that the hurt NPC is an
    -- illusion), suspiciously low (evidence that the attacker is an illusion), or within normal
    -- ranges (evidence that both the hurt NPC and attacker are non-illusions)
    -- NOTE: This mishandles refraction and similar damage shields, but it shouldn't be that big
    --       of an issue
    if damage_ratio > 1.9 then
      -- Require a higher damage ratio if the attacker has daedalus
      -- No score adjustments occur in the ambiguous case where the attacker has a daedalus and the
      -- damage ratio is only moderately high
      if (not has_daedalus) or (damage_ratio > 4.0) then
        DecreaseNonIllusionConfidence(hurt, damage_ratio)
      end
    elseif damage_ratio < 0.5 then
      -- The attacker's damage reveals some information, but only if there aren't too many units
      -- attacking (approximated by the number of visible units), as if there are too many units,
      -- each individual attack is hard to tell apart from the others
      if (non_illusion_scores_length[attacker:GetTeam()] <= 2) then
        DecreaseNonIllusionConfidence(attacker, 2 / (0.1 + damage_ratio))
      end
    else
      -- NOTE: More accurate information could be gathered by checking if both the attacker and hurt
      --       NPC are illusions by using the fact that they are visible to their own teams, but this is
      --       not done for now
      IncreaseNonIllusionConfidence(attacker, 4.0)
      IncreaseNonIllusionConfidence(hurt, 4.0)
    end
  end
end


-- Decreases the non-illusion confidence score for the NPC by an amount determined by `severity`
-- A higher severity value results in a larger decrease
function DecreaseNonIllusionConfidence(npc, severity)
  -- Only update scores of heroes (non-heroes have absolute scores anyways)
  if not npc:IsHero() then
    return
  end

  local score = GetNonIllusionConfidence(npc)

  if not IsNonIllusionConfidenceAbsolute(score) then
    -- Make the distance of the score from zero `severity` times smaller
    local difference = score
    local change = difference * (1 - 1 / severity)

    non_illusion_scores[npc] = score - change
  end
end


-- Increases the non-illusion confidence score for the NPC by an amount determined by `severity`
-- A higher severity value results in a larger increase
function IncreaseNonIllusionConfidence(npc, severity)
  -- Only update scores of heroes (non-heroes have absolute scores anyways)
  if not npc:IsHero() then
    return
  end

  local score = GetNonIllusionConfidence(npc)

  if not IsNonIllusionConfidenceAbsolute(score) then
    -- Make the distance of the score from one `severity` times smaller
    local difference = 1 - score
    local change = difference * (1 - 1 / severity)

    non_illusion_scores[npc] = score + change
  end
end
