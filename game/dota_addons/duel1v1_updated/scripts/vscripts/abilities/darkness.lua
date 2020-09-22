function Darkness(keys)
	local caster = keys.caster

	if caster ~= nil then
		-- Apply nightstalker night for 1 second repeatedly while the modifier is present
		-- This allows a script to remove the modifier to end the nightstalker night
		local apply_night = function()
			local modifier = caster:FindModifierByName("modifier_night_stalker_darkness")

			if modifier then
				local time_remaining = modifier:GetRemainingTime()
				local night_duration = math.min(1.0, time_remaining)


				if night_duration > 0.0 then
					GameRules:BeginNightstalkerNight(night_duration)

					return 1.0
				end
			end
		end

		Timers:CreateTimer(apply_night)
	end
end