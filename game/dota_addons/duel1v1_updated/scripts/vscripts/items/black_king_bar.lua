function BasicDispel(keys)
	local caster = keys.caster

	local remove_positive_buffs = false
	local remove_debuffs = true
	local frame_only = false
	local remove_stuns = false
	local remove_exceptions = false

	caster:Purge(
		remove_positive_buffs,
		remove_debuffs,
		frame_only,
		remove_stuns,
		remove_exceptions
	)
end