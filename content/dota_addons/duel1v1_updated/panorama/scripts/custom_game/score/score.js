"use strict";


// Initializes the score UI and logic
function Initialize()
{
	GameEvents.Subscribe("score_update", ScoreUpdate);
}


function ScoreUpdate(args)
{
	$("#ScoreRadiant").text = args.radiant.toString();
	$("#ScoreDire").text = args.dire.toString();
}


Initialize();