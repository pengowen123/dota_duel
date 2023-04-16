-- Constants for the bots
--
-- Changing these configures the general behavior of the bots, but hero-specific configuration is
-- contained in their respective files


-- The tick time for performing bot think functions
-- `Think` will be called for each bot once every this many seconds
THINK_INTERVAL = 0.25
-- The tick time for updating the illusion data
ILLUSION_DATA_UPDATE_INTERVAL = 0.5


-- The non-illusion confidence score above which to consider an NPC likely to not be an illusion
LIKELY_NON_ILLUSION_THRESHOLD = 0.9

-- The rate at which the bots learn from observations
-- 0 to never learn, 1 to learn instantly
-- Leaving it in the middle adds unpredictability to the bots, while still preventing abuse of them
-- with silly strategies
OBSERVATION_LEARN_RATE = 0.66

-- The evasion value above which to consider a hero to have high evasion
HIGH_EVASION = 0.3
-- The status resistance value above which to consider a hero to have high status resistance
HIGH_STATUS_RESISTANCE = 0.25

-- The ratio of the time spent fully disabled to the time spent fighting above which to consider the
-- enemy to have a high amount of total disable
HIGH_TOTAL_DISABLE_RATIO = 0.5
-- The duration (in seconds) above which to consider a single, consecutive string of disables to be
-- long
HIGH_CONSECUTIVE_DISABLE = 5.0
-- Like `HIGH_TOTAL_DISABLE_RATIO`, but only considers when the bot was weakly disabled
HIGH_WEAK_DISABLE_RATIO = 0.5

-- The ratio of health loss per second to the bot's max health above which to consider the bot to
-- be taking a high amount of damage
HIGH_HP_LOSS_RATIO = 0.35

-- The amount of randomness to add to any position goal
POSITION_GOAL_RANDOMNESS = 100.0
-- The radius within which to consider a position goal to have been reached
POSITION_GOAL_REACHED_RADIUS = 200.0

-- The range within which to search for enemies while the bot is fighting
-- NOTE: If too small to cover the arena, the bots may ignore some enemies while dead because they
--       can't move
ENEMY_SEARCH_RADIUS = 5000.0


-- Below are actual constants that should not be changed, as they simply reflect actual game
-- mechanics

MOON_SHARD_CONSUMED_ATTACK_SPEED = 0.60
