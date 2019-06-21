"use strict";

function Initialize()
{
	ToggleForfeitFlag(true);
	ToggleForfeitScreen(false);
	$.Msg("Trying to initialize");
}

function CleanUp(){
	ToggleForfeitScreen(false);
	ToggleForfeitFlag(true);
}

function ShowPopUp(){
	ToggleForfeitScreen(true);
	ToggleForfeitFlag(false);
}

function GiveUp(){
	var player_id = Players.GetLocalPlayer();
	var data = {"player_id" : player_id};
	$.Msg("Invoking lua for surrendering with data: "+ data["player_id"])
	GameEvents.SendCustomGameEventToServer("player_surrender_js", data);
	CleanUp();
}

// Sets the forfeit flag on the top
function ToggleForfeitFlag(state){
	var panel = $("#surrender");
	ToggleElement(panel, state);
}

// Sets the forfeit pop-up on the screen
function ToggleForfeitScreen(state) {
	var panel = $("#PopUpHolder");
	ToggleElement(panel, state);
}

// Sets the element's enabled and visible properties to the provided value
function ToggleElement(element, enabled)
{
	$.Msg("enabled: " + enabled.toString())
	element.enabled = enabled;
	element.visible = enabled;
}

Initialize();
