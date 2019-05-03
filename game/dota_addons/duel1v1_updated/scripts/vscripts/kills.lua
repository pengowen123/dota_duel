-- Handling of the custom scoreboard system

kills = {}


-- Initializes the custom scoreboard
function InitKills()
	ResetKills()
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


-- Gives one kill to radiant
function AwardRadiantKill()
	kills.radiant = kills.radiant + 1

	CustomGameEventManager:Send_ServerToAllClients("score_update", kills)
end


-- Gives on kill to dire
function AwardDireKill()
	kills.dire = kills.dire + 1

	CustomGameEventManager:Send_ServerToAllClients("score_update", kills)
end