-- Logic for selecting bots' heroes


hero_pool = {
  -- "npc_dota_hero_spectre",
  -- "npc_dota_hero_ogre_magi",
  "npc_dota_hero_wisp",
  -- "npc_dota_hero_juggernaut",
  -- "npc_dota_hero_ursa",
  -- "npc_dota_hero_arc_warden",
}


-- A list of heroes picked by any radiant bot during this match (reset for rematches)
bot_picks_radiant = {}
-- A list of heroes picked by any dire bot during this match (reset for rematches)
bot_picks_dire = {}


-- Returns the list of heroes picked by any bot on the given team during this match
function GetBotHeroPicks(team)
  if team == DOTA_TEAM_GOODGUYS then
    return bot_picks_radiant
  elseif team == DOTA_TEAM_BADGUYS then
    return bot_picks_dire
  end
end


-- Registers that a bot on the given team picked a hero
function AddBotHeroPick(team, hero)
  if team == DOTA_TEAM_GOODGUYS then
    table.insert(bot_picks_radiant, hero)
  elseif team == DOTA_TEAM_BADGUYS then
    table.insert(bot_picks_dire, hero)
  end
end


-- Resets the bot hero pick lists
-- Should be called on rematch
function ResetBotHeroPicks()
  bot_picks_radiant = {}
  bot_picks_dire = {}
end


-- Returns a random hero name for a bot on the given team to pick
-- Guaranteed to return unique hero names until all possible heroes have been picked, in which case
-- a random non-unique hero name will be returned instead
-- Calling `ResetBotHeroPicks` resets this function so that it starts from the full hero pool again
function PickBotHero(team)
  local already_picked = GetBotHeroPicks(team)
  -- Heroes from the bot's hero pool that another bot on the team did not already pick
  local valid_heroes = {}

  for _, possible_hero in pairs(hero_pool) do
    local exists = false

    for _, existing_hero in pairs(already_picked) do
      if existing_hero == possible_hero then
        exists = true
        break
      end
    end

    -- The hero is a valid choice if it's not in `already_picked`
    if not exists then
      table.insert(valid_heroes, possible_hero)
    end
  end

  local hero_name = nil

  if #valid_heroes > 0 then
    -- If there are valid choices, pick one at random
    hero_name = valid_heroes[RandomInt(1, #valid_heroes)]
  else
    -- Otherwise, just pick a random hero from the bot's hero pool
    hero_name = hero_pool[RandomInt(1, #hero_pool)]
  end

  -- Add this hero to the list of picked heroes
  AddBotHeroPick(team, hero_name)

  return hero_name
end
