if modifier_special_bonus_unique_ancient_apparition_3 == nil then
  modifier_special_bonus_unique_ancient_apparition_3 = class({})
end

function modifier_special_bonus_unique_ancient_apparition_3:GetAttributes()
  return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_special_bonus_unique_ancient_apparition_3:IsHidden()
  return true
end

function modifier_special_bonus_unique_ancient_apparition_3:IsDebuff()
  return false
end

function modifier_special_bonus_unique_ancient_apparition_3:IsPurgable()
  return false
end