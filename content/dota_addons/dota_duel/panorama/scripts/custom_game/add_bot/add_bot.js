"use strict";


var client_team = Players.GetTeam(Players.GetLocalPlayer());
var is_spectator_client = !(client_team === DOTATeam_t.DOTA_TEAM_GOODGUYS ||
                            client_team === DOTATeam_t.DOTA_TEAM_BADGUYS);


// Initializes the add bot UI and logic
function Initialize()
{
  GameEvents.Subscribe("enable_add_bot_button", EnableAddBotButton);
  GameEvents.Subscribe("start_round", OnStartRound);

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

  if (!is_spectator_client)
  {
    EnableElement(button, args.enabled);
  }
  else
  {
    EnableElement(button, false);
  }
}


// Called when a round starts
// Hides the add bot button
function OnStartRound()
{
  EnableAddBotButton({ "enabled": false });
}


// Sets the element's enabled and visible properties to the provided value
function EnableElement(element, enabled)
{
  element.enabled = enabled;
  element.visible = enabled;
}


Initialize();