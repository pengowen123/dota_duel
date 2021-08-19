if night_stalker_darkness_custom == nil then
  night_stalker_darkness_custom = class ({})
end


function night_stalker_darkness_custom:OnSpellStart()
  local caster = self:GetCaster()

  -- Create particle
  caster:EmitSound("Hero_Nightstalker.Darkness")
  local particle_name = "particles/units/heroes/hero_night_stalker/nightstalker_ulti.vpcf"
  -- Add darkness particle
  local particle = ParticleManager:CreateParticle(particle_name, PATTACH_ABSORIGIN_FOLLOW, caster)
  ParticleManager:SetParticleControl(particle, 0, caster:GetAbsOrigin())
  ParticleManager:SetParticleControl(particle, 1, caster:GetAbsOrigin())

  -- Add buff (with talents applied)
  local duration = self:GetLevelSpecialValueFor("duration", self:GetLevel() - 1)
  local talent = caster:FindAbilityByName("special_bonus_unique_night_stalker_7")

  if talent and talent:GetLevel() > 0 then
    duration = duration + talent:GetSpecialValueFor("value")
  end

  caster:AddNewModifier(caster, self, "modifier_night_stalker_darkness", { duration = duration })
  -- Add tracking buff that persists through death (used to apply night time)
  caster:AddNewModifier(caster, self, "modifier_night_stalker_darkness_timer", { duration = duration })

  -- Apply nightstalker night for 1 second repeatedly while the tracking modifier is present
  -- This allows a script to remove the modifier to end the nightstalker night
  local apply_night = function()
    if not caster:IsNull() then
      local modifier = caster:FindModifierByName("modifier_night_stalker_darkness_timer")

      if modifier then
        local time_remaining = modifier:GetRemainingTime()
        local night_duration = math.min(1.25, time_remaining)


        if night_duration > 0.0 then
          GameRules:BeginNightstalkerNight(night_duration)

          return 1.0
        end
      end
    end
  end

  Timers:CreateTimer(apply_night)
end


function night_stalker_darkness_custom:GetCooldown(level)
  local caster = self:GetCaster()
  local cooldown = self.BaseClass.GetCooldown(self, level)

  local talent_value = caster:GetModifierStackCount("modifier_special_bonus_unique_night_stalker", caster)

  if talent_value then
    cooldown = cooldown - talent_value
  end

  return cooldown
end
