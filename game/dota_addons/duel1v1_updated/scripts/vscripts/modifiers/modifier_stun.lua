if modifier_stun == nil then modifier_stun = class({}) end


function modifier_stun:CheckState()
	local states = {
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_ATTACK_IMMUNE] = true,
		[MODIFIER_STATE_MAGIC_IMMUNE] = true,
		[MODIFIER_STATE_TRUESIGHT_IMMUNE] = true,
		[MODIFIER_STATE_INVISIBLE] = true,
		-- Certain heroes must be silenced while in base to prevent exploits, but it is safer to just
		-- silence all heroes
		[MODIFIER_STATE_SILENCED] = true,
	}

	local parent = self:GetParent()

	if parent ~= nil then
		local name = parent:GetName()

		if IsDummyHero and IsDummyHero(parent) then
			states[MODIFIER_STATE_UNSELECTABLE] = true
			states[MODIFIER_STATE_INVISIBLE] = true
			states[MODIFIER_STATE_TRUESIGHT_IMMUNE] = true
		end
	end

	return states
end


function modifier_stun:GetTexture()
	return "modifiers/modifier_stun"
end