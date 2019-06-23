if modifier_bear_disable == nil then modifier_bear_disable = class({}) end

function modifier_bear_disable:CheckState()
	local states = {
		[MODIFIER_STATE_STUNNED] = true,
		[MODIFIER_STATE_ATTACK_IMMUNE] = true,
		[MODIFIER_STATE_MAGIC_IMMUNE] = true,
		[MODIFIER_STATE_INVISIBLE] = true,
		[MODIFIER_STATE_PASSIVES_DISABLED] = true,
	}

	return states
end