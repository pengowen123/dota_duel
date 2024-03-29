"use strict";


var DEATH_COLOR_OPACITY = 0.85;
var DISCONNECT_COLOR_OPACITY = 0.85;
var ABANDON_COLOR_OPACITY = 0.92;

var display_player_stats = false;
var player_stats = null;


// Initializes the top bar UI and logic
function Initialize()
{
	GameEvents.Subscribe("score_update", ScoreUpdate);
  GameEvents.Subscribe("rebuild_hero_lists", SetupHeroLists);
  GameEvents.Subscribe("update_hero_lists", UpdateHeroLists);
  GameEvents.Subscribe("start_game", HidePlayerStats);
  GameEvents.Subscribe("all_voted_rematch", HidePlayerStats);
  GameEvents.Subscribe("end_game", ShowPlayerStats);
  GameEvents.Subscribe("end_game_no_rematch", ShowPlayerStats);
  GameEvents.Subscribe("update_player_stats", UpdatePlayerStats);
  GameEvents.Subscribe("show_player_stats", ShowPlayerStats);
  GameEvents.Subscribe("start_round", HidePlayerStats);

  // Hide the default hero lists
  var topbar = $.GetContextPanel()
    .GetParent()
    .GetParent()
    .GetParent()
    .FindChildTraverse("topbar");

  EnableUIElement(topbar.FindChild("TopBarRadiantTeamContainer"), false);
  EnableUIElement(topbar.FindChild("TopBarDireTeamContainer"), false);
  // Also disable the "time until day/night time" display because it is useless in this mode
  EnableUIElement(topbar.FindChild("TimeUntil"), false);

  SetupHeroLists();
}


// Hides the respawn indicators and shows player stats
function ShowPlayerStats()
{
  display_player_stats = true;
  UpdateHeroLists();
}


// Stops hiding the respawn indicators and hides player stats
function HidePlayerStats()
{
  display_player_stats = false;
  UpdateHeroLists();
}


// Sets whether the player stats panels are visible
function SetPlayerStatsVisible(visible)
{
  for (var id = 25; id >= 0; id--) {
    if (Players.IsValidPlayerID(id))
    {
      var hero_slot = $("#" + id.toString());

      if (hero_slot === null)
      {
        continue;
      }

      var style = hero_slot.GetChild(2).style;
      if (visible)
      {
        style.visibility = "visible";
      }
      else
      {
        style.visibility = "collapse";
      }
    }
  }
}


// Updates the player stats and the stats display panels
// If `args` is null, uses the existing player stats and only updates the panels
function UpdatePlayerStats(args)
{
  if (args !== null)
  {
    player_stats = args.players;
  }

  if (player_stats === null)
  {
    return;
  }

  SetPlayerStatsVisible(display_player_stats);

  for (var id in player_stats) {
    var player = player_stats[id];

    var hero_slot = $("#" + id.toString());

    if (hero_slot === null)
    {
      continue;
    }

    var player_stats_panel = hero_slot.GetChild(2);

    player_stats_panel.GetChild(1).text = player.wins.toString();
    player_stats_panel.GetChild(4).text = player.losses.toString();
    player_stats_panel.GetChild(7).text = player.draws.toString();
  }
}


function ScoreUpdate(args)
{
	$("#ScoreRadiant").text = args.radiant.toString();
	$("#ScoreDire").text = args.dire.toString();
}


// Clears and sets up the hero lists
function SetupHeroLists()
{
  var hero_list_radiant = $("#HeroListRadiant");
  var hero_list_dire = $("#HeroListDire");

  // Clear hero lists before populating them
  hero_list_dire.RemoveAndDeleteChildren();
  hero_list_radiant.RemoveAndDeleteChildren();

  for (var id = 25; id >= 0; id--) {
    if (Players.IsValidPlayerID(id))
    {
      var team = Players.GetTeam(id);

      if (team === DOTATeam_t.DOTA_TEAM_GOODGUYS)
      {
        AddPlayer(hero_list_radiant, id);
      }
      else if (team === DOTATeam_t.DOTA_TEAM_BADGUYS)
      {
        AddPlayer(hero_list_dire, id);
      }
    }
  }

  UpdateHeroLists();
  UpdatePlayerStats(null);
}


// Creates a hero element under `parent`
function AddPlayer(parent, player_id)
{
  var element = $.CreatePanel("Panel", parent, player_id.toString());
  element.SetHasClass("HeroSlot", true);
  element.BLoadLayoutSnippet("HeroSlot");

  var hero_name = Players.GetPlayerSelectedHero(player_id);

  if (hero_name !== null)
  {
    var button = element.GetChild(0);
    button.GetChild(1).heroname = hero_name;
    // Convert to proper format
    button.GetChild(0).style.backgroundColor = GetHexPlayerColor(player_id);
    // Setup click handler per hero
    button.SetPanelEvent("onactivate", function()
    {
      Players.PlayerPortraitClicked(player_id, GameUI.IsControlDown(), GameUI.IsAltDown());
    });
  }
}


// Updates the hero lists (respawn timers, connection status, etc)
function UpdateHeroLists()
{
  SetPlayerStatsVisible(display_player_stats);

  for (var id = 25; id >= 0; id--) {
    if (Players.IsValidPlayerID(id))
    {
      var hero_slot = $("#" + id.toString());


      if (hero_slot === null)
      {
        continue;
      }

      var player_info = Game.GetPlayerInfo(id);

      var hero_image = hero_slot.GetChild(0).GetChild(1);
      hero_image.style.saturation = 1;

      var color_changer = hero_slot.GetChild(0).GetChild(2);
      var new_color_changer_opacity = 0;

      // Add one because the value is already rounded down
      var respawn_timer = player_info.player_respawn_seconds + 1;
      var respawn_timer_string = respawn_timer.toString();

      var respawn_timer_panel = hero_slot.GetChild(1);
      var respawn_timer_label = respawn_timer_panel.GetChild(0);

      var disconnect_indicator = hero_slot.GetChild(0).GetChild(3);

      var is_dead = respawn_timer > 0;

      if (is_dead && !display_player_stats)
      {
        // Make hero image gray-scale, darken it, and display respawn timer
        respawn_timer_panel.style.visibility = "visible";

        // Use a fixed string in this case instead of displaying large numbers
        if (respawn_timer > 5)
        {
          respawn_timer_string = "-";
        }

        hero_image.style.saturation = 0;
        new_color_changer_opacity = DEATH_COLOR_OPACITY;
        respawn_timer_label.text = respawn_timer_string;
      }
      else
      {
        respawn_timer_label.text = "0";
        respawn_timer_panel.style.visibility = "collapse";
      }

      // Dark hero image and display disconnect indicator if the player is disconnected
      if (player_info.player_connection_state
          === DOTAConnectionState_t.DOTA_CONNECTION_STATE_DISCONNECTED)
      {
        disconnect_indicator.style.opacity = 1;

        if (DISCONNECT_COLOR_OPACITY > new_color_changer_opacity)
        {
          new_color_changer_opacity = DISCONNECT_COLOR_OPACITY;
        }
      }
      else if (player_info.player_connection_state
          === DOTAConnectionState_t.DOTA_CONNECTION_STATE_ABANDONED)
      {
        disconnect_indicator.style.opacity = 1;

        if (ABANDON_COLOR_OPACITY > new_color_changer_opacity)
        {
          new_color_changer_opacity = ABANDON_COLOR_OPACITY;
        }
      }
      else
      {
        disconnect_indicator.style.opacity = 0;
      }

      color_changer.style.opacity = new_color_changer_opacity;
    }
  }
}


// Returns the color of the player in hex format (#RRGGBBAA)
function GetHexPlayerColor(player_id)
{
  var color_string = "#" + Players.GetPlayerColor(player_id).toString(16);

  if (color_string === null)
  {
    return "#DDDDDDFF"
  }
  else
  {
    return "#" + color_string.substring(7, 9)
               + color_string.substring(5, 7)
               + color_string.substring(3, 5)
               + color_string.substring(1, 3);
 }
}


// Sets the UI element's enabled and visible properties to the provided value
function EnableUIElement(element, enabled)
{
  element.enabled = enabled;
  element.visible = enabled;
}


Initialize();