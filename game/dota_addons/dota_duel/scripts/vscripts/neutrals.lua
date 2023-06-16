-- A custom implementation of the neutrals system


-- Constants

neutral_camp_info = {
  [0] = {
  	[0] = {
	  	["npc_dota_neutral_kobold"] = 3,
	  	["npc_dota_neutral_kobold_tunneler"] = 1,
	  	["npc_dota_neutral_kobold_taskmaster"] = 1,
		},
		[1] = {
	  	["npc_dota_neutral_forest_troll_berserker"] = 2,
	  	["npc_dota_neutral_forest_troll_high_priest"] = 1,
		},
		[2] = {
	  	["npc_dota_neutral_forest_troll_berserker"] = 2,
	  	["npc_dota_neutral_kobold_taskmaster"] = 1,
		},
		[3] = {
	  	["npc_dota_neutral_gnoll_assassin"] = 3,
		},
		[4] = {
	  	["npc_dota_neutral_fel_beast"] = 2,
	  	["npc_dota_neutral_ghost"] = 1,
		},
		[5] = {
	  	["npc_dota_neutral_harpy_scout"] = 2,
	  	["npc_dota_neutral_harpy_storm"] = 1,
		},
		[6] = {
	  	["npc_dota_neutral_centaur_outrunner"] = 1,
	  	["npc_dota_neutral_centaur_khan"] = 1,
		},
		[7] = {
	  	["npc_dota_neutral_giant_wolf"] = 2,
	  	["npc_dota_neutral_alpha_wolf"] = 1,
		},
		[8] = {
	  	["npc_dota_neutral_satyr_trickster"] = 2,
	  	["npc_dota_neutral_satyr_soulstealer"] = 2,
		},
		[9] = {
	  	["npc_dota_neutral_ogre_mauler"] = 2,
	  	["npc_dota_neutral_ogre_magi"] = 1,
		},
		[10] = {
	  	["npc_dota_neutral_mud_golem"] = 2,
		},
		[11] = {
	  	["npc_dota_neutral_centaur_outrunner"] = 2,
	  	["npc_dota_neutral_centaur_khan"] = 1,
		},
		[12] = {
	  	["npc_dota_neutral_satyr_trickster"] = 1,
	  	["npc_dota_neutral_satyr_soulstealer"] = 1,
	  	["npc_dota_neutral_satyr_hellcaller"] = 1,
		},
		[13] = {
	  	["npc_dota_neutral_polar_furbolg_champion"] = 1,
	  	["npc_dota_neutral_polar_furbolg_ursa_warrior"] = 1,
		},
		[14] = {
	  	["npc_dota_neutral_enraged_wildkin"] = 1,
	  	["npc_dota_neutral_wildkin"] = 2,
		},
		[15] = {
			["npc_dota_neutral_dark_troll"] = 2,
			["npc_dota_neutral_dark_troll_warlord"] = 1,
		},
		[16] = {
			["npc_dota_neutral_warpine_raider"] = 2,
		},
  },
  [1] = {
	  [0] = {
	  	["npc_dota_neutral_black_drake"] = 2,
	  	["npc_dota_neutral_black_dragon"] = 1,
		},
	  [1] = {
	  	["npc_dota_neutral_rock_golem"] = 2,
	  	["npc_dota_neutral_granite_golem"] = 1,
		},
	  [2] = {
	  	["npc_dota_neutral_small_thunder_lizard"] = 2,
	  	["npc_dota_neutral_big_thunder_lizard"] = 1,
		},
		[3] = {
			["npc_dota_neutral_frostbitten_golem"] = 2,
			["npc_dota_neutral_ice_shaman"] = 1,
		},
		-- [4] = {
		--  	["npc_dota_neutral_prowler_acolyte"] = 2,
		--  	["npc_dota_neutral_prowler_shaman"] = 1,
		-- },
	}
}

-- The maximum level that neutral creep abilities can reach without chen's bonus
-- All neutral creep abilities are permanently set to this level
MAX_NEUTRAL_CREEP_ABILITY_LEVEL = 3


-- Spawns neutrals at all neutral camps
function SpawnAllNeutrals()
  for i, camp in pairs(Entities:FindAllByName("neutral_camp")) do
    SpawnNeutrals(camp)
  end
end


-- Spawns neutrals at the provided camp if there are no neutrals already present
-- Neutrals will be spawned regardless of whether a player is in its radius
function SpawnNeutrals(camp)
  local camp_type = camp:Attribute_GetIntValue("camp_type", 0)
  local origin = camp:GetOrigin()

  if IsPopulated(camp) then
    return
  end

  local camp_info = neutral_camp_info[camp_type]
  local variant_count = #camp_info
  local chosen_variant = math.random(0, variant_count)
  local creeps = camp_info[chosen_variant]

  for name, count in pairs(creeps) do
		for i = 0, count - 1 do
			local unit = CreateUnitByName(name, origin, true, nil, nil, DOTA_TEAM_NEUTRALS)

			-- Force all creeps to have the maximum ability level, consistent with the late game in dota
			LevelNeutralAbilities(unit)
		end
  end
end


-- Returns whether neutrals exist in the provided camp
function IsPopulated(camp)
  local origin = camp:GetOrigin()
  local camp_radius = 300.0

  for i, entity in pairs(Entities:FindAllByClassnameWithin("npc_dota_creep_neutral", origin, camp_radius)) do
	  if entity and entity:IsAlive() then
	    return true
	  end
	end

  return false
end


-- Levels the neutral creep's abilities to the maximum level they can reach without chen's bonus
function LevelNeutralAbilities(npc)
	for i=0,25 do
		local ability = npc:GetAbilityByIndex(i)

		if ability then
			-- There doesn't seem to be a general way to detect the max level of these abilities, so a
			-- fixed value is used instead (the max level is currently constant, so this is fine for the
			-- moment)
			-- This also incorrectly increases the level of certain abilities that only have one level,
			-- but this doesn't seem to cause any issues
			ability:SetLevel(MAX_NEUTRAL_CREEP_ABILITY_LEVEL)
		end
	end
end
