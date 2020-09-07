unsafe_classnames = {
	["dota_death_prophet_exorcism_spirit"] = true,
	["dota_item_drop"] = true,
}

function OnStartTouch(trigger)
	local activator = trigger.activator

	if activator == nil or unsafe_classnames[activator:GetClassname()] ~= nil then
		return
	end

	if not ((activator.IsSummoned and activator:IsSummoned())
						 or (activator.IsHero and activator:IsHero())) then
		return
	end

	local name = activator:GetName()

	if name == "npc_dota_hero_monkey_king" then
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
	elseif name == "npc_dota_hero_lone_druid" then
		Timers:CreateTimer(0.5, function()
			if activator:GetAbilityByIndex(0):GetLevel() >= 3 then
				-- Lone Druid is silenced in the fountain to prevent bugs with the transformation period of his
				-- ultimate, so this summons the bear automatically
				activator:GetAbilityByIndex(0):CastAbility()
			else
				return 0.5
			end
		end)
	end

	activator:AddNewModifier(activator, nil, "modifier_stun", {})
end

function OnEndTouch(trigger)
end