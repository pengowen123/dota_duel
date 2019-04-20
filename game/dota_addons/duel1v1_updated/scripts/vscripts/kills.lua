-- Handling of the custom scoreboard system

kills = {}
-- For tracking changes to the builtin scoreboard in order to properly update the custom one
dota_kills = {}


-- Initializes the custom scoreboard
function InitKills()
	ResetKills()
	dota_kills.radiant = 0
	dota_kills.dire = 0
end


-- Reset the scoreboard so all players have 0 kills
function ResetKills()
	kills.radiant = 0
	kills.dire = 0

	CustomGameEventManager:Send_ServerToAllClients("score_update", kills)
end


-- Returns how many kills the radiant team has
function GetRadiantKills()
	return kills.radiant
end


-- Returns how many kills the dire team has
function GetDireKills()
	return kills.dire
end


-- Updates the custom scoreboard and its UI
function UpdateKills()
	local radiant_kills = PlayerResource:GetTeamKills(DOTA_TEAM_GOODGUYS)
	local dire_kills = PlayerResource:GetTeamKills(DOTA_TEAM_BADGUYS)

	local new_radiant_kills = radiant_kills - dota_kills.radiant
	local new_dire_kills = dire_kills - dota_kills.dire

	kills.radiant = kills.radiant + new_radiant_kills
	kills.dire = kills.dire + new_dire_kills

	dota_kills.radiant = radiant_kills
	dota_kills.dire = dire_kills

	CustomGameEventManager:Send_ServerToAllClients("score_update", kills)
end