-- In this file you can set up all the properties and settings for your game mode.

-- Lobby settings
SKIP_TEAM_SETUP = true                  -- Should we skip the team setup entirely?
ENABLE_AUTO_LAUNCH = true               -- Should we automatically have the game complete team setup after AUTO_LAUNCH_DELAY seconds?
AUTO_LAUNCH_DELAY = 30                  -- How long should the default team selection launch timer be?  The default for custom games is 30.  Setting to 0 will skip team selection.
MAX_NUMBER_OF_TEAMS = 2                 -- How many potential teams can be in this game mode?

-- Game phases
HERO_SELECTION_TIME = 30.0              -- How long should we let people select their hero?
PRE_GAME_TIME = 0.0                     -- How long after people select their heroes should the horn blow and the game start?
POST_GAME_TIME = 60.0                   -- How long should we let people look at the scoreboard before closing the server automatically?
GAME_END_DELAY = 1                      -- How long should we wait after the game winner is set to display the victory banner and End Screen?  Use -1 to keep the default (about 10 seconds)
VICTORY_MESSAGE_DURATION = 1            -- How long should we wait after the victory message displays to show the End Screen?

-- Game rules
ALLOW_SAME_HERO_SELECTION = true        -- Should we let people select the same hero as each other
UNIVERSAL_SHOP_MODE = true              -- Should the main shop contain Secret Shop items as well as regular items
ENABLE_HERO_RESPAWN = true              -- Should the heroes automatically respawn on a timer or stay dead until manually respawned
FIXED_RESPAWN_TIME = 5                  -- What time should we use for a fixed respawn timer?  Use -1 to keep the default dota behavior.
BUYBACK_ENABLED = false                 -- Should we allow people to buyback when they die?
DISABLE_DAY_NIGHT_CYCLE = true          -- Should we disable the day night cycle from naturally occurring? (Manual adjustment still possible)
TREE_REGROW_TIME = 90.0                 -- How long should it take individual trees to respawn after being cut down/destroyed?

-- Infinite gold
STARTING_GOLD = 99999                   -- How much starting gold should we give to each player?
GOLD_PER_TICK = 99999                   -- How much gold should players get per tick?
GOLD_TICK_TIME = 1                      -- How long should we wait in seconds between gold ticks?

-- Dynamic settings based on map

-- The number of players on each team, by map
players_per_team = {
	["duel1v1"] = 1,
	["duel1v1_classic"] = 1,
	["duel2v2"] = 2,
	["duel2v2_classic"] = 2,
	["duel3v3"] = 3,
	["duel3v3_classic"] = 3,
}
players_per_team = players_per_team[GetMapName()]

CUSTOM_TEAM_PLAYER_COUNT = {}           -- If we're not automatically setting the number of players per team, use this table
CUSTOM_TEAM_PLAYER_COUNT[DOTA_TEAM_GOODGUYS] = players_per_team
CUSTOM_TEAM_PLAYER_COUNT[DOTA_TEAM_BADGUYS]  = players_per_team

-- Special settings for all non-1v1 maps
if players_per_team > 1 then
	-- Allow players to choose teams (they are shuffled by default but players might want to set them manually)
	SKIP_TEAM_SETUP = false
end