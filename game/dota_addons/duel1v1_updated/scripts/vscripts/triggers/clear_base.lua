function OnStartTouch(keys)
	local activator = keys.activator
	local name = activator:GetName()

	if string.find(name, "npc_dota_hero") then
		return
	else
		activator:Kill(nil, nil)
	end
end

function OnEndTouch(keys)
end