"use strict";


var READY_UP_IMAGE_URL = "file://{resources}/images/custom_game/ready/checkmark.png";
var client_team = Players.GetTeam(Players.GetLocalPlayer());
var is_spectator_client = !(client_team === DOTATeam_t.DOTA_TEAM_GOODGUYS ||
													  client_team === DOTATeam_t.DOTA_TEAM_BADGUYS);


// Initializes the ready-up UI and logic
function Initialize()
{
	// Create a PlayerReady element for each player in the game
	var maxPlayers = Players.GetMaxPlayers();

	for (var id = maxPlayers; id >= 0; id--)
	{
		if (Players.IsValidPlayerID(id))
		{
			var team = Players.GetTeam(id);
			if (team === DOTATeam_t.DOTA_TEAM_GOODGUYS || team === DOTATeam_t.DOTA_TEAM_BADGUYS)
			{
				AddPlayer(id);
			}
		}
	}

	GameEvents.Subscribe("player_ready_lua", OnReadyUp);
	GameEvents.Subscribe("timer_update", TimerUpdate);
	GameEvents.Subscribe("start_round", StartRound);
	GameEvents.Subscribe("start_game", EndRound);
	GameEvents.Subscribe("end_round", EndRound);
	GameEvents.Subscribe("end_game", EndGame);
	GameEvents.Subscribe("end_game", EndGame);
	GameEvents.Subscribe("all_voted_rematch", AllVotedRematch);

	EnableReadyUpPanel(false);
}


// Creates a PlayerReady element
// PlayerReady contains the name of the provided player and a checkbox to show whether
// they have readied up
function AddPlayer(id)
{
	var name = Players.GetPlayerName(id);
	var panel = $.CreatePanel("Panel", $("#Players"), id.toString());
	panel.SetHasClass("PlayerReady", true);
	panel.BLoadLayoutSnippet("PlayerReady");
	var player_name = panel.GetChild(0).GetChild(0);
	player_name.text = name;
}


// Called when a player uses the ready up button
function ReadyUp()
{
	var id = Players.GetLocalPlayer();
	var data = { "id": id };

	// Disable the ready up button to prevent trolling (pressing it again will set the timer back to 3 seconds)
	EnableReadyUpButton(false);
	
 	GameEvents.SendCustomGameEventToServer("player_ready_js", data);
}


// Called when a player has readied up
function OnReadyUp(args)
{
	var id = args.id;
	SetReadyUpImage(id, READY_UP_IMAGE_URL);
}


// Sets the image source of the ready-up image for the player with the given id
function SetReadyUpImage(id, src)
{
	var player_panel = $("#" + id.toString());

	if (player_panel)
	{
		var image = player_panel.GetChild(1).GetChild(0).GetChild(0);
		image.SetImage(src);
	}
	else {
		AddPlayer(id);
		SetReadyUpImage(id, src);
	}
}


// Called when the round start timer updates
// Updates the number shown in the ready-up UI
function TimerUpdate(args)
{
	var timer = args.timer;
	var label = $("#ReadyLabel");
	label.SetDialogVariableInt("seconds", timer);
}


// Called when a round starts
// Hides the ready-up UI and centers the camera on the hero
function StartRound()
{
	EnableReadyUpPanel(false);
}


// Called when a round ends
// Shows the ready-up UI
function EndRound()
{
	var maxPlayers = Players.GetMaxPlayers()
	for (var id = maxPlayers; id >= 0; id--) {
		if (Players.IsValidPlayerID(id))
		{
			var team = Players.GetTeam(id);
			if (team === DOTATeam_t.DOTA_TEAM_GOODGUYS || team === DOTATeam_t.DOTA_TEAM_BADGUYS)
			{
				SetReadyUpImage(id, "");
			}
		}
	}

	EnableReadyUpPanel(true);

	if (!is_spectator_client)
	{
		EnableReadyUpButton(true);
	}
}


// Called when the game ends
// Hides the ready-up UI
function EndGame()
{
	EnableReadyUpPanel(false);
}


// Called when all players vote to rematch
function AllVotedRematch()
{
	EnableReadyUpPanel(false);
}


// Sets the ready-up panel's enabled and visible properties to the provided value
function EnableReadyUpPanel(enabled)
{
	var panel = $("#Ready");
	EnableElement(panel, enabled);
}


// Sets the ready-up button's enabled and visible properties to the provided value
function EnableReadyUpButton(enabled)
{
	var button = $("#ReadyButton");
	EnableElement(button, enabled);
}


// Sets the element's enabled and visible properties to the provided value
function EnableElement(element, enabled)
{
	element.enabled = enabled;
	element.visible = enabled;
}


Initialize();