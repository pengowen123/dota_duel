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

		if IsMonkeyKingClone(parent) then
			return
		end
		
		-- If the entity will reincarnate, kill them and re-add the modifier to kill them again
		if parent.WillReincarnate and parent:WillReincarnate() then
			local re_add_modifier = function()
				local data = { duration = 0.1 }
				parent:AddNewModifier(nil, nil, "leave_arena_modifier", data)
			end

			local reincarnate_delay = 5.0

			Timers:CreateTimer(reincarnate_delay, re_add_modifier)
		end

		parent:Kill(nil, parent)
	end
end


function leave_arena_modifier:GetTexture()
	-- Texture taken from xavbonmar at https://www.onlinewebfonts.com/icon/488688
	return "modifiers/leave_arena"
end