function OnStartTouch(trigger)
	local activator = trigger.activator

	if activator == nil or activator:GetClassname() == "dota_death_prophet_exorcism_spirit" then
		return
	end

	activator:AddNewModifier(activator, nil, "modifier_stun", {})
end

function OnEndTouch(trigger)
	local activator = trigger.activator

	if activator == nil or activator:GetClassname() == "dota_death_prophet_exorcism_spirit" then
		return
	end

	activator:RemoveModifierByName("modifier_stun")
end