function OnStartTouch(keys)
	local activator = keys.activator
	local name = activator:GetName()
	local classname = activator:GetClassname()

	if string.find(name, "npc_dota_hero") and name ~= "npc_dota_hero_arc_warden" then
		return
	elseif classname == "dota_item_drop" then
		activator:Kill()
	elseif name == "npc_dota_creep_neutral" then
		-- Neutral creeps must be removed instead of killed, or new neutrals will not spawn
		-- because the camps still count as populated
		UTIL_Remove(activator)
	else
		-- Make the entity commit suicide
		activator:Kill(nil, activator)
	end
end

function OnEndTouch(keys)
end