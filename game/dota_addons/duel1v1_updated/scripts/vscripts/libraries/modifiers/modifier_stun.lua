if modifier_stun == nil then modifier_stun = class({}) end

function modifier_stun:CheckState()
	local states = { [MODIFIER_STATE_STUNNED] = true }
	return states
end

function modifier_stun:DeclareFunctions()
	local funcs = { MODIFIER_PROPERTY_OVERRIDE_ANIMATION }
	return funcs
end

function modifier_stun:GetOverrideAnimation(params)
	return ACT_DOTA_DISABLED
end

function modifier_stun:IsHidden()
	return false
end