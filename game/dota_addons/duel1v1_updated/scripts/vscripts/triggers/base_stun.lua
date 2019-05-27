unsafe_classnames = {
	["dota_death_prophet_exorcism_spirit"] = true,
	["dota_item_drop"] = true,
}

function OnStartTouch(trigger)
	local activator = trigger.activator

	if activator == nil or unsafe_classnames[activator:GetClassname()] ~= nil then
		return
	end

	if activator:GetName() == "npc_dota_hero_monkey_king" then
		for i, modifier in pairs(activator:FindAllModifiers()) do
			local name = modifier:GetName()

			local monkey_clone_modifiers = {
				["modifier_monkey_king_fur_army_soldier"] = true,
				["modifier_monkey_king_fur_army_soldier_hidden"] = true,
				["modifier_monkey_king_fur_army_soldier_active"] = true,
			}

			if monkey_clone_modifiers[name] then
				return
			end
		end
	end

	activator:AddNewModifier(activator, nil, "modifier_stun", {})
end

function OnEndTouch(trigger)
end