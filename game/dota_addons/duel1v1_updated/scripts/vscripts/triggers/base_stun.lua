unsafe_classnames = {
	["dota_death_prophet_exorcism_spirit"] = true,
	["dota_item_drop"] = true,
}

function OnStartTouch(trigger)
	local activator = trigger.activator

	if activator == nil or unsafe_classnames[activator:GetClassname()] ~= nil then
		return
	end

	activator:AddNewModifier(activator, nil, "modifier_stun", {})
end

function OnEndTouch(trigger)
	local activator = trigger.activator

	if activator == nil or unsafe_classnames[activator:GetClassname()] ~= nil then
		return
	end

	activator:RemoveModifierByName("modifier_stun")
end