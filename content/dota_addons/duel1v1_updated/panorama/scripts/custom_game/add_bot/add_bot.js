"use strict";


// Initializes the add bot UI and logic
function Initialize()
{
	GameEvents.Subscribe("enable_add_bot_button", EnableAddBotButton);

	EnableAddBotButton({ "enabled": false });
}


// Called when a player presses the add bot button
function AddBot()
{
	GameEvents.SendCustomGameEventToServer("add_bot", {});
}


// Sets the add bot button's enabled and visible properties to the provided value
function EnableAddBotButton(args)
{
	var button = $("#AddBotButton");
	EnableElement(button, args.enabled);
}


// Sets the element's enabled and visible properties to the provided value
function EnableElement(element, enabled)
{
	element.enabled = enabled;
	element.visible = enabled;
}


Initialize();