"use strict";


var client_team = Players.GetTeam(Players.GetLocalPlayer());
var is_spectator_client = !(client_team === DOTATeam_t.DOTA_TEAM_GOODGUYS ||
													  client_team === DOTATeam_t.DOTA_TEAM_BADGUYS);


function Initialize()
{
  GameEvents.Subscribe("server_message", PrintServerMessage);
}


function PrintServerMessage(args)
{
  $.Msg(args.text);
}


Initialize();