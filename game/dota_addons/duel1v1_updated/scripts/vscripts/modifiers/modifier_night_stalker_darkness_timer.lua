if modifier_night_stalker_darkness_timer == nil then
  modifier_night_stalker_darkness_timer = class({})
end

function modifier_night_stalker_darkness_timer:GetAttributes()
  return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_night_stalker_darkness_timer:IsHidden()
  return true
end

function modifier_night_stalker_darkness_timer:IsDebuff()
  return false
end

function modifier_night_stalker_darkness_timer:IsPurgable()
  return false
end