require('../../utils')

if leave_arena_modifier == nil then
    leave_arena_modifier = class({})
end


function leave_arena_modifier:GetAttributes()
    return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end


function leave_arena_modifier:OnDestroy()
	-- Only kill the entity if the buff expired, not if it was removed
	if self:GetRemainingTime() <= 0.0 then
		local parent = self:GetParent()

		if parent.GetTeam == nil then
			return
		end
		
		local enemy_player = GetEnemyPlayer(parent:GetTeam())

		if enemy_player == nil then
			enemy_player = parent
		end
		
		parent:Kill(nil, enemy_player)
	end
end