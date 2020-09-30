"use strict";


var client_team = Players.GetTeam(Players.GetLocalPlayer());
var is_spectator_client = !(client_team === DOTATeam_t.DOTA_TEAM_GOODGUYS ||
													  client_team === DOTATeam_t.DOTA_TEAM_BADGUYS);


function Initialize()
{
	// Disable default neutral items tab and replace it with a custom one
	var root = $("#Root");

	// Don't do it more than once
	if (root === null)
	{
		return;
	}

	var neutral_shop_tab = $.GetContextPanel()
		.GetParent()
		.GetParent()
		.GetParent()
		.FindChildTraverse("GridNeutralsCategory");

	var children = neutral_shop_tab.Children();

	for (var i = children.length - 1; i >= 0; i--) {
		var style = children[i].style;
		style.width = "0%";
		style.height = "0%";
	}

	root.SetParent(neutral_shop_tab);
}


// Called when a player purchases a neutral item
function OnNeutralItemPurchased(item_name)
{
	var player_id = Players.GetLocalPlayer()
	var player = Players.GetPlayerHeroEntityIndex(player_id);

	// Spectators and players without a hero can't buy items
	if (player === -1 || is_spectator_client || Game.IsGamePaused())
	{
		return;
	}

	var selected_entity_index = Players.GetSelectedEntities(player_id)[0];

	var data = {
		"player_id": player_id,
		"item_name": item_name,
		"selected_entity_index": selected_entity_index,
	};
	GameEvents.SendCustomGameEventToServer("player_purchase_neutral_item", data);

	if (IsAtShop(player))
	{
		Game.EmitSound("General.Buy");
	}
}


// Returns whether the entity is at any shop
function IsAtShop(entity)
{
	for (var shop_type = 7; shop_type >= 1; shop_type--) {
		if (Entities.IsInRangeOfShop(entity, shop_type, false))
		{
			return true;
		}
	}

	return false;
}


Initialize();