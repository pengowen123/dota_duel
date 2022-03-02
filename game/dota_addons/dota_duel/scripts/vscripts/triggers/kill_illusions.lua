function OnStartTouch(keys)
	local activator = keys.activator

	if activator:IsIllusion() then
		-- Make the entity commit suicide
		activator:Kill(nil, activator)
	end
end

function OnEndTouch(keys)
end