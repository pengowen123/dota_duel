"use strict";


function Initialize()
{
	GameEvents.Subscribe("start_round", StartRound);
	GameEvents.Subscribe("end_round", EndRound);
	GameEvents.Subscribe("end_game", EndGame);
	GameEvents.Subscribe("round_timeout_timer_update", TimeoutTimerUpdate);

	ToggleTimeoutTimer(false);
}


function StartRound()
{
	ToggleTimeoutTimer(true);
}


function EndRound(args)
{
	ToggleTimeoutTimer(false);
}


function EndGame()
{
	ToggleTimeoutTimer(false);
}


// Sets whether the round timeout timer is visible
function ToggleTimeoutTimer(state)
{
	var panel = $("#RoundTimeout");
	panel.enabled = state;
	panel.visible = state;

	if (state)
	{
		SetTimerString("");
	}
}

// Updates the timeout timer
function TimeoutTimerUpdate(args)
{
	var timer = args.timer;
	SetTimerString(FormatTimer(timer));

	var label = $("#RoundTimeoutTimer");

	var turn_red = 30;
	var tick = 15;

	if (timer <= turn_red)
	{
		label.style.color = "#CC1111";

		// Cause the color to flash to make it more apparent
		$.Schedule(0.5, function() {
			label.style.color = "white";
		});
	}
	else
	{
		label.style.color = "white";
	}

	if (timer <= tick)
	{
		Game.EmitSound("DotaDuel.RoundTimeoutTick");
	}
}

// Sets the string of the timer label
function SetTimerString(str)
{
	var label = $("#RoundTimeoutTimer");
	label.text = str;
}

// Formats the seconds value to a minutes:seconds string
function FormatTimer(seconds)
{
	var minutes = Math.floor(seconds / 60);
	var seconds = seconds % 60;
	var seconds_pad = seconds < 10 ? "0" : "";
	return minutes.toString() + ":" + seconds_pad + seconds;
}

Initialize();