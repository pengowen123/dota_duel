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

  -- Add buff
  local duration = self:GetLevelSpecialValueFor("duration", self:GetLevel() - 1)
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
  return self.BaseClass.GetCooldown(self, level)
end
