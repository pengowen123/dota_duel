// A hack to localize bot messages (with multiple players in the match, the message can only be
// localized in one language)

"use strict";


function BotSayAllChat(args) {
	var message = args.message;
	var player_id = args.player_id;
	var localized = $.Localize(message);
	var data = {
		"message": localized,
		"player_id": player_id,
	};
	GameEvents.SendCustomGameEventToServer("bot_message_localized", data);
}

GameEvents.Subscribe("bot_message_raw", BotSayAllChat);