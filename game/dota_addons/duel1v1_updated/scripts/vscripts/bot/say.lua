-- An event handler to process localized messages from the bot

function OnBotSayAllChat(event_source_index, args)
	local message = args["message"]

	if global_bot_controller then
		local bot = PlayerResource:GetPlayer(global_bot_controller.bot_id)

		Say(bot, message, false)
	end
end