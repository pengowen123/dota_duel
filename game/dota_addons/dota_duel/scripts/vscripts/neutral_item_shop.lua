-- Called when a player purchases a neutral item from the custom neutral item shop
function OnPlayerPurchaseNeutralItem(event_source_index, args)
  local player_id = args["player_id"]
  local player_team = PlayerResource:GetTeam(player_id)

  -- Only non-spectator players can purchase items
  if (player_team ~= DOTA_TEAM_GOODGUYS) and (player_team ~= DOTA_TEAM_BADGUYS) then
    return
  end

  local player = PlayerResource:GetSelectedHeroEntity(player_id)
  local item_name = args["item_name"]
  local selected_entity_index = args["selected_entity_index"]

  -- Players can't purchase neutral items without a hero
  if (not player) or (type(selected_entity_index) ~= "number") then
    return
  end

  local selected_entity = EntIndexToHScript(selected_entity_index)

  -- Neutral items can't be purchased during the round because of the way they are added to the
  -- inventory (the equipped neutral item is temporarily swapped out for the purchased item)
  if not IsAtShop(selected_entity) then
    return
  end

  if (selected_entity:GetTeam() == player:GetTeam())
    and selected_entity:CanSellItems()
    and selected_entity:GetPlayerOwnerID() == player_id then
    local is_hero_selected = selected_entity == player

    PurchaseNeutralItem(player, selected_entity, item_name, is_hero_selected)
  else
    PurchaseNeutralItem(player, player, item_name, true)
  end
end


-- Purchases a neutral item for `item_owner` and adds it to the inventory of `entity`
--
-- `use_stash` determines whether the item is added to the stash if the inventory is full (the
-- item is dropped otherwise)
function PurchaseNeutralItem(item_owner, entity, item_name, use_stash)
  -- Item slots to try to add the item to, in order
  item_slots = { NEUTRAL_ITEM_SLOT, 6, 7, 8 }

  local stash_slots = { 9, 10, 11, 12, 13, 14 }

  -- Only stash slots are considered when the entity is not at a shop
  if not IsAtShop(entity) then
    item_slots = stash_slots
  -- Stash slots are considered in addition to inventory slots if use_stash is true
  elseif use_stash then
    for i, slot in pairs(stash_slots) do
      table.insert(item_slots, slot)
    end
  end

  -- Find the first empty slot
  local empty_slot = nil

  for i, slot in pairs(item_slots) do
    if not entity:GetItemInSlot(slot) then
      empty_slot = slot
      break
    end
  end

  local item = CreateItem(item_name, item_owner, item_owner)

  -- Make the item sellable
  item:SetPurchaser(item_owner)

  -- Disable seer stone to prevent abuse (will be re-enabled at round start)
  if item:GetAbilityName() == "item_seer_stone" then
    item:SetActivated(false)
  end

  if empty_slot then
    -- Destroy equipped neutral item temporarily
    local equipped_item = entity:GetItemInSlot(NEUTRAL_ITEM_SLOT)
    local equipped_item_owner = nil
    local equipped_item_name = nil

    if equipped_item then
      equipped_item_name = equipped_item:GetAbilityName()
      equipped_item_owner = equipped_item:GetPurchaser()
      equipped_item:Destroy()
    end

    -- Add the item to the correct slot (requires neutral item slot to be empty)
    entity:AddItem(item)
    entity:SwapItems(NEUTRAL_ITEM_SLOT, empty_slot)

    -- Re-add equipped neutral item
    if equipped_item_name then
      local new_equipped_item = CreateItem(equipped_item_name, item_owner, item_owner)

      -- Makes the item sellable
      if equipped_item_owner then
        new_equipped_item:SetPurchaser(equipped_item_owner)
      else
        new_equipped_item:SetPurchaser(item_owner)
      end

      entity:AddItem(new_equipped_item)
    end
  else
    local position = nil

    if IsAtShop(entity) then
      position = entity:GetAbsOrigin()
    else
      local team = entity:GetTeam()

      local base_entity_name = nil

      if team == DOTA_TEAM_GOODGUYS then
        entity_name = "base_teleport_radiant"
      else
        entity_name = "base_teleport_dire"
      end

      position = Entities:FindByName(nil, entity_name):GetAbsOrigin()
    end

    CreateItemOnPositionSync(position, item)
  end
end


-- Returns whether the unit is in range of any shop
function IsAtShop(entity)
  for shop_type=1,7 do
    if entity:IsInRangeOfShop(shop_type, true) then
      return true
    end
  end

  return false
end