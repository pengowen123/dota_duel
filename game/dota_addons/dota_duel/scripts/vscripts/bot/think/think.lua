-- The actual logic for the bots, separated into shared logic and hero-specific logic

require('bot/think/common')
require('bot/think/base')

require('bot/think/heroes/spectre')
require('bot/think/heroes/ogre_magi')
require('bot/think/heroes/wisp')
require('bot/think/heroes/juggernaut')
require('bot/think/heroes/ursa')
require('bot/think/heroes/arc_warden')


-- Returns a bot thinker object for the hero with the given name, or nil if no thinker is
-- implemented for that hero
-- The thinker will be assigned to control the player with ID `player_id`
function BotGetThinker(player_id, hero_name)
  local thinker_classes = {
    ["npc_dota_hero_spectre"] = BotSpectre,
    ["npc_dota_hero_ogre_magi"] = BotOgreMagi,
    ["npc_dota_hero_wisp"] = BotWisp,
    ["npc_dota_hero_juggernaut"] = BotJuggernaut,
    ["npc_dota_hero_ursa"] = BotUrsa,
    ["npc_dota_hero_arc_warden"] = BotArcWarden,
  }

  local thinker_class = thinker_classes[hero_name]

  if thinker_class then
    return thinker_class:New(player_id)
  else
    print("no thinker implemented for " .. hero_name)
    return nil
  end
end
