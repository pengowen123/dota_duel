-- Copied and modified from https://github.com/Pizzalol/SpellLibrary
-- License: https://creativecommons.org/licenses/by/2.0/legalcode

arc_warden_spark_wraith = class({})

function SparkWraith(keys)
  local caster = keys.caster

  if caster ~= nil then
    local point = keys.target_points[1]
    local team_id = caster:GetTeamNumber()
    local thinker = CreateModifierThinker(caster, self, "arc_warden_spark_wraith_custom_thinker", {}, point, team_id, false)

    -- local talent_learned = caster:GetAbilityByIndex(13):GetLevel() > 0
  end
end

function arc_warden_spark_wraith:OnProjectileHit( target, location )
  print("hit")
  local thinker = self:GetCaster()
  local modifier = thinker:FindModifierByName("arc_warden_spark_wraith_custom_thinker")
  local caster = modifier:GetCaster()
  if caster == nil then
    caster = PlayerResource:GetSelectedHeroEntity(thinker.player_id)
  end
  ApplyDamage({ victim = target, attacker = caster, damage = self:GetAbilityDamage(), damage_type = self:GetAbilityDamageType(), ["ability"] = self})
  local damage_particle = ParticleManager:CreateParticle("particles/units/heroes/hero_zuus/zuus_base_attack_sparkles.vpcf", PATTACH_ROOTBONE_FOLLOW, target)
  ParticleManager:ReleaseParticleIndex(damage_particle)
  AddFOWViewer(caster:GetTeamNumber(), target:GetAbsOrigin(), self:GetSpecialValueFor("vision_radius"), 3.34, true)
  modifier:Destroy()
end

arc_warden_spark_wraith_custom_thinker = class({})

function arc_warden_spark_wraith_custom_thinker:OnCreated(keys)
  if IsServer() then
    local thinker = self:GetParent()
    local caster = self:GetCaster()
    local ability = caster:FindAbilityByName("arc_warden_spark_wraith_custom")

    -- Get ability values
    self.startup_time = ability:GetSpecialValueFor("activation_delay")
    self.duration = ability:GetSpecialValueFor("duration")
    self.speed = ability:GetSpecialValueFor("wraith_speed")
    self.search_radius = ability:GetSpecialValueFor("radius")
    self.vision_radius = ability:GetSpecialValueFor("wraith_vision_radius")

    -- Create particle
    local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_arc_warden/arc_warden_wraith.vpcf", PATTACH_OVERHEAD_FOLLOW, thinker)
    local thinker_pos = thinker:GetAbsOrigin()
    ParticleManager:SetParticleControl(particle, 3, thinker_pos)
    self:StartIntervalThink(self.startup_time)
    self.particle = particle

    -- Set thinker properties
    thinker:SetMoveCapability(DOTA_UNIT_CAP_MOVE_FLY)
    thinker:SetDayTimeVisionRange(self.vision_radius)
    thinker:SetNightTimeVisionRange(self.vision_radius)
    thinker:AddAbility("arc_warden_spark_wraith_custom")
    thinker:FindAbilityByName("arc_warden_spark_wraith_custom"):SetLevel(ability:GetLevel())

    thinker.player_id = caster:GetPlayerOwnerID()
  end
end

function arc_warden_spark_wraith_custom_thinker:OnIntervalThink()
  local thinker = self:GetParent()
  local thinker_pos = thinker:GetAbsOrigin()
  if self.startup_time ~= nil then
    -- Set expiration time starting from when the activation delay ends
    self.startup_time = nil
    self.expire = GameRules:GetGameTime() + self.duration
    self:StartIntervalThink(0)
  elseif self.duration ~= nil then
    if GameRules:GetGameTime() > self.expire then
      self:Destroy()
    else
      local enemies = FindUnitsInRadius(
        thinker:GetTeamNumber(),
        thinker_pos,
        nil,
        self.search_radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_CREEP + DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_CLOSEST,
        false
      )

      if enemies[1] then
        self.target = enemies[1]
        self.duration = nil
        self.expire = nil
        self:StartIntervalThink(-1)
        local info = {
          Target = enemies[1],
          Source = thinker,
          Ability = thinker:FindAbilityByName("arc_warden_spark_wraith_custom"), 
          EffectName = "particles/units/heroes/hero_arc_warden/arc_warden_wraith_prj.vpcf",
          vSourceLoc = thinker_pos,
          bDrawsOnMinimap = false,
          iSourceAttachment = 1,
          iMoveSpeed = self.speed,
          bDodgeable = false,
          bProvidesVision = true,
          iVisionRadius = self.vision_radius,
          iVisionTeamNumber = thinker:GetTeamNumber(),
          bVisibleToEnemies = true,
          flExpireTime = nil,
          bReplaceExisting = false
        }
        ProjectileManager:CreateTrackingProjectile(info)
        ParticleManager:DestroyParticle(self.particle, false)
      end
    end
  end
end

function arc_warden_spark_wraith_custom_thinker:OnDestroy()
  if self.particle then
    ParticleManager:DestroyParticle(self.particle, false)
  end
end

function arc_warden_spark_wraith_custom_thinker:CheckState()
  if self.duration then
    return {[MODIFIER_STATE_PROVIDES_VISION] = true}
  end
  return nil
end