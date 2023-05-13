-- A bot implementation for Arc Warden


BotArcWarden = {}
BotArcWarden.__index = BotArcWarden
BotBase:InitializeSubclass(BotArcWarden)


function BotArcWarden:New(player_id)
  local bot = BotBase.New(self, player_id)

  bot.ability_think_functions = {
    -- TODO
    self.ThinkTether,
    self.ThinkSpirits,
    self.ThinkOvercharge,
    self.ThinkRelocate,
  }

  -- The tempest double unit, if one exists and is alive
  bot.tempest_double = nil

  -- TODO: test all these more thoroughly
  bot.buff_power["modifier_arc_warden_magnetic_field_evasion"] = 5.0

  bot.debuff_power["modifier_arc_warden_flux"] = 5.0

  bot.ability_modifiers["arc_warden_magnetic_field"] = "modifier_arc_warden_magnetic_field_evasion"
  bot.ability_modifiers["arc_warden_flux"] = "modifier_arc_warden_flux"

  return bot
end
