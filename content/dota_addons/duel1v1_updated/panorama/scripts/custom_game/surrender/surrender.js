"use strict";


var client_team = Players.GetTeam(Players.GetLocalPlayer());
var is_spectator_client = !(client_team === DOTATeam_t.DOTA_TEAM_GOODGUYS ||
													  client_team === DOTATeam_t.DOTA_TEAM_BADGUYS);


function Initialize()
{
	GameEvents.Subscribe("enable_surrender", ResetForfeitUI);
	GameEvents.Subscribe("start_game", ResetForfeitUI);
	GameEvents.Subscribe("start_round", StartRound);
	GameEvents.Subscribe("end_round", EndRound);
	GameEvents.Subscribe("end_game", EndGame);
	GameEvents.Subscribe("all_voted_rematch", AllVotedRematch);

	HideForfeitUI();
}


function ResetForfeitUI()
{
	ToggleForfeitPopup(false);
	if (!is_spectator_client)
	{
		ToggleForfeitButton(true);
	}
}


// Disables the entire forfeit UI
function HideForfeitUI()
{
	ToggleForfeitPopup(false);
	ToggleForfeitButton(false);
}


function ShowPopup()
{
	ToggleForfeitPopup(true);
	ToggleForfeitButton(false);
}


function Surrender()
{
	var player_id = Players.GetLocalPlayer();
	var data = { "player_id": player_id };
	GameEvents.SendCustomGameEventToServer("player_surrender_js", data);
	HideForfeitUI();
}


function StartRound()
{
	HideForfeitUI();
}


function EndRound(args)
{
	if (args.enable_surrender)
	{
		ResetForfeitUI();
	}
	else
	{
		HideForfeitUI();
	}
}


function EndGame()
{
	HideForfeitUI();
}


// Called when all players vote to rematch
function AllVotedRematch()
{
	HideForfeitUI();
}


// Sets the forfeit flag on the top
function ToggleForfeitButton(state)
{
	var panel = $("#Surrender");
	ToggleElement(panel, state);
}


// Sets the forfeit pop-up on the screen
function ToggleForfeitPopup(state)
{
	var panel = $("#PopupHolder");
	ToggleElement(panel, state);
}


// Sets the element's enabled and visible properties to the provided value
function ToggleElement(element, enabled)
{
	element.enabled = enabled;
	element.visible = enabled;
}


Initialize();