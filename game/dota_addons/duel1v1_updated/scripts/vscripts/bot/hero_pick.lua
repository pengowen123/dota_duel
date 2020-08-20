-- Logic for the bot picking a hero and the creation of its hero entity

-- Selects a new hero for the bot to use. Requires that one already exists (usually created by
-- using Tutorial:AddBot).
--
-- `callback` will be given the new hero entity as an argument when it finishes loading
function SelectNewBotHero(hero_name, callback)
	bot_id = nil
	for i, id in pairs(GetPlayerIDs()) do
		if IsBot(id) then
			bot_id = id
			PlayerResource:ReplaceHeroWith(id, hero_name, 999999, 99999)
		end
	end

	-- Waits for the new hero to load, then calls the callback
	local check_new_hero = function()
		local bot_hero = PlayerResource:GetSelectedHeroEntity(bot_id)

		if bot_hero then
			callback(bot_hero)
		else
			return 0.5
		end
	end

	Timers:CreateTimer(0.1, check_new_hero)
end


-- Chooses a hero for the bot to play and returns the hero name
function MakeBotHeroChoice()
	local hero_pool = {
		"npc_dota_hero_skeleton_king",
		"npc_dota_hero_arc_warden"
	}
	local choice_index = RandomInt(1, #hero_pool)

	return hero_pool[1]
  -- return hero_pool[choice_index]
end