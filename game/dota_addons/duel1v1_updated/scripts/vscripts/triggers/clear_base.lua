function OnStartTouch(keys)
	local activator = keys.activator
	local name = activator:GetName()
	local classname = activator:GetClassname()

	if string.find(name, "npc_dota_hero") and name ~= "npc_dota_hero_arc_warden" then
		return
	elseif classname == "dota_item_drop" then
		activator:Kill()
	else
		activator:Kill(nil, nil)
	end
end

function OnEndTouch(keys)
end