"use strict";


var client_team = Players.GetTeam(Players.GetLocalPlayer());
var is_spectator_client = !(client_team === DOTATeam_t.DOTA_TEAM_GOODGUYS ||
													  client_team === DOTATeam_t.DOTA_TEAM_BADGUYS);


function Initialize()
{
	GameEvents.Subscribe("center_camera", CenterCamera);
}


function CenterCamera()
{
	var player = Players.GetLocalPlayer();
	var player_hero = Players.GetPlayerHeroEntityIndex(player);

	if (!is_spectator_client && player_hero !== -1)
	{
		GameUI.MoveCameraToEntity(player_hero);
	}
}

Initialize();
