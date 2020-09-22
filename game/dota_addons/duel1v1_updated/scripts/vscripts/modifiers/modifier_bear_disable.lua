if modifier_bear_disable == nil then modifier_bear_disable = class({}) end


function modifier_bear_disable:CheckState()
  local states = {
    [MODIFIER_STATE_STUNNED] = true,
    [MODIFIER_STATE_ATTACK_IMMUNE] = true,
    [MODIFIER_STATE_MAGIC_IMMUNE] = true,
    [MODIFIER_STATE_INVISIBLE] = true,
    [MODIFIER_STATE_PASSIVES_DISABLED] = true,
    [MODIFIER_STATE_SILENCED] = true,
  }

  return states
end


function modifier_bear_disable:GetTexture()
  return "modifiers/modifier_bear_disable"
end