-- Initialization of the game

require('neutrals')


-- Initializes the custom neutrals system
function InitNeutrals()
  Timers:RemoveTimer("neutrals_timer")

  local spawn_neutrals = function()
    SpawnAllNeutrals()
    return 60.0
  end

  local args = {
    endTime = 0.5,
    callback = spawn_neutrals
  }

  Timers:CreateTimer("neutrals_timer", args)
end


-- Levels all players to level 25
-- Also checks for players who didn't pick a hero and makes them lose
function LevelUpPlayers()
	for i, playerID in pairs(GetPlayerIDs()) do
    local player = PlayerResource:GetPlayer(playerID)
    local player_entity = player:GetAssignedHero()

    if player_entity then
      local levelup = function()
        player_entity:AddExperience(99999.0, 0, false, false)
      end

      for i=0,25 do
        local ability = player_entity:GetAbilityByIndex(i)

        if ability then
          -- Only talents require higher levels than 6, which must not be upgraded here
          if ability:GetHeroLevelRequiredToUpgrade() <= 6 then
            -- Lua ranges are inclusive so this starts at 1 to compensate
            for i=1,ability:GetMaxLevel() - ability:GetLevel() do
              player_entity:UpgradeAbility(ability)
            end
          end
        end
      end

      local levelup_delay = 0.5

      Timers:CreateTimer(levelup_delay, levelup)
    else
      -- Make the player lose if they didn't pick a hero
      MakePlayerLose(playerID, "#duel_no_selected_hero")
    end
  end
end


-- Removes Town Portal Scrolls from players' inventories
-- One is added at the start of the game since 7.07, so this is called to delete it
function RemoveTPScroll()
  for i, playerID in pairs(GetPlayerIDs()) do
    local player = PlayerResource:GetPlayer(playerID)
    local player_entity = player:GetAssignedHero()

    if player_entity then
      for i=0,10 do
        local item = player_entity:GetItemInSlot(i)

        if item then
          local name = item:GetName()
          local items_to_remove = {
            ["item_tpscroll"] = true,
            ["item_enchanted_mango"] = true,
            ["item_faerie_fire"] = true,
          }
          if items_to_remove[name] then
            item:Destroy()
          end
        end
      end
    else
      -- Make the player lose if they didn't pick a hero
      MakePlayerLose(playerID, "#duel_no_selected_hero")
    end
  end
end