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