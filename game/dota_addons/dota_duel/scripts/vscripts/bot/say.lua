-- An event handler to process localized messages from the bots

function OnBotSayAllChat(event_source_index, args)
  local message = args["message"]
  local player_id = args["player_id"]

  local bot = PlayerResource:GetPlayer(player_id)
  Say(bot, message, false)
end