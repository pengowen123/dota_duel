neutral_items = {
	["item_keen_optic"] = true,
	["item_royal_jelly"] = true,
	["item_poor_mans_shield"] = true,
	["item_ocean_heart"] = true,
	["item_iron_talon"] = true,
	["item_mango_tree"] = true,
	["item_arcane_ring"] = true,
	-- sic
	["item_elixer"] = true,
	["item_broom_handle"] = true,
	["item_ironwood_tree"] = true,
	["item_trusty_shovel"] = true,
	["item_faded_broach"] = true,
	["item_grove_bow"] = true,
	["item_vampire_fangs"] = true,
	["item_ring_of_aquila"] = true,
	["item_repair_kit"] = true,
	["item_pupils_gift"] = true,
	["item_helm_of_the_undying"] = true,
	["item_imp_claw"] = true,
	["item_philosophers_stone"] = true,
	["item_dragon_scale"] = true,
	["item_essence_ring"] = true,
	["item_nether_shawl"] = true,
	["item_tome_of_aghanim"] = true,
	["item_craggy_coat"] = true,
	["item_greater_faerie_fire"] = true,
	["item_quickening_charm"] = true,
	["item_mind_breaker"] = true,
	["item_third_eye"] = true,
	["item_spider_legs"] = true,
	["item_vambrace"] = true,
	["item_clumsy_net"] = true,
	["item_enchanted_quiver"] = true,
	["item_paladin_sword"] = true,
	["item_orb_of_destruction"] = true,
	["item_titan_sliver"] = true,
	["item_witless_shako"] = true,
	["item_timeless_relic"] = true,
	["item_spell_prism"] = true,
	["item_princes_knife"] = true,
	["item_flicker"] = true,
	["item_spy_gadget"] = true,
	["item_ninja_gear"] = true,
	-- sic
	["item_illusionsts_cape"] = true,
	["item_havoc_hammer"] = true,
	["item_panic_button"] = true,
	["item_the_leveller"] = true,
	["item_minotaur_horn"] = true,
	["item_force_boots"] = true,
	["item_seer_stone"] = true,
	["item_mirror_shield"] = true,
	["item_fallen_sky"] = true,
	["item_fusion_rune"] = true,
	["item_apex"] = true,
	["item_ballista"] = true,
	["item_woodland_striders"] = true,
	["item_recipe_trident"] = true,
	["item_demonicon"] = true,
	["item_pirate_hat"] = true,
	["item_ex_machina"] = true,
	["item_desolator_2"] = true,
	["item_phoenix_ash"] = true,
}

local unsafe_classnames = {
	["npc_dota_elder_titan_ancestral_spirit"] = true,
}

function OnStartTouch(trigger)
	local activator = trigger.activator
	
	-- Only run on NPCs
	if activator == nil
		or not ((activator.IsSummoned and activator:IsSummoned())
						 or (activator.IsHero and activator:IsHero())
						 or (activator.IsConsideredHero and activator:IsConsideredHero())) then
		return
	end

	activator:RemoveModifierByName("leave_arena_modifier")
	activator:RemoveModifierByName("modifier_bear_disable")
end


function OnEndTouch(trigger)
	local activator = trigger.activator

	-- Only run on NPCs
	if activator == nil
		or unsafe_classnames[activator:GetClassname()]
		or not ((activator.IsSummoned and activator:IsSummoned())
						 or (activator.IsHero and activator:IsHero())
						 or (activator.IsConsideredHero and activator:IsConsideredHero())) then
		return
	end

	local data = { duration = 8.0 }

	activator:AddNewModifier(trigger.activator, nil, "leave_arena_modifier", data)
end