if modifier_stun == nil then modifier_stun = class({}) end

function modifier_stun:CheckState()
	local states = {
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_ATTACK_IMMUNE] = true,
		[MODIFIER_STATE_MAGIC_IMMUNE] = true,
	}

	local parent = self:GetParent()

	if parent ~= nil then
		local name = parent:GetName()

		-- Certain heroes must be silenced while in base to prevent exploits
		local heroes_to_silence = {
			["npc_dota_hero_ancient_apparition"] = true,
			["npc_dota_lone_druid_bear"] = true,
			["npc_dota_hero_lycan"] = true,
			["npc_dota_hero_weaver"] = true,
			["npc_dota_hero_puck"] = true,
			["npc_dota_hero_ember_spirit"] = true,
			["npc_dota_hero_morphling"] = true,
			["npc_dota_hero_spectre"] = true,
			["npc_dota_hero_furion"] = true,
			["npc_dota_hero_meepo"] = true,
			["npc_dota_hero_broodmother"] = true,
			["npc_dota_hero_rubick"] = true,
			["npc_dota_hero_gyrocopter"] = true,
		}

		if heroes_to_silence[name] then
			states[MODIFIER_STATE_SILENCED] = true
		end
	end

	return states
end