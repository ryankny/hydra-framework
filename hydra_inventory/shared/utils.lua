--[[
    Hydra Inventory - Shared Utilities

    Item registry indexing, weight calculations, and shared
    helper functions used by both server and client.
]]

Hydra = Hydra or {}
Hydra.Inventory = Hydra.Inventory or {}

-- ---------------------------------------------------------------------------
-- Build item index from config (O(1) lookup by name)
-- ---------------------------------------------------------------------------

local ItemRegistry = {}
local ItemsByCategory = {}

local function buildRegistry()
    -- Clear existing
    for k in pairs(ItemRegistry) do ItemRegistry[k] = nil end
    for k in pairs(ItemsByCategory) do ItemsByCategory[k] = nil end

    for _, item in ipairs(HydraConfig.Items) do
        item.stackable = item.stackable ~= false
        item.maxStack = item.maxStack or (item.stackable and 50 or 1)
        item.weight = item.weight or 0
        item.useable = item.useable or false
        item.unique = item.unique or false
        item.category = item.category or 'misc'
        item.image = item.image or (item.name .. '.png')
        item.description = item.description or ''
        -- rarity is optional, nil means no rarity display

        ItemRegistry[item.name] = item

        ItemsByCategory[item.category] = ItemsByCategory[item.category] or {}
        ItemsByCategory[item.category][#ItemsByCategory[item.category] + 1] = item
    end
end

-- Initial build
buildRegistry()

-- ---------------------------------------------------------------------------
-- Public item lookup functions
-- ---------------------------------------------------------------------------

function Hydra.Inventory.GetItemData(name)
    return ItemRegistry[name]
end

function Hydra.Inventory.ItemExists(name)
    return ItemRegistry[name] ~= nil
end

function Hydra.Inventory.GetItemsByCategory(category)
    return ItemsByCategory[category] or {}
end

function Hydra.Inventory.GetAllItems()
    return ItemRegistry
end

function Hydra.Inventory.GetItemLabel(name)
    local item = ItemRegistry[name]
    return item and item.label or name
end

function Hydra.Inventory.GetItemWeight(name)
    local item = ItemRegistry[name]
    return item and item.weight or 0
end

function Hydra.Inventory.IsUseable(name)
    local item = ItemRegistry[name]
    return item and item.useable or false
end

function Hydra.Inventory.IsConsumable(name)
    local item = ItemRegistry[name]
    return item and item.consumable ~= nil
end

function Hydra.Inventory.GetItemRarity(name)
    local item = ItemRegistry[name]
    if not item or not item.rarity then return nil end
    local rarityDef = HydraConfig.Inventory.rarity[item.rarity]
    return rarityDef and { key = item.rarity, label = rarityDef.label, color = rarityDef.color } or nil
end

--- Rebuild the item registry from HydraConfig.Items.
--- Call after modifying HydraConfig.Items at runtime.
function Hydra.Inventory.ReloadItems()
    buildRegistry()
    return #HydraConfig.Items
end

-- ---------------------------------------------------------------------------
-- Weight calculation helpers
-- ---------------------------------------------------------------------------

function Hydra.Inventory.CalculateWeight(items)
    local total = 0
    for _, item in pairs(items) do
        if item and item.name then
            local data = ItemRegistry[item.name]
            local weight = data and data.weight or 0
            total = total + (weight * (item.count or 1))
        end
    end
    return total
end

function Hydra.Inventory.CanCarry(items, addItem, addCount, maxWeight)
    local currentWeight = Hydra.Inventory.CalculateWeight(items)
    local itemData = ItemRegistry[addItem]
    if not itemData then return false end
    local addWeight = itemData.weight * (addCount or 1)
    return (currentWeight + addWeight) <= (maxWeight or HydraConfig.Inventory.player.maxWeight)
end

function Hydra.Inventory.CanStack(items, itemName, addCount)
    local itemData = ItemRegistry[itemName]
    if not itemData or not itemData.stackable then return false end

    -- Find existing stack with room
    for _, item in pairs(items) do
        if item.name == itemName and (item.count or 1) < itemData.maxStack then
            return true
        end
    end

    return true -- Can create new stack
end

-- ---------------------------------------------------------------------------
-- Slot helpers
-- ---------------------------------------------------------------------------

function Hydra.Inventory.FindFreeSlot(items, maxSlots)
    maxSlots = maxSlots or HydraConfig.Inventory.player.slots
    for i = 1, maxSlots do
        if not items[i] then return i end
    end
    return nil
end

function Hydra.Inventory.FindItemSlot(items, itemName)
    for slot, item in pairs(items) do
        if item and item.name == itemName then
            return slot
        end
    end
    return nil
end

function Hydra.Inventory.FindStackableSlot(items, itemName)
    local itemData = ItemRegistry[itemName]
    if not itemData or not itemData.stackable then return nil end

    for slot, item in pairs(items) do
        if item and item.name == itemName and (item.count or 1) < itemData.maxStack then
            return slot
        end
    end
    return nil
end

function Hydra.Inventory.CountItem(items, itemName)
    local total = 0
    for _, item in pairs(items) do
        if item and item.name == itemName then
            total = total + (item.count or 1)
        end
    end
    return total
end
