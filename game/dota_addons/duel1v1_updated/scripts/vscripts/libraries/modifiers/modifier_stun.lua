if modifier_stun == nil then modifier_stun = class({}) end

function modifier_stun:CheckState()
	local states = {
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_ATTACK_IMMUNE] = true,
		[MODIFIER_STATE_MAGIC_IMMUNE] = true,
	}

	local parent = self:GetParent()

	-- Silence ancient apparition in base to prevent an exploit where he ults the enemy spawn in the arena before the round starts
	if parent ~= nil then
		if parent:GetName() == "npc_dota_hero_ancient_apparition" then
			states[MODIFIER_STATE_SILENCED] = true
		end
	end

	return states
end