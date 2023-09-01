// Customizes the pregame hero select screen
function SetupPregameHeroSelect()
{
  var pregame_panel = $.GetContextPanel()
    .GetParent()
    .GetParent()
    .GetParent()
    .FindChild("PreGame");

  var radiant_players = pregame_panel.FindChildTraverse("RadiantTeamPlayers");
  var dire_players = pregame_panel.FindChildTraverse("DireTeamPlayers");
  var header = radiant_players.GetParent();
  var header_center = header.FindChild("HeaderCenter");

  // Hide pregame minimap
  pregame_panel.FindChildTraverse("HeroPickMinimap").style.visibility = "collapse";

  // Hide dota plus ad
  pregame_panel.FindChildTraverse("FriendsAndFoes").style.visibility = "collapse";

  // Hide empty player slots
  RemoveUnusedTeamPlayerSlots(radiant_players);
  RemoveUnusedTeamPlayerSlots(dire_players);

  // Hide coach slots even if there are coaches to avoid formatting problems
  header.FindChild("RadiantCoachPlayer").style.visibility = "collapse";
  header.FindChild("DireCoachPlayer").style.visibility = "collapse";

  // Make everything symmetrical
  radiant_players.style.width = "45%";
  radiant_players.style.flowChildren = "left";
  dire_players.style.width = "45%";
  header_center.style.width = "10%";

  var fill_widths = header.FindChildrenWithClassTraverse("FillWidth");

  for (var i = fill_widths.length - 1; i >= 0; i--) {
    fill_widths[i].style.visibility = "collapse";
  }
}


// Removes unused player slots from the provided team panel
function RemoveUnusedTeamPlayerSlots(team_panel)
{
  var children = team_panel.Children();

  for (var i = children.length - 1; i >= 0; i--) {
    var player_name_label = children[i].FindChildTraverse("PlayerName");

    // Only consider player panels
    if (player_name_label === null)
    {
      continue;
    }

    // Steam names can't be fewer than 2 characters so this is safe
    if (player_name_label.text === "")
    {
      children[i].style.visibility = "collapse";
    }
  }
}

// Must be delayed by 1 frame to let player names be set
$.Schedule(0.1, SetupPregameHeroSelect);