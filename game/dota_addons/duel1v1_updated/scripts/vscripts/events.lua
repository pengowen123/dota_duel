require('utils')

-- This file contains all barebones-registered events and has already set up the passed-in parameters for your use.

-- Cleanup a player when they leave
function GameMode:OnDisconnect(keys)
end
-- The overall game state has changed
function GameMode:OnGameRulesStateChange(keys)
end

-- An NPC has spawned somewhere in game.  This includes heroes
function GameMode:OnNPCSpawned(keys)
end

-- An entity somewhere has been hurt.  This event fires very often with many units so don't do too many expensive
-- operations here
function GameMode:OnEntityHurt(keys)
end

-- An item was picked up off the ground
function GameMode:OnItemPickedUp(keys)
  DebugPrint( '[BAREBONES] OnItemPickedUp' )
  DebugPrintTable(keys)

  local unitEntity = nil
  if keys.UnitEntitIndex then
    unitEntity = EntIndexToHScript(keys.UnitEntitIndex)
  elseif keys.HeroEntityIndex then
    unitEntity = EntIndexToHScript(keys.HeroEntityIndex)
  end

  local itemEntity = EntIndexToHScript(keys.ItemEntityIndex)
  local player = PlayerResource:GetPlayer(keys.PlayerID)
  local itemname = keys.itemname
end

-- A player has reconnected to the game.  This function can be used to repaint Player-based particles or change
-- state as necessary
function GameMode:OnPlayerReconnect(keys)
end

-- An item was purchased by a player
function GameMode:OnItemPurchased( keys )
end

-- An ability was used by a player
function GameMode:OnAbilityUsed(keys)
end

-- A non-player entity (necro-book, chen creep, etc) used an ability
function GameMode:OnNonPlayerUsedAbility(keys)
end

-- A player changed their name
function GameMode:OnPlayerChangedName(keys)
end

-- A player leveled up an ability
function GameMode:OnPlayerLearnedAbility( keys)
end

-- A channelled ability finished by either completing or being interrupted
function GameMode:OnAbilityChannelFinished(keys)
end

-- A player leveled up
function GameMode:OnPlayerLevelUp(keys)
end

-- A player last hit a creep, a tower, or a hero
function GameMode:OnLastHit(keys)
end

-- A tree was cut down by tango, quelling blade, etc
function GameMode:OnTreeCut(keys)
end

-- A rune was activated by a player
function GameMode:OnRuneActivated (keys)
end

-- A player took damage from a tower
function GameMode:OnPlayerTakeTowerDamage(keys)
end

-- A player picked a hero
function GameMode:OnPlayerPickHero(keys)
end

-- A player killed another player in a multi-team context
function GameMode:OnTeamKillCredit(keys)
end

-- An entity died
function GameMode:OnEntityKilled( keys )
end



-- This function is called 1 to 2 times as the player connects initially but before they 
-- have completely connected
function GameMode:PlayerConnect(keys)
end

-- This function is called once when the player fully connects and becomes "Ready" during Loading
function GameMode:OnConnectFull(keys)
end

-- This function is called whenever illusions are created and tells you which was/is the original entity
function GameMode:OnIllusionsCreated(keys)
end

-- This function is called whenever an item is combined to create a new item
function GameMode:OnItemCombined(keys)
end

-- This function is called whenever an ability begins its PhaseStart phase (but before it is actually cast)
function GameMode:OnAbilityCastBegins(keys)
end

-- This function is called whenever a tower is killed
function GameMode:OnTowerKill(keys)
end

-- This function is called whenever a player changes there custom team selection during Game Setup 
function GameMode:OnPlayerSelectedCustomTeam(keys)
end

-- This function is called whenever an NPC reaches its goal position/target
function GameMode:OnNPCGoalReached(keys)
end

-- This function is called whenever any player sends a chat message to team or All
function GameMode:OnPlayerChat(keys)
end