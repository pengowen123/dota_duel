-- Controls the rematch system to let players play against each other again

require('utils')
require('hero_select_timer')


-- A listener for when a player selects a hero
function OnSelectHero(event_source_index, args)
	local id = args["id"]
	local hero_name = args["hero"]

	hero_select_data[id] = hero_name

	local data = {}
	data.id = id

	if AllSelectedHero() then
		-- Start the game after 3 seconds
		if hero_select_timer > 3 then
			SetHeroSelectTimer(3)
		end
	end
end


-- Initializes the hero select data
function InitHeroSelectData()
	hero_select_data = {}

	for i, id in pairs(GetPlayerIDs()) do
		hero_select_data[id] = nil
	end
end


-- Returns whether all players have selected a hero
function AllSelectedHero()
	for i, hero in pairs(hero_select_data) do
		if not hero then
			return false
		end
	end

	return true
end