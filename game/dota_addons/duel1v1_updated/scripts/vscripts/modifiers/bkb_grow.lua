if item_bkb_grow_modifier == nil then
    item_bkb_grow_modifier = class({})
end

function item_bkb_grow_modifier:IsHidden()
    return true
end

function item_bkb_grow_modifier:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MODEL_SCALE
    }
end

function item_bkb_grow_modifier:GetModifierModelScale()
	return 30.0
end