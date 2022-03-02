if modifier_special_bonus_unique_night_stalker == nil then
  modifier_special_bonus_unique_night_stalker = class({})
end

function modifier_special_bonus_unique_night_stalker:GetAttributes()
  return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_special_bonus_unique_night_stalker:IsHidden()
  return true
end

function modifier_special_bonus_unique_night_stalker:IsDebuff()
  return false
end

function modifier_special_bonus_unique_night_stalker:IsPurgable()
  return false
end