unsafe_classnames = {
	["dota_death_prophet_exorcism_spirit"] = true,
	["dota_item_drop"] = true,
	["npc_dota_elder_titan_ancestral_spirit"] = true,
}

function OnStartTouch(trigger)
	local activator = trigger.activator

	if activator == nil or unsafe_classnames[activator:GetClassname()] ~= nil then
		return
	end

	-- Only run on heroes
	if not ((activator.IsSummoned and activator:IsSummoned())
						 or (activator.IsHero and activator:IsHero())
						 or (activator.IsConsideredHero and activator:IsConsideredHero())) then
		return
	end

	-- Instantly kill players who TP to base (functions as a surrender)
	-- leave_arena_modifier would cause death 8 seconds later anyways but this makes it faster
	if game_state == GAME_STATE_FIGHT then
		-- Killing monkey king clones results in hundreds of them being spawned, crashing the game
		if not IsMonkeyKingClone(activator) then
			KillNPC(activator)
		end

		return
	end

	local name = activator:GetName()

	if IsMonkeyKingClone(activator) then
		-- The stun modifier shouldn't be added to Monkey King clones
		return
	elseif name == "npc_dota_hero_lone_druid" then
		Timers:CreateTimer(0.5, function()
			if activator:GetAbilityByIndex(0):GetLevel() >= 3 then
				-- Lone Druid is silenced in the fountain to prevent bugs with the transformation period of his
				-- ultimate, so this summons the bear automatically
				activator:GetAbilityByIndex(0):CastAbility()

				for i, bear in pairs(Entities:FindAllByName("npc_dota_lone_druid_bear")) do
					if bear:GetOwner() == activator then
						local tp_scroll = CreateAndConfigureItem("item_tpscroll", activator)
						tp_scroll:SetCurrentCharges(3)
						bear:AddItem(tp_scroll)

						-- Add modifier_stun in case the trigger doesn't add it (it is inconsistent sometimes)
						bear:AddNewModifier(bear, nil, "modifier_stun", {})

						-- Give the Spirit Bear the Moon Shard buff if it doesn't already have it
						if not bear:HasModifier("modifier_item_moon_shard_consumed") then
							local moon_shard = bear:AddItemByName("item_moon_shard")
							local player_index = 0
							bear:CastAbilityOnTarget(bear, moon_shard, player_index)
						end
					end
				end
			else
				return 0.5
			end
		end)
	end

	activator:AddNewModifier(activator, nil, "modifier_stun", {})
end

function OnEndTouch(trigger)
end