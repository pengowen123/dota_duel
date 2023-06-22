function OnStartTouch(keys)
	local activator = keys.activator
	local name = activator:GetName()
	local classname = activator:GetClassname()

	local announcer_classnames = {
		["npc_dota_hero_announcer"] = true,
		["npc_dota_hero_announcer_killing_spree"] = true,
	}

	-- Killing announcer entities breaks the announcer
	if announcer_classnames[classname] then
		return
	end

	if classname == "npc_dota_thinker" then
		for i, modifier in pairs(activator:FindAllModifiers()) do
			local modifier_name = modifier:GetName()

			-- Thinker modifiers that just have to be `Destroy`ed
			local simple_destroy = {
				["modifier_slardar_puddle_thinker"] = true,
				["modifier_item_gem_of_true_sight"] = true,
				["modifier_tinker_march_thinker"] = true,
				["modifier_ancient_apparition_ice_vortex_custom_thinker"] = true,
				["modifier_kunkka_ghost_ship_fleet"] = true,
				["modifier_kunkka_torrent_thinker"] = true,
				["modifier_kunkka_torrent_storm"] = true,
				["modifier_leshrac_split_earth_thinker"] = true,
				["modifier_disruptor_static_storm_thinker"] = true,
				["modifier_item_dustofappearance_thinker"] = true,
				["modifier_gem_active_truesight"] = true,
				-- Vision persists for this, but it's difficult to fix
				["modifier_sniper_shrapnel_thinker"] = true,
			}

			if simple_destroy[modifier_name] then
				modifier:Destroy()
				return
			elseif modifier_name == "modifier_arc_warden_scepter" then
				modifier:StartIntervalThink(1.0)
				return
			elseif modifier_name == "modifier_arc_warden_spark_wraith_thinker" then
				local creep = CreateUnitByName(
					"npc_dota_creep_badguys_melee",
					activator:GetAbsOrigin() + Vector(1, 1, 0),
					false,
					nil,
					nil,
					DOTA_TEAM_NEUTRALS
				)

				Timers:CreateTimer(0.25, function()
					creep:Kill(nil, creep)

					-- This doesn't remove the vision but at least removes the spark wraiths visually to avoid confusion
					for i, thinker in pairs(Entities:FindAllByClassname("npc_dota_thinker")) do
						local modifier = thinker:FindModifierByName("modifier_arc_warden_spark_wraith_thinker")

						if modifier then
							modifier:Destroy()
						end
					end
				end)
				return
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

		-- Monkey king clones must not be killed
		return
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

	-- ET spirit must not be destroyed or the ability will not work anymore
	if classname == "npc_dota_elder_titan_ancestral_spirit" then
		local owner = activator:GetOwner()

		if owner then
			FindClearSpaceForUnit(activator, owner:GetAbsOrigin(), false)
		end

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

	-- Don't kill the fountain, shop, or neutral item stash
	if activator:IsBuilding() then
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
