"use strict";


// Initializes the rematch UI and logic
function Initialize()
{
	GameEvents.Subscribe("start_game", StartGame);
	GameEvents.Subscribe("end_game", EndGame);
	GameEvents.Subscribe("player_vote_rematch_lua", OnVoteRematch);
	GameEvents.Subscribe("rematch_timer_update", TimerUpdate);
	GameEvents.Subscribe("all_voted_rematch", OnAllVotedRematch);

  // Create a PlayerRematch element for each player in the game
	var maxPlayers = Players.GetMaxPlayers();

	for (var id = maxPlayers; id >= 0; id--) {
		if (Players.IsValidPlayerID(id))
		{
			AddPlayer(id);
		}
	}

	// Due to the inconsistency of the `start_round` event being successfully sent at the
	// start of the game, just hide everything here
	EnableVoteRematchPanel(false)
}


// Creates a PlayerRematch element
// PlayerRematch contains the name of the provided player and a checkbox to show whether
// they have voted to rematch
function AddPlayer(id)
{
	var name = Players.GetPlayerName(id);
	var panel = $.CreatePanel("Panel", $("#Players"), id.toString());
	panel.SetHasClass("PlayerRematch", true);
	panel.BLoadLayoutSnippet("PlayerRematch");
	var player_name = panel.GetChild(0).GetChild(0);
	player_name.text = name;
}


// Called when a player uses the vote rematch button
function VoteRematch()
{
	var id = Players.GetLocalPlayer();
	var data = { "id": id };

	EnableVoteRematchButton(false);
	
 	GameEvents.SendCustomGameEventToServer("player_vote_rematch_js", data);
}


// Called when a player has voted to rematch
function OnVoteRematch(args)
{
	var id = args.id;
	SetVoteRematchImage(id, "file://{resources}/images/custom_game/ready/checkmark.png");
}


// Sets the image source of the vote rematch image for the player with the given id
function SetVoteRematchImage(id, src)
{
	var player_panel = $("#" + id.toString());

	if (player_panel)
	{
		var image = player_panel.GetChild(1).GetChild(0).GetChild(0);
		image.SetImage(src);
	}
	else
	{
		AddPlayer(id);
	}
}


// Called when the game end timer updates
// Updates the number shown in the vote rematch UI
function TimerUpdate(args)
{
	var timer = args.timer;
	var label = $("#RematchLabel");
	label.SetDialogVariableInt("seconds", timer);
}


// Called when the game or a rematch starts
// Resets the state of the rematch UI and hides it
function StartGame()
{
	EnableVoteRematchPanel(false);

	var maxPlayers = Players.GetMaxPlayers()
	for (var id = maxPlayers; id >= 0; id--) {
		if (Players.IsValidPlayerID(id))
		{
			SetVoteRematchImage(id, "");
		}
	}
}


// Called when all players vote to have a rematch
function OnAllVotedRematch()
{
	EnableVoteRematchPanel(false);
}

// Called when a game ends
// Shows the vote rematch UI
function EndGame(args)
{
	EnableVoteRematchPanel(true);
	EnableVoteRematchButton(true);
}


// Sets the vote rematch panel's enabled and visible properties to the provided value
function EnableVoteRematchPanel(enabled)
{
	var panel = $("#Rematch");
	EnableElement(panel, enabled);
}


// Sets the vote rematch button's enabled and visible properties to the provided value
function EnableVoteRematchButton(enabled)
{
	var button = $("#RematchButton");
	EnableElement(button, enabled);
}


// Sets the element's enabled and visible properties to the provided value
function EnableElement(element, enabled)
{
	element.enabled = enabled;
	element.visible = enabled;
}


Initialize();