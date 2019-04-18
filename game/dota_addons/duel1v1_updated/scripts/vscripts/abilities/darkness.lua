function Darkness(keys)
	local caster = keys.caster

	if caster ~= nil then
		-- Apply nightstalker night for 1 second repeatedly while the modifier is present
		-- This allows a script to remove the modifier to end the nightstalker night
		-- Also grant the caster unobstructed vision
		local apply_night = function()
			local linger_duration = 0.5

			GameRules:BeginNightstalkerNight(linger_duration)

			
			AddFOWViewer(
				caster:GetTeam(),
				caster:GetCenter(),
				caster:GetNightTimeVisionRange(),
				linger_duration,
				false
			)

			if caster:HasModifier("modifier_night_stalker_darkness") then
				return 0.4
			end
		end

		Timers:CreateTimer(apply_night)
	end
end