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
	  	["npc_dota_neutral_forest_troll_high_priest"] = 1,
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
	  	["npc_dota_neutral_prowler_acolyte"] = 2,
	  	["npc_dota_neutral_prowler_shaman"] = 1,
		},
	}
}


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
  local chosen_variant = math.random(0, variant_count - 1)
  local creeps = camp_info[chosen_variant]

  for name, count in pairs(creeps) do
  	for i = 0, count - 1 do
	  	CreateUnitByName(name, origin, true, nil, nil, DOTA_TEAM_NEUTRALS)
	  end
  end
end


-- Returns whether neutrals exist in the provided camp
function IsPopulated(camp)
  local origin = camp:GetOrigin()
  local camp_radius = 300.0

  local entity = Entities:FindByClassnameWithin(nil, "npc_dota_creep_neutral", origin, camp_radius)

  if entity then
    return true
  end

  return false
end