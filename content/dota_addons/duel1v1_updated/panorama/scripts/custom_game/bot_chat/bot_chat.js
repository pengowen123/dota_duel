// A hack to localize bot messages (only works with 1 player in the game, which is currently always
// true when there is a bot)

"use strict";


function BotSayAllChat(args) {
	var message = args.message;
	var localized = $.Localize(message);
	var data = {
		"message": localized,
	};
	GameEvents.SendCustomGameEventToServer("bot_message_localized", data);
}

GameEvents.Subscribe("bot_message_raw", BotSayAllChat);