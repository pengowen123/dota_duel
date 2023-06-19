"use strict";


var hero_name_table = [
	"npc_dota_hero_ancient_apparition",
	"npc_dota_hero_bane",
	"npc_dota_hero_batrider",
	"npc_dota_hero_chen",
	"npc_dota_hero_crystal_maiden",
	"npc_dota_hero_dark_seer",
	"npc_dota_hero_dark_willow",
	"npc_dota_hero_dazzle",
	"npc_dota_hero_death_prophet",
	"npc_dota_hero_disruptor",
	"npc_dota_hero_enchantress",
	"npc_dota_hero_enigma",
	"npc_dota_hero_grimstroke",
	"npc_dota_hero_invoker",
	"npc_dota_hero_jakiro",
	"npc_dota_hero_keeper_of_the_light",
	"npc_dota_hero_leshrac",
	"npc_dota_hero_lich",
	"npc_dota_hero_lina",
	"npc_dota_hero_lion",
	"npc_dota_hero_muerta",
	"npc_dota_hero_furion",
	"npc_dota_hero_necrolyte",
	"npc_dota_hero_ogre_magi",
	"npc_dota_hero_oracle",
	"npc_dota_hero_obsidian_destroyer",
	"npc_dota_hero_puck",
	"npc_dota_hero_pugna",
	"npc_dota_hero_queenofpain",
	"npc_dota_hero_rubick",
	"npc_dota_hero_shadow_demon",
	"npc_dota_hero_shadow_shaman",
	"npc_dota_hero_silencer",
	"npc_dota_hero_skywrath_mage",
	"npc_dota_hero_storm_spirit",
	"npc_dota_hero_techies",
	"npc_dota_hero_tinker",
	"npc_dota_hero_visage",
	"npc_dota_hero_void_spirit",
	"npc_dota_hero_warlock",
	"npc_dota_hero_windrunner",
	"npc_dota_hero_winter_wyvern",
	"npc_dota_hero_witch_doctor",
	"npc_dota_hero_zuus",
	"npc_dota_hero_antimage",
	"npc_dota_hero_arc_warden",
	"npc_dota_hero_bloodseeker",
	"npc_dota_hero_bounty_hunter",
	"npc_dota_hero_broodmother",
	"npc_dota_hero_clinkz",
	"npc_dota_hero_drow_ranger",
	"npc_dota_hero_ember_spirit",
	"npc_dota_hero_faceless_void",
	"npc_dota_hero_gyrocopter",
	"npc_dota_hero_hoodwink",
	"npc_dota_hero_juggernaut",
	"npc_dota_hero_lone_druid",
	"npc_dota_hero_luna",
	"npc_dota_hero_medusa",
	"npc_dota_hero_meepo",
	"npc_dota_hero_mirana",
	"npc_dota_hero_morphling",
	"npc_dota_hero_monkey_king",
	"npc_dota_hero_naga_siren",
	"npc_dota_hero_nyx_assassin",
	"npc_dota_hero_pangolier",
	"npc_dota_hero_phantom_assassin",
	"npc_dota_hero_phantom_lancer",
	"npc_dota_hero_razor",
	"npc_dota_hero_riki",
	"npc_dota_hero_nevermore",
	"npc_dota_hero_slark",
	"npc_dota_hero_sniper",
	"npc_dota_hero_spectre",
	"npc_dota_hero_templar_assassin",
	"npc_dota_hero_terrorblade",
	"npc_dota_hero_troll_warlord",
	"npc_dota_hero_ursa",
	"npc_dota_hero_vengefulspirit",
	"npc_dota_hero_venomancer",
	"npc_dota_hero_viper",
	"npc_dota_hero_weaver",
	"npc_dota_hero_abaddon",
	"npc_dota_hero_alchemist",
	"npc_dota_hero_axe",
	"npc_dota_hero_beastmaster",
	"npc_dota_hero_brewmaster",
	"npc_dota_hero_bristleback",
	"npc_dota_hero_centaur",
	"npc_dota_hero_chaos_knight",
	"npc_dota_hero_rattletrap",
	"npc_dota_hero_dawnbreaker",
	"npc_dota_hero_doom_bringer",
	"npc_dota_hero_dragon_knight",
	"npc_dota_hero_earth_spirit",
	"npc_dota_hero_earthshaker",
	"npc_dota_hero_elder_titan",
	"npc_dota_hero_huskar",
	"npc_dota_hero_wisp",
	"npc_dota_hero_kunkka",
	"npc_dota_hero_legion_commander",
	"npc_dota_hero_life_stealer",
	"npc_dota_hero_lycan",
	"npc_dota_hero_magnataur",
	"npc_dota_hero_marci",
	"npc_dota_hero_mars",
	"npc_dota_hero_night_stalker",
	"npc_dota_hero_omniknight",
	"npc_dota_hero_phoenix",
	"npc_dota_hero_primal_beast",
	"npc_dota_hero_pudge",
	"npc_dota_hero_sand_king",
	"npc_dota_hero_slardar",
	"npc_dota_hero_snapfire",
	"npc_dota_hero_spirit_breaker",
	"npc_dota_hero_sven",
	"npc_dota_hero_tidehunter",
	"npc_dota_hero_shredder",
	"npc_dota_hero_tiny",
	"npc_dota_hero_treant",
	"npc_dota_hero_tusk",
	"npc_dota_hero_abyssal_underlord",
	"npc_dota_hero_undying",
	"npc_dota_hero_skeleton_king",
];


// Initializes the hero select UI and logic
function Initialize()
{
	GameEvents.Subscribe("select_timer_update", SelectTimerUpdate);
	GameEvents.Subscribe("start_game", StartGame);
	GameEvents.Subscribe("end_game_no_rematch", EndGame);
	GameEvents.Subscribe("all_voted_rematch", AllVotedRematch);

	// Due to the inconsistency of the `start_round` event being successfully sent at the
	// start of the game, just hide everything here
	EnableHeroSelectPanel(true);
}


// Called when a player selects a hero
function OnSelectHero(hero)
{
	var player_id = Players.GetLocalPlayer();
	var data = { "id": player_id, "hero": hero };

 	GameEvents.SendCustomGameEventToServer("player_select_hero_js", data);

  // Remove border from all hero buttons except for the selected one
	RemoveButtonBorders();
	SetHeroSelected(hero, true);
}


// Called when a player clicks the random hero button
function ChooseRandomHero()
{
	var index = Math.floor(Math.random() * (hero_name_table.length + 1));
	var hero = hero_name_table[index];
	OnSelectHero(hero);
}


// Called when the game ends (after players don't vote to rematch)
function EndGame()
{
	EnableHud(false);
	ToggleChatOffset(false);
}


// Called when the game or a rematch starts
function StartGame()
{
	EnableHeroSelectPanel(false);
	EnableHud(true);
	ToggleChatOffset(false);
	RemoveButtonBorders();
}


// Called when all players vote to rematch
function AllVotedRematch()
{
	EnableHeroSelectPanel(true);
	EnableHud(false);
	// Move chat down to make room for the hero select UI
	ToggleChatOffset(true);
}


// Removes the border from all hero buttons
function RemoveButtonBorders()
{
	for (var i = 0; i < hero_name_table.length; i++) {
		SetHeroSelected(hero_name_table[i], false);
	}
}


// Called when the game start timer updates
// Updates the number shown in the hero select UI
function SelectTimerUpdate(args)
{
	var timer = args.timer;
	var label = $("#SelectLabel");
	label.SetDialogVariableInt("seconds", timer);
}


// Sets the hero select panel's enabled and visible properties to the provided value
function EnableHeroSelectPanel(enabled)
{
	var panel = $("#HeroSelect");
	EnableElement(panel, enabled);
}


// Sets whether the hero is selected in the UI
function SetHeroSelected(hero_name, selected)
{
	var id = "#" + hero_name;
	var panel = $(id).GetParent();

	if (selected)
	{
		// panel.style.border = "5px solid #FF0000";
		panel.AddClass("HeroSelectAnimation");
	}
	else
	{
		// panel.style.border = "0px";
		panel.RemoveClass("HeroSelectAnimation");
	}
}


// Sets the lower half of the built-in HUD's enable and visible properties to the provided value
function EnableHud(enabled)
{
	var hud = $.GetContextPanel()
		.GetParent()
		.GetParent()
		.GetParent()
		.FindChildTraverse("HUDElements");

	var lower_hud = hud.FindChildTraverse("lower_hud");
	var minimap = hud.FindChildTraverse("minimap_container");

	EnableElement(lower_hud, enabled);
	EnableElement(minimap, enabled);
}


// Sets whether the chat is offset downwards to the bottom of the screen
function ToggleChatOffset(enabled)
{
	var chat = $.GetContextPanel()
		.GetParent()
		.GetParent()
		.GetParent()
		.FindChildTraverse("HUDElements")
		.FindChildTraverse("HudChat");

	var y = "-220px";
	if (enabled)
	{
	  y = "50px";
	}

	chat.style.y = y;
}


// Sets the element's enabled and visible properties to the provided value
function EnableElement(element, enabled)
{
	element.enabled = enabled;
	element.visible = enabled;
}


Initialize();