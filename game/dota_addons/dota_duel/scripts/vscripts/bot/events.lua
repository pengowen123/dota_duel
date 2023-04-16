-- Hooks for handling various game events for the bots


-- Called when all bots have been created and picked their heroes
function BotOnAllBotsLoaded()
  for _, c in pairs(global_bot_controllers) do
    c:OnAllBotsLoaded()
  end
end


-- Called when a match starts, including rematches
function BotOnMatchStart()
  for _, c in pairs(global_bot_controllers) do
    -- Reset all bot controllers' state
    c:Reset()
    -- Force all bots to ready up
    ForceReadyUp(c.id)
  end

  -- Update illusion data
  CheckTeamIllusionCapabilities()
end


-- Called at the start of the rematch hero select phase
function BotOnRematch()
  -- Reset the list of picked heroes from the previous match
  ResetBotHeroPicks()

  for _, c in pairs(global_bot_controllers) do
    -- Pick new random heroes for all bots
    local data = {
      ["id"] = c.id,
      ["hero"] = PickBotHero(c.team),
    }
    OnSelectHero(nil, data)
  end
end


-- Called when a round starts
function BotOnRoundStart()
  -- Reset illusion data
  ResetIllusionData()

  for _, c in pairs(global_bot_controllers) do
    -- Perform round start actions for each bot
    c:OnRoundStart()
  end
end


-- Called when a round ends
function BotOnRoundEnd()
  for _, c in pairs(global_bot_controllers) do
    -- Force all bots to ready up
    ForceReadyUp(c.id)
    -- Perform round end actions for each bot
    c:OnRoundEnd()
  end
end


-- Called when a hero spawns for the first time
function BotOnHeroSpawned(hero)
  for _, c in pairs(global_bot_controllers) do
    -- Notify the respective bot that it has a new hero entity assigned to it (if the hero belongs
    -- to one of the controlled bots)
    if hero:GetPlayerOwnerID() == c.id then
      c:OnNewHeroEntity(hero)
    end
  end
end


-- Called when the game fully ends, with no possibility of a rematch
function BotOnGameEnd()
  for _, c in pairs(global_bot_controllers) do
    -- Perform game end actions for each bot
    c:OnGameEnd()
  end
end


-- Called every `THINK_INTERVAL` seconds
function BotOnThink()
  for _, c in pairs(global_bot_controllers) do
    -- Perform think functions for each bot
    c:Think()
  end
end


-- Called whenever an entity takes damage
-- `entity` is the entity that took damage, `attacker` is the entity that caused the damage,
-- `damage` is the damage amount, and `source_ability` is the ability that caused the damage, if
-- one exists
function BotOnEntityHurt(entity, attacker, damage, source_ability)
  if entity:IsHero() then
    -- Check if the entity is a bot's hero entity, and notify it if so
    for _, c in pairs(global_bot_controllers) do
      if entity == c.hero then
        c:OnHurt(damage, source_ability)
      end
    end
  end

  -- Update illusion data (for NPCs only)
  if entity.IsHero then
    IllusionsOnNPCHurt(entity, attacker, damage, source_ability)
  end
end


-- Called whenever an ability is cast
-- `caster` is the entity that used the ability, and `ability` is the ability itself
function BotOnAbilityUsed(caster, ability)
  -- Update illusion data
  IllusionsOnAbilityUsed(caster, ability)
end
