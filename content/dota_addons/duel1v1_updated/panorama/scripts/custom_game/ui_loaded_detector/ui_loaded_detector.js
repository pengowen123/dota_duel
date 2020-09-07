"use strict";


var client_team = Players.GetTeam(Players.GetLocalPlayer());
var is_spectator_client = !(client_team === DOTATeam_t.DOTA_TEAM_GOODGUYS ||
													  client_team === DOTATeam_t.DOTA_TEAM_BADGUYS);


function Initialize()
{
	if (!is_spectator_client)
	{
		var id = Players.GetLocalPlayer();
		var data = { "id": id };

		GameEvents.SendCustomGameEventToServer("player_ui_loaded", data);
	}
}

Initialize();