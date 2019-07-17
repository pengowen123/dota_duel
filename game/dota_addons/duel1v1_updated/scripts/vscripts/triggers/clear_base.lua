function OnStartTouch(keys)
	local activator = keys.activator
	local name = activator:GetName()
	local classname = activator:GetClassname()

	if classname == "npc_dota_thinker" then
		for i, modifier in pairs(activator:FindAllModifiers()) do
			local modifier_name = modifier:GetName()

			if modifier_name == "modifier_arc_warden_scepter" then
				modifier:StartIntervalThink(1.0)
				return
			elseif modifier_name == "modifier_slardar_puddle_thinker" then
				modifier:Destroy()
				return
			elseif modifier_name == "modifier_item_gem_of_true_sight" then
				modifier:Destroy()
				return
			elseif modifier_name == "modifier_arc_warden_spark_wraith_thinker" then
				local enemy_team = DOTA_TEAM_GOODGUYS

				if activator:GetTeamNumber() == DOTA_TEAM_GOODGUYS then
					enemy_team = DOTA_TEAM_BADGUYS
				end

				local owner = nil

				for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
			    if PlayerResource:IsValidPlayerID(playerID) then
			      owner = PlayerResource:GetSelectedHeroEntity(playerID)
			    end
			  end

			  if owner then
					local creep = CreateUnitByName(
						"npc_dota_creep_badguys_melee",
						activator:GetAbsOrigin() + Vector(15, 15, 15),
						false,
						owner,
						owner,
						enemy_team)

					Timers:CreateTimer(0.25, function()
						creep:Kill(nil, creep)
					end)
					return
				end
			end
		end
	end

	if name == "npc_dota_hero_monkey_king" then
		for i, modifier in pairs(activator:FindAllModifiers()) do
			local modifier_name = modifier:GetName()
			if modifier_name == "modifier_monkey_king_fur_army_soldier" or modifier_name == "modifier_monkey_king_fur_army_soldier_active" then
				modifier:Destroy()
				return
			end
		end
	end

	-- Spirit bears are useless in base because they are silenced and rooted, so the player is forced
	-- to resummon them even if they are not killed
	if name == "npc_dota_lone_druid_bear" then
		return
	end

	-- These are created to destroy spark wraiths and must not be killed here
	if name == "npc_dota_creep_lane" then
		return
	end

	-- Classnames of entities that must not be removed
	local unsafe_classnames = {
		["npc_dota_companion"] = true,
		["dota_death_prophet_exorcism_spirit"] = true,
		["npc_dota_wisp_spirit"] = true,
	}

	if unsafe_classnames[classname] then
		return
	end

	if name == "ent_dota_shop" then
		return
	end

	if name == "npc_dota_hero_arc_warden" then
		local is_tempest_double = false

		local modifiers = activator:FindAllModifiers()

	  for i, modifier in pairs(modifiers) do
	    if modifier:GetName() == "modifier_arc_warden_tempest_double" then
	    	is_tempest_double = true
	    end
    end

    if not is_tempest_double then
    	return
    end
	end

	if string.find(name, "npc_dota_hero") and name ~= "npc_dota_hero_arc_warden" and not activator:IsIllusion() then
		return
	elseif classname == "dota_item_drop" then
		-- To prevent reaching the items purchased limit
		local item = activator:GetContainedItem()

		if item then
			if item:GetAbilityName() ~= "item_gem" then
				item:Destroy()
				activator:Kill()
			end
		else
			activator:Kill()
		end
	elseif name == "npc_dota_creep_neutral" then
		-- Neutral creeps must be removed instead of killed, or new neutrals will not spawn
		-- because the camps still count as populated
		UTIL_Remove(activator)
	else
		-- Make the entity commit suicide
		activator:Kill(nil, activator)
	end
end

function OnEndTouch(keys)
end