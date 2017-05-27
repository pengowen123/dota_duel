function OnStartTouch(trigger)
	local activator = trigger.activator
	
	if activator == nil then
		return
	end

	activator:RemoveModifierByName("leave_arena_modifier")
end


function OnEndTouch(trigger)
	local activator = trigger.activator

	if activator == nil then
		return
	end

	local data = { duration = 8.0 }

	activator:AddNewModifier(trigger.activator, nil, "leave_arena_modifier", data)
end