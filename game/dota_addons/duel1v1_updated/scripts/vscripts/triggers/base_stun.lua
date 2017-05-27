LinkLuaModifier("modifier_stun","libraries/modifiers/modifier_stun.lua",LUA_MODIFIER_MOTION_NONE)

function OnStartTouch(trigger)
	local activator = trigger.activator

	if activator == nil then
		return
	end

	activator:AddNewModifier(activator, nil, "modifier_stun", {})
end

function OnEndTouch(trigger)
	local activator = trigger.activator

	if activator == nil then
		return
	end

	activator:RemoveModifierByName("modifier_stun")
end