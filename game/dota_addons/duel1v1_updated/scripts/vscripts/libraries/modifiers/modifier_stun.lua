if modifier_stun == nil then modifier_stun = class({}) end

function modifier_stun:CheckState()
	local states = {
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_ATTACK_IMMUNE] = true,
		[MODIFIER_STATE_MAGIC_IMMUNE] = true,
	}

	local parent = self:GetParent()

	-- Silence ancient apparition in base to prevent an exploit where he ults the enemy spawn
	-- in the arena before the round starts
	-- Also silence lone druid's spirit bear to prevent it teleporting to base to heal, then returning to
	-- lone druid in the arena
	if parent ~= nil then
		local name = parent:GetName()

		if name == "npc_dota_hero_ancient_apparition" or name == "npc_dota_lone_druid_bear" then
			states[MODIFIER_STATE_SILENCED] = true
		end
	end

	return states
end