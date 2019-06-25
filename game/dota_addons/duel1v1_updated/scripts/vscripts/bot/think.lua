-- Points to escape to
ESCAPE_POINTS = {
	-- Dire spawn
	Vector(3328, 576, 128),
	-- Radiant spawn
	Vector(-1344, 640, 128),
	-- Bottom left
	Vector(275, 219, 384),
	-- Bottom right
	Vector(1252, -93, 384),
	-- Top left
	Vector(296, 1284, 384),
	-- Top right
	Vector(1777, 1047, 384),
}


-- Points to idle at
IDLE_POINTS = {
	-- Bottom left
	Vector(275, 219, 384),
	-- Bottom right
	Vector(1252, -93, 384),
	-- Top left
	Vector(296, 1284, 384),
	-- Top right
	Vector(1777, 1047, 384),
}


-- The X coordinate of the vertical center line of the map (splits map into left and right)
X_MAP_CENTER = 1050
-- The Y coordinate of the horizontal center line of the map (splits map into top and bottom)
Y_MAP_CENTER = 672


-- Performs all actions for the bot, called every THINK_INTERVAL seconds
function BotController:Think()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	if not bot_hero:IsAlive() then
		self.previous_health = nil
		return DEAD_THINK_INTERVAL
	end

	if not self.previous_health then
		self.previous_health = bot_hero:GetMaxHealth()
	end

	local current_health = bot_hero:GetHealth()
	-- HP loss per second based on the previous THINK_INTERVAL seconds
	local hp_loss_per_second = (self.previous_health - current_health) / THINK_INTERVAL

	self.previous_health = current_health

	local is_in_base = bot_hero:HasModifier("modifier_stun")
	-- If this function is run during the small time when the hero is replaced after each round, the
	-- observation updates may happen twice and inaccurately
	-- This might not be possible due to the hero replacement calls being sync, but even if it
	-- happens the consequences aren't too bad
	if is_in_base then
		if not self.purchased_items then
			-- End of round actions
			self.purchased_items = true

			local end_of_round = function()
				self:ThinkShop()

				if not self.first_round then
					self:UpdateObservationChances()
					self:ResetObservationFlags()
					self:ResetDisableCounts()
					self:ResetDamageCounts()
				end
				self.first_round = false
			end

			-- The above code must be delayed because this function could be called while the hero is being swapped
			Timers:CreateTimer(1.5, end_of_round)
		end
		self.time_spent_fighting = 0
	else
		self.purchased_items = false

		if not self.in_round then
			-- Start of round actions
			self.in_round = true

			self:EnterModeRun()
		end
	end

	self:GatherEnemyInfo()

	-- Update disable counters
	-- This isn't perfect, but it tends averages out to the correct value
	if (bot_hero:IsStunned() or bot_hero:IsMuted() or bot_hero:IsHexed())
			and not bot_hero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not bot_hero:HasModifier("modifier_naga_siren_song_of_the_siren") then
		local base_disable_duration = THINK_INTERVAL / self:GetStatusDurationMultiplier()
		self.seconds_disabled = self.seconds_disabled + base_disable_duration
		self.current_disable = self.current_disable + base_disable_duration
	else
		if self.current_disable > self.longest_disable then
			self.longest_disable = self.current_disable
		end
		self.current_disable = 0
	end

	-- Detect whether the enemy is dealing a dangerous amount of damage (deals with hiding strategies
	-- to manipulate round time, and helps deal with riki perma-invis talent)
	local current_ult_cooldown = bot_hero:GetAbilityByIndex(5):GetCooldownTimeRemaining()
	if current_ult_cooldown == 0 then
		-- If it is not on cooldown, use 23 seconds as the cooldown (aghs + octarine effective cooldown)
		current_ult_cooldown = 23
	end
	local significant_dps = bot_hero:GetHealth() / current_ult_cooldown

	if hp_loss_per_second > significant_dps then
		self.time_spent_fighting = self.time_spent_fighting + THINK_INTERVAL
		self.fighting = true
	else
		self.fighting = false
	end

	-- Detect short bursts of large amounts of damage such as versus PA or arc warden
	local dps_to_kill = bot_hero:GetMaxHealth() / EFFECTIVE_REINCARNATION_ULT_COOLDOWN
	local very_high_damage = dps_to_kill * VERY_HIGH_DAMAGE_THRESHOLD

	if hp_loss_per_second > very_high_damage then
		self.current_burst_duration = self.current_burst_duration + THINK_INTERVAL

		if self.current_burst_duration >= BURST_DURATION_THRESHOLD then
			self.observations["high_burst_damage"][2] = true
		end
	else
		self.current_burst_duration = self.current_burst_duration - THINK_INTERVAL
		if self.current_burst_duration < 0 then
			self.current_burst_duration = 0
		end
	end

	-- Run think function for the current mode
	if not is_in_base then
		if self.mode == MODE_RUN then
			self:ThinkModeRun()
		elseif self.mode == MODE_FIGHT then
			self:ThinkModeFight()
		end
	end

	return THINK_INTERVAL
end


-- Enters the `run` mode
function BotController:EnterModeRun()
	self.mode = MODE_RUN

	self:UpdatePositionGoal()
end


-- Enters the `fight` mode
function BotController:EnterModeFight()
	self.mode = MODE_FIGHT
end


-- Think function for the `run` mode
function BotController:ThinkModeRun()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)
	self:UpdatePositionGoal()
	bot_hero:MoveToPosition(self.position_goal)
end


-- Think function for the `fight` mode
function BotController:ThinkModeFight()
end


-- Updates the bot's position goal
function BotController:UpdatePositionGoal()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	-- Get dangerous visible enemy positions and count
	local num_enemies = 0
	local enemy_positions = self:GetDangerousVisibleEnemies()

	for i,enemy in pairs(enemy_positions) do
		num_enemies = num_enemies + 1
		enemy_positions[i] = enemy:GetAbsOrigin()
		print("enemy position: " .. tostring(enemy_positions[i]))
	end

	-- Remove this after debugging
	num_enemies = 0

	-- If no enemies are visible and the bot is not fighting, go stand at one of the idle points
	-- Also lock the position so it doesn't change until something new happens
	if num_enemies == 0 and not self.fighting then
		if not self.lock_position_goal then
			self.lock_position_goal = true
			self.position_goal = IDLE_POINTS[RandomInt(1, 4)]
			return
		end
	else
		self.lock_position_goal = false
	end

	-- Variables to store whether there is a dangerous unit in each quadrant of the map and
	-- surrounding the bot

	-- The quadrants centered around the bot
	local bot_quadrants = GetEnemyQuadrants(bot_hero:GetAbsOrigin(), enemy_positions)
	-- The quadrants of the map
	local map_quadrants = GetEnemyQuadrants(Vector(X_MAP_CENTER, Y_MAP_CENTER, 0), enemy_positions)
	-- local

	-- local empty_quadrant
	for i,quadrant in pairs({ "bl", "br", "tl", "tr" }) do
	end
end


-- Returns a list of visible enemies that can be expected to be dangerous
function BotController:GetDangerousVisibleEnemies()
	local bot_hero = PlayerResource:GetSelectedHeroEntity(self.bot_id)

	-- Enemy heroes and lone druid's spirit bear are considered dangerous
	local player_hero_name = PlayerResource:GetSelectedHeroEntity(self.player_id):GetName()
	local enemies = Entities:FindAllByName(player_hero_name)
	table.insert(enemies, Entities:FindByName(nil, "npc_dota_lone_druid_bear"))

	local visible = {}

	for i,enemy in pairs(enemies) do
		if bot_hero:CanEntityBeSeenByMyTeam(enemy) and enemy:IsAlive() then
			table.insert(visible, enemy)
		end
	end

	return visible
end


-- For each of the four quadrants centered at the provided location, returns whether an enemy lies
-- in it
function GetEnemyQuadrants(center, enemy_positions)
	local quadrants = {
		bl = false,
		br = false,
		tl = false,
		tr = false,
	}

	local center_x = center.x
	local center_y = center.y

	for i,position in pairs(enemy_positions) do
		if position.x < center_x then
			if position.y < center_y then
				quadrants.bl = true
			else
				quadrants.tl = true
			end
		else
			if position.y < center_y then
				quadrants.br = true
			else
				quadrants.tr = true
			end
		end
	end

	return quadrants
end
