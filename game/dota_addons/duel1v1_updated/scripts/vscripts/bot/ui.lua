-- A listener for when a player adds a bot
function OnAddBot(event_source_index, args)
	EnableAddBotButton(false)

	local bot_hero_name = "npc_dota_hero_skeleton_king"
	Tutorial:AddBot("npc_dota_hero_abaddon", "", "", false)

	local replaced_hero = false
	local on_bot_created = function()
		local bot = nil
		local bot_id = nil
		local player = nil
		local player_id = nil

		-- Assign the above variables, waiting as needed for the bot heroes to load (first the default
		-- one added above, then the real one added so it can't be controlled by the player)
		for i, id in pairs(GetPlayerIDs()) do
			if IsBot(id) then
				bot_id = id

				if replaced_hero then
					bot = PlayerResource:GetSelectedHeroEntity(id)
				else
					local default_bot = PlayerResource:GetSelectedHeroEntity(id)

					if default_bot then
						replaced_hero = true
						PlayerResource:ReplaceHeroWith(id, bot_hero_name, 99999, 99999)
					end
				end
			else
				player = PlayerResource:GetPlayer(id)
				player_id = id
			end
		end

		-- If the bot hero hasn't loaded yet, check again in 1 second
		if not bot then
			return 1.0
		end

		ForceReadyUp(bot_id)

		-- This may not be necessary, but it doesn't hurt
		PlayerResource:SetUnitShareMaskForPlayer(bot_id, player_id, 1, false)
		PlayerResource:SetUnitShareMaskForPlayer(bot_id, player_id, 2, false)
		PlayerResource:SetUnitShareMaskForPlayer(bot_id, player_id, 4, false)

		LevelUpPlayers()

		local settings = {}

		global_bot_controller = BotController:New(bot_id, player_id, settings)
	end

	Timers:CreateTimer(0.1, on_bot_created)
end