function OnStartTouch(trigger)
	local activator = trigger.activator
	
	-- Only run on NPCs
	if activator == nil or not activator.GetItemInSlot then
		return
	end

	activator:RemoveModifierByName("leave_arena_modifier")
	activator:RemoveModifierByName("modifier_bear_disable")
end


function OnEndTouch(trigger)
	local activator = trigger.activator

	-- Only run on NPCs
	if activator == nil or not activator.GetItemInSlot then
		return
	end

	local data = { duration = 8.0 }

	activator:AddNewModifier(trigger.activator, nil, "leave_arena_modifier", data)
end