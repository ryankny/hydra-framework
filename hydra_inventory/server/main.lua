--[[
    Hydra Inventory - Server Main (Part 1)

    Core inventory management: persistence, CRUD operations,
    weight/slot validation, stacking, and money system.

    Part 2 covers: use handlers, events, module registration, exports.
]]

Hydra = Hydra or {}
Hydra.Inventory = Hydra.Inventory or {}

local cfg = HydraConfig.Inventory

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local inventories = {}      -- [identifier] = { items = {}, money = {} }
local useHandlers = {}      -- [itemName]   = callback
local moneyAccounts = {}    -- [identifier] = { cash = 0, bank = 0, crypto = 0 }
local openInventories = {}  -- [src]        = inventoryId

-- ---------------------------------------------------------------------------
-- Item enrichment — merge registry display data onto inventory items for NUI
-- ---------------------------------------------------------------------------

local function enrichItems(items)
    local enriched = {}
    for slot, item in pairs(items) do
        if item and item.name then
            local data = Hydra.Inventory.GetItemData(item.name)
            if data then
                enriched[slot] = {
                    name = item.name,
                    count = item.count,
                    metadata = item.metadata,
                    slot = item.slot or slot,
                    label = data.label,
                    weight = data.weight,
                    image = data.image,
                    category = data.category,
                    description = data.description,
                    useable = data.useable,
                    stackable = data.stackable,
                    rarity = data.rarity,
                }
            else
                enriched[slot] = item
            end
        end
    end
    return enriched
end

-- ---------------------------------------------------------------------------
-- Identifier helper
-- ---------------------------------------------------------------------------

--- Extract the license identifier from a player source.
--- @param src number Player server ID
--- @return string|nil identifier
local function getIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)
    if not identifiers then return nil end

    for _, id in ipairs(identifiers) do
        if string.sub(id, 1, 8) == 'license:' then
            return id
        end
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- COLLECTION REGISTRATION
-- ---------------------------------------------------------------------------

CreateThread(function()
    Wait(0)
    pcall(function()
        exports['hydra_data']:CreateCollection('inventories', {
            { name = 'identifier', type = 'VARCHAR(128)', index = true },
            { name = 'items',      type = 'LONGTEXT' },
            { name = 'money',      type = 'LONGTEXT' },
        })
    end)
end)

-- ---------------------------------------------------------------------------
-- PERSISTENCE
-- ---------------------------------------------------------------------------

--- Load a player inventory from the database via hydra_data.
--- @param identifier string License identifier
--- @return table inventory { items = {}, money = {} }
local function loadInventory(identifier)
    if inventories[identifier] then
        return inventories[identifier]
    end

    local items = {}
    local money = {}

    -- Initialize default money accounts
    for _, mType in ipairs(cfg.money.types) do
        money[mType.name] = 0
    end

    local ok, result = pcall(function()
        return exports['hydra_data']:FindOne('inventories', { identifier = identifier })
    end)

    if ok and result then
        local loadedItems = result.items
        local loadedMoney = result.money

        -- Decode JSON strings if needed
        if type(loadedItems) == 'string' then loadedItems = json.decode(loadedItems) end
        if type(loadedMoney) == 'string' then loadedMoney = json.decode(loadedMoney) end

        if loadedItems then
            for slot, item in pairs(loadedItems) do
                local slotNum = tonumber(slot) or slot
                if item and item.name and Hydra.Inventory.ItemExists(item.name) then
                    items[slotNum] = {
                        name = item.name,
                        count = item.count or 1,
                        metadata = item.metadata or {},
                        slot = slotNum,
                    }
                end
            end
        end

        if loadedMoney then
            for _, mType in ipairs(cfg.money.types) do
                if loadedMoney[mType.name] ~= nil then
                    money[mType.name] = tonumber(loadedMoney[mType.name]) or 0
                end
            end
        end
    end

    inventories[identifier] = { items = items, money = money }
    moneyAccounts[identifier] = money

    return inventories[identifier]
end

--- Save a player inventory to the database via hydra_data.
--- @param identifier string License identifier
local function saveInventory(identifier)
    local inv = inventories[identifier]
    if not inv then return end

    local itemsJson = json.encode(inv.items)
    local moneyJson = json.encode(inv.money)

    local ok, err = pcall(function()
        local existing = exports['hydra_data']:FindOne('inventories', { identifier = identifier })
        if existing then
            exports['hydra_data']:Update('inventories', { identifier = identifier }, {
                items = itemsJson,
                money = moneyJson,
            })
        else
            exports['hydra_data']:Create('inventories', {
                identifier = identifier,
                items = itemsJson,
                money = moneyJson,
            })
        end
    end)

    if not ok then
        print(('[Hydra:Inventory] Failed to save inventory for %s: %s'):format(identifier, tostring(err)))
    end
end

--- Auto-save thread: persists all loaded inventories every 5 minutes.
CreateThread(function()
    while true do
        Wait(5 * 60 * 1000) -- 5 minutes

        for identifier, _ in pairs(inventories) do
            saveInventory(identifier)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- CORE CRUD
-- ---------------------------------------------------------------------------

--- Get the full inventory table for a player.
--- @param src number Player server ID
--- @return table|nil inventory
function Hydra.Inventory.GetInventory(src)
    local identifier = getIdentifier(src)
    if not identifier then return nil end

    return loadInventory(identifier)
end

--- Add an item to a player's inventory with weight and slot validation.
--- Supports stacking onto existing slots and auto-finding free slots.
--- @param src number Player server ID
--- @param itemName string Item name from registry
--- @param count number Amount to add
--- @param metadata table|nil Optional metadata
--- @param slot number|nil Preferred slot (optional)
--- @return boolean success
--- @return string|nil reason
function Hydra.Inventory.AddItem(src, itemName, count, metadata, slot)
    if not src or not itemName then return false, 'invalid_params' end

    count = count or 1
    if count <= 0 then return false, 'invalid_count' end

    local itemData = Hydra.Inventory.GetItemData(itemName)
    if not itemData then return false, 'invalid_item' end

    local identifier = getIdentifier(src)
    if not identifier then return false, 'no_identifier' end

    local inv = loadInventory(identifier)
    local items = inv.items

    -- Weight check
    local maxWeight = Hydra.Inventory.GetMaxWeight(src)
    local currentWeight = Hydra.Inventory.GetWeight(src)
    local addWeight = itemData.weight * count

    if (currentWeight + addWeight) > maxWeight then
        return false, 'overweight'
    end

    local maxSlots = Hydra.Inventory.GetMaxSlots(src)
    local remaining = count
    metadata = metadata or {}

    -- If a specific slot was requested, try that slot first
    if slot and slot >= 1 and slot <= maxSlots then
        local existing = items[slot]
        if existing and existing.name == itemName and itemData.stackable then
            local canAdd = itemData.maxStack - (existing.count or 1)
            if canAdd > 0 then
                local toAdd = math.min(remaining, canAdd)
                existing.count = (existing.count or 1) + toAdd
                remaining = remaining - toAdd
            end
        elseif not existing then
            local toAdd = math.min(remaining, itemData.maxStack)
            items[slot] = {
                name = itemName,
                count = toAdd,
                metadata = metadata,
                slot = slot,
            }
            remaining = remaining - toAdd
        end

        if remaining <= 0 then
            TriggerClientEvent('hydra_inventory:client:itemAdded', src, itemName, count, metadata)
            return true
        end
    end

    -- Stack onto existing slots that have room
    if itemData.stackable then
        for s = 1, maxSlots do
            if remaining <= 0 then break end
            local existing = items[s]
            if existing and existing.name == itemName then
                local canAdd = itemData.maxStack - (existing.count or 1)
                if canAdd > 0 then
                    local toAdd = math.min(remaining, canAdd)
                    existing.count = (existing.count or 1) + toAdd
                    remaining = remaining - toAdd
                end
            end
        end
    end

    -- Fill empty slots with remaining items
    while remaining > 0 do
        local freeSlot = Hydra.Inventory.FindFreeSlot(items, maxSlots)
        if not freeSlot then
            -- Rollback is complex; we've already partially added. In practice
            -- the weight check above should have caught this. Log and continue.
            print(('[Hydra:Inventory] Warning: no free slots for %s adding %s x%d (partial add)'):format(
                identifier, itemName, remaining))
            return false, 'no_slots'
        end

        local toAdd = math.min(remaining, itemData.maxStack)
        items[freeSlot] = {
            name = itemName,
            count = toAdd,
            metadata = metadata,
            slot = freeSlot,
        }
        remaining = remaining - toAdd
    end

    TriggerClientEvent('hydra_inventory:client:itemAdded', src, itemName, count, metadata)
    return true
end

--- Remove an item from a player's inventory.
--- @param src number Player server ID
--- @param itemName string Item name
--- @param count number Amount to remove
--- @param slot number|nil Specific slot to remove from (optional)
--- @return boolean success
--- @return string|nil reason
function Hydra.Inventory.RemoveItem(src, itemName, count, slot)
    if not src or not itemName then return false, 'invalid_params' end

    count = count or 1
    if count <= 0 then return false, 'invalid_count' end

    local identifier = getIdentifier(src)
    if not identifier then return false, 'no_identifier' end

    local inv = loadInventory(identifier)
    local items = inv.items

    -- Check total available first
    local totalAvailable = Hydra.Inventory.CountItem(items, itemName)
    if totalAvailable < count then
        return false, 'not_enough'
    end

    local remaining = count

    -- If a specific slot was requested, try that first
    if slot then
        local item = items[slot]
        if item and item.name == itemName then
            local toRemove = math.min(remaining, item.count or 1)
            item.count = (item.count or 1) - toRemove
            remaining = remaining - toRemove

            if item.count <= 0 then
                items[slot] = nil
            end
        end
    end

    -- Remove from other slots if needed (iterate in order)
    if remaining > 0 then
        local maxSlots = Hydra.Inventory.GetMaxSlots(src)
        for s = 1, maxSlots do
            if remaining <= 0 then break end
            if s ~= slot then
                local item = items[s]
                if item and item.name == itemName then
                    local toRemove = math.min(remaining, item.count or 1)
                    item.count = (item.count or 1) - toRemove
                    remaining = remaining - toRemove

                    if item.count <= 0 then
                        items[s] = nil
                    end
                end
            end
        end
    end

    TriggerClientEvent('hydra_inventory:client:itemRemoved', src, itemName, count)
    return true
end

--- Set an item directly in a specific slot, replacing anything there.
--- @param src number Player server ID
--- @param slot number Slot index
--- @param item table|nil Item data { name, count, metadata } or nil to clear
--- @return boolean success
function Hydra.Inventory.SetItem(src, slot, item)
    if not src or not slot then return false end

    local identifier = getIdentifier(src)
    if not identifier then return false end

    local inv = loadInventory(identifier)

    if item then
        if not item.name or not Hydra.Inventory.ItemExists(item.name) then
            return false
        end
        inv.items[slot] = {
            name = item.name,
            count = item.count or 1,
            metadata = item.metadata or {},
            slot = slot,
        }
    else
        inv.items[slot] = nil
    end

    TriggerClientEvent('hydra_inventory:client:inventoryUpdated', src)
    return true
end

--- Clear a specific slot in a player's inventory.
--- @param src number Player server ID
--- @param slot number Slot index
--- @return boolean success
function Hydra.Inventory.ClearSlot(src, slot)
    if not src or not slot then return false end

    local identifier = getIdentifier(src)
    if not identifier then return false end

    local inv = loadInventory(identifier)
    inv.items[slot] = nil

    TriggerClientEvent('hydra_inventory:client:inventoryUpdated', src)
    return true
end

--- Check if a player has at least a certain count of an item.
--- @param src number Player server ID
--- @param itemName string Item name
--- @param count number|nil Minimum count (default 1)
--- @return boolean
function Hydra.Inventory.HasItem(src, itemName, count)
    count = count or 1

    local identifier = getIdentifier(src)
    if not identifier then return false end

    local inv = loadInventory(identifier)
    local total = Hydra.Inventory.CountItem(inv.items, itemName)

    return total >= count
end

--- Get the first item stack matching the given name.
--- @param src number Player server ID
--- @param itemName string Item name
--- @return table|nil item
function Hydra.Inventory.GetItem(src, itemName)
    local identifier = getIdentifier(src)
    if not identifier then return nil end

    local inv = loadInventory(identifier)

    for _, item in pairs(inv.items) do
        if item and item.name == itemName then
            return item
        end
    end

    return nil
end

--- Get the total count of an item across all slots.
--- @param src number Player server ID
--- @param itemName string Item name
--- @return number
function Hydra.Inventory.GetItemCount(src, itemName)
    local identifier = getIdentifier(src)
    if not identifier then return 0 end

    local inv = loadInventory(identifier)
    return Hydra.Inventory.CountItem(inv.items, itemName)
end

--- Get the current total weight of a player's inventory.
--- @param src number Player server ID
--- @return number weight in grams
function Hydra.Inventory.GetWeight(src)
    local identifier = getIdentifier(src)
    if not identifier then return 0 end

    local inv = loadInventory(identifier)
    return Hydra.Inventory.CalculateWeight(inv.items)
end

--- Get the maximum weight a player can carry, accounting for backpacks.
--- @param src number Player server ID
--- @return number maxWeight in grams
function Hydra.Inventory.GetMaxWeight(src)
    local baseWeight = cfg.player.maxWeight

    local identifier = getIdentifier(src)
    if not identifier then return baseWeight end

    local inv = loadInventory(identifier)

    -- Check for equipped backpacks that increase carry weight
    for _, item in pairs(inv.items) do
        if item and item.name then
            local data = Hydra.Inventory.GetItemData(item.name)
            if data and data.backpack and data.backpack.extraWeight then
                baseWeight = baseWeight + data.backpack.extraWeight
                break -- Only one backpack bonus applies
            end
        end
    end

    return baseWeight
end

--- Get the maximum number of slots a player has, accounting for backpacks.
--- @param src number Player server ID
--- @return number maxSlots
function Hydra.Inventory.GetMaxSlots(src)
    local baseSlots = cfg.player.slots

    local identifier = getIdentifier(src)
    if not identifier then return baseSlots end

    local inv = loadInventory(identifier)

    -- Check for equipped backpacks that add extra slots
    for _, item in pairs(inv.items) do
        if item and item.name then
            local data = Hydra.Inventory.GetItemData(item.name)
            if data and data.backpack and data.backpack.extraSlots then
                baseSlots = baseSlots + data.backpack.extraSlots
                break -- Only one backpack bonus applies
            end
        end
    end

    return baseSlots
end

--- Check if a player can carry a given amount of an item.
--- Validates both weight and slot availability.
--- @param src number Player server ID
--- @param itemName string Item name
--- @param count number Amount
--- @return boolean
function Hydra.Inventory.CanCarry(src, itemName, count)
    count = count or 1

    local itemData = Hydra.Inventory.GetItemData(itemName)
    if not itemData then return false end

    local identifier = getIdentifier(src)
    if not identifier then return false end

    local inv = loadInventory(identifier)
    local items = inv.items

    -- Weight check
    local maxWeight = Hydra.Inventory.GetMaxWeight(src)
    local currentWeight = Hydra.Inventory.CalculateWeight(items)
    local addWeight = itemData.weight * count

    if (currentWeight + addWeight) > maxWeight then
        return false
    end

    -- Slot availability check: simulate adding the items
    local maxSlots = Hydra.Inventory.GetMaxSlots(src)
    local remaining = count

    if itemData.stackable then
        for s = 1, maxSlots do
            if remaining <= 0 then break end
            local existing = items[s]
            if existing and existing.name == itemName then
                local canAdd = itemData.maxStack - (existing.count or 1)
                if canAdd > 0 then
                    remaining = remaining - math.min(remaining, canAdd)
                end
            end
        end
    end

    -- Count free slots needed for the rest
    if remaining > 0 then
        local freeSlotsNeeded = math.ceil(remaining / itemData.maxStack)
        local freeSlots = 0
        for s = 1, maxSlots do
            if not items[s] then
                freeSlots = freeSlots + 1
            end
        end
        if freeSlots < freeSlotsNeeded then
            return false
        end
    end

    return true
end

--- Move items from one slot to another, optionally to a different inventory.
--- @param src number Player server ID
--- @param fromSlot number Source slot
--- @param toSlot number Destination slot
--- @param count number|nil Amount to move (nil = all)
--- @param targetInv string|nil Target inventory identifier (nil = same inventory)
--- @return boolean success
--- @return string|nil reason
function Hydra.Inventory.MoveItem(src, fromSlot, toSlot, count, targetInv)
    if not src or not fromSlot or not toSlot then return false, 'invalid_params' end

    local identifier = getIdentifier(src)
    if not identifier then return false, 'no_identifier' end

    local srcInv = loadInventory(identifier)
    local srcItems = srcInv.items
    local fromItem = srcItems[fromSlot]

    if not fromItem then return false, 'empty_slot' end

    count = count or fromItem.count or 1
    if count <= 0 then return false, 'invalid_count' end
    if count > (fromItem.count or 1) then return false, 'not_enough' end

    -- Determine destination inventory
    local dstItems
    local dstMaxSlots
    local dstMaxWeight

    if targetInv and targetInv ~= identifier then
        local dstInv = inventories[targetInv]
        if not dstInv then return false, 'target_not_found' end
        dstItems = dstInv.items
        -- For external inventories, use their configured limits
        -- This supports stash/vehicle inventories that are registered in the table
        dstMaxSlots = cfg.player.slots
        dstMaxWeight = cfg.player.maxWeight
    else
        dstItems = srcItems
        dstMaxSlots = Hydra.Inventory.GetMaxSlots(src)
        dstMaxWeight = Hydra.Inventory.GetMaxWeight(src)
    end

    if toSlot < 1 or toSlot > dstMaxSlots then return false, 'invalid_slot' end

    local toItem = dstItems[toSlot]
    local itemData = Hydra.Inventory.GetItemData(fromItem.name)
    if not itemData then return false, 'invalid_item' end

    -- Case 1: Destination slot is empty
    if not toItem then
        if count == (fromItem.count or 1) then
            -- Move entire stack
            dstItems[toSlot] = {
                name = fromItem.name,
                count = fromItem.count or 1,
                metadata = fromItem.metadata or {},
                slot = toSlot,
            }
            srcItems[fromSlot] = nil
        else
            -- Split stack
            dstItems[toSlot] = {
                name = fromItem.name,
                count = count,
                metadata = fromItem.metadata or {},
                slot = toSlot,
            }
            fromItem.count = (fromItem.count or 1) - count
            if fromItem.count <= 0 then
                srcItems[fromSlot] = nil
            end
        end

        TriggerClientEvent('hydra_inventory:client:inventoryUpdated', src)
        return true
    end

    -- Case 2: Same item, stackable - merge
    if toItem.name == fromItem.name and itemData.stackable then
        local canAdd = itemData.maxStack - (toItem.count or 1)
        if canAdd <= 0 then return false, 'stack_full' end

        local toMove = math.min(count, canAdd)
        toItem.count = (toItem.count or 1) + toMove
        fromItem.count = (fromItem.count or 1) - toMove

        if fromItem.count <= 0 then
            srcItems[fromSlot] = nil
        end

        TriggerClientEvent('hydra_inventory:client:inventoryUpdated', src)
        return true
    end

    -- Case 3: Different items, swap only if moving entire stack
    if count == (fromItem.count or 1) then
        return Hydra.Inventory.SwapItems(src, fromSlot, toSlot)
    end

    return false, 'cannot_merge'
end

--- Swap two items between slots in the player's inventory.
--- @param src number Player server ID
--- @param slot1 number First slot
--- @param slot2 number Second slot
--- @return boolean success
--- @return string|nil reason
function Hydra.Inventory.SwapItems(src, slot1, slot2)
    if not src or not slot1 or not slot2 then return false, 'invalid_params' end
    if slot1 == slot2 then return true end

    local identifier = getIdentifier(src)
    if not identifier then return false, 'no_identifier' end

    local inv = loadInventory(identifier)
    local items = inv.items

    local item1 = items[slot1]
    local item2 = items[slot2]

    -- Update slot references
    if item1 then item1.slot = slot2 end
    if item2 then item2.slot = slot1 end

    items[slot1] = item2
    items[slot2] = item1

    TriggerClientEvent('hydra_inventory:client:inventoryUpdated', src)
    return true
end

--- Clear all items from a player's inventory.
--- @param src number Player server ID
--- @return boolean success
function Hydra.Inventory.ClearInventory(src)
    local identifier = getIdentifier(src)
    if not identifier then return false end

    local inv = loadInventory(identifier)
    inv.items = {}

    TriggerClientEvent('hydra_inventory:client:inventoryUpdated', src)
    return true
end

-- ---------------------------------------------------------------------------
-- MONEY SYSTEM
-- ---------------------------------------------------------------------------

--- Get the amount of money for a given type.
--- When cashAsItem is enabled, 'cash' returns the count of cash items.
--- @param src number Player server ID
--- @param moneyType string 'cash', 'bank', or 'crypto'
--- @return number
function Hydra.Inventory.GetMoney(src, moneyType)
    if not src or not moneyType then return 0 end

    -- When cash-as-item is enabled, cash balance is the item count
    if moneyType == 'cash' and cfg.money.cashAsItem then
        return Hydra.Inventory.GetItemCount(src, cfg.money.cashItemName)
    end

    local identifier = getIdentifier(src)
    if not identifier then return 0 end

    local inv = loadInventory(identifier)
    return inv.money[moneyType] or 0
end

--- Add money to a player.
--- @param src number Player server ID
--- @param moneyType string 'cash', 'bank', or 'crypto'
--- @param amount number Amount to add
--- @param reason string|nil Reason for the transaction
--- @return boolean success
--- @return string|nil reason
function Hydra.Inventory.AddMoney(src, moneyType, amount, reason)
    if not src or not moneyType or not amount then return false, 'invalid_params' end

    amount = tonumber(amount) or 0
    if amount <= 0 then return false, 'invalid_amount' end

    -- Cash as physical item
    if moneyType == 'cash' and cfg.money.cashAsItem then
        local ok, err = Hydra.Inventory.AddItem(src, cfg.money.cashItemName, math.floor(amount))
        if not ok then return false, err end

        TriggerClientEvent('hydra_inventory:client:moneyChanged', src, moneyType, amount, 'add', reason)
        return true
    end

    local identifier = getIdentifier(src)
    if not identifier then return false, 'no_identifier' end

    local inv = loadInventory(identifier)

    if inv.money[moneyType] == nil then return false, 'invalid_type' end

    inv.money[moneyType] = inv.money[moneyType] + amount

    TriggerClientEvent('hydra_inventory:client:moneyChanged', src, moneyType, amount, 'add', reason)
    return true
end

--- Remove money from a player.
--- @param src number Player server ID
--- @param moneyType string 'cash', 'bank', or 'crypto'
--- @param amount number Amount to remove
--- @param reason string|nil Reason for the transaction
--- @return boolean success
--- @return string|nil reason
function Hydra.Inventory.RemoveMoney(src, moneyType, amount, reason)
    if not src or not moneyType or not amount then return false, 'invalid_params' end

    amount = tonumber(amount) or 0
    if amount <= 0 then return false, 'invalid_amount' end

    -- Cash as physical item
    if moneyType == 'cash' and cfg.money.cashAsItem then
        local currentCash = Hydra.Inventory.GetItemCount(src, cfg.money.cashItemName)
        if currentCash < math.floor(amount) then return false, 'not_enough' end

        local ok, err = Hydra.Inventory.RemoveItem(src, cfg.money.cashItemName, math.floor(amount))
        if not ok then return false, err end

        TriggerClientEvent('hydra_inventory:client:moneyChanged', src, moneyType, amount, 'remove', reason)
        return true
    end

    local identifier = getIdentifier(src)
    if not identifier then return false, 'no_identifier' end

    local inv = loadInventory(identifier)

    if inv.money[moneyType] == nil then return false, 'invalid_type' end
    if inv.money[moneyType] < amount then return false, 'not_enough' end

    inv.money[moneyType] = inv.money[moneyType] - amount

    TriggerClientEvent('hydra_inventory:client:moneyChanged', src, moneyType, amount, 'remove', reason)
    return true
end

--- Set a player's money to an exact value.
--- @param src number Player server ID
--- @param moneyType string 'cash', 'bank', or 'crypto'
--- @param amount number New balance
--- @return boolean success
--- @return string|nil reason
function Hydra.Inventory.SetMoney(src, moneyType, amount)
    if not src or not moneyType or not amount then return false, 'invalid_params' end

    amount = tonumber(amount) or 0
    if amount < 0 then return false, 'invalid_amount' end

    -- Cash as physical item: clear existing and add new amount
    if moneyType == 'cash' and cfg.money.cashAsItem then
        local currentCash = Hydra.Inventory.GetItemCount(src, cfg.money.cashItemName)
        if currentCash > 0 then
            Hydra.Inventory.RemoveItem(src, cfg.money.cashItemName, currentCash)
        end
        if amount > 0 then
            local ok, err = Hydra.Inventory.AddItem(src, cfg.money.cashItemName, math.floor(amount))
            if not ok then return false, err end
        end

        TriggerClientEvent('hydra_inventory:client:moneyChanged', src, moneyType, amount, 'set')
        return true
    end

    local identifier = getIdentifier(src)
    if not identifier then return false, 'no_identifier' end

    local inv = loadInventory(identifier)

    if inv.money[moneyType] == nil then return false, 'invalid_type' end

    inv.money[moneyType] = amount

    TriggerClientEvent('hydra_inventory:client:moneyChanged', src, moneyType, amount, 'set')
    return true
end

--- Transfer money from one player to another.
--- @param src number Sender server ID
--- @param target number Receiver server ID
--- @param moneyType string 'cash', 'bank', or 'crypto'
--- @param amount number Amount to transfer
--- @return boolean success
--- @return string|nil reason
function Hydra.Inventory.TransferMoney(src, target, moneyType, amount)
    if not src or not target or not moneyType or not amount then return false, 'invalid_params' end

    amount = tonumber(amount) or 0
    if amount <= 0 then return false, 'invalid_amount' end

    -- Validate target is a connected player
    if not GetPlayerName(target) then return false, 'target_offline' end

    -- Check sender has enough
    local senderBalance = Hydra.Inventory.GetMoney(src, moneyType)
    if senderBalance < amount then return false, 'not_enough' end

    -- Remove from sender
    local ok, err = Hydra.Inventory.RemoveMoney(src, moneyType, amount, ('transfer_to_%d'):format(target))
    if not ok then return false, err end

    -- Add to receiver
    local ok2, err2 = Hydra.Inventory.AddMoney(target, moneyType, amount, ('transfer_from_%d'):format(src))
    if not ok2 then
        -- Refund sender on failure
        Hydra.Inventory.AddMoney(src, moneyType, amount, 'transfer_refund')
        return false, err2
    end

    return true
end

-- =========================================================================
-- USE / CONSUME SYSTEM
-- =========================================================================

--- Register a custom use handler for an item
function Hydra.Inventory.RegisterUseHandler(itemName, handler)
    if type(handler) ~= 'function' then return end
    useHandlers[itemName] = handler
end

--- Internal: default consumable handler
local function defaultConsumeHandler(src, item, slot)
    local itemData = Hydra.Inventory.GetItemData(item.name)
    if not itemData or not itemData.consumable then return end

    local consumable = itemData.consumable

    -- Tell client to play animation/prop/progressbar
    TriggerClientEvent('hydra:inventory:client:consume', src, {
        item = item,
        consumable = consumable,
    })

    -- Completion is handled by client callback event
end

--- Internal: apply consumable effects after client confirms completion
local function applyConsumableEffects(src, itemName)
    local itemData = Hydra.Inventory.GetItemData(itemName)
    if not itemData or not itemData.consumable then return end

    local consumable = itemData.consumable

    -- Apply status effects via hydra_status
    if consumable.status then
        for stat, value in pairs(consumable.status) do
            pcall(function()
                if value > 0 then
                    exports['hydra_status']:Add(src, stat, value)
                else
                    exports['hydra_status']:Remove(src, stat, math.abs(value))
                end
            end)
        end
    end

    -- Apply special effects
    if consumable.effects then
        local ped = GetPlayerPed(src)

        if consumable.effects.heal and consumable.effects.heal > 0 then
            local health = GetEntityHealth(ped)
            local maxHealth = 200
            SetEntityHealth(ped, math.min(health + consumable.effects.heal, maxHealth))
        end

        if consumable.effects.armour and consumable.effects.armour > 0 then
            local armour = GetPedArmour(ped)
            SetPedArmour(ped, math.min(armour + consumable.effects.armour, 100))
        end

        if consumable.effects.stamina then
            pcall(function()
                exports['hydra_status']:Add(src, 'stamina', consumable.effects.stamina)
            end)
        end

        -- Drunk / screen effects handled client-side
        if consumable.effects.drunk or consumable.effects.screen_effect then
            TriggerClientEvent('hydra:inventory:client:effect', src, consumable.effects)
        end
    end

    -- Update HUD
    pcall(function()
        exports['hydra_hud']:UpdateStatus(src)
    end)
end

-- Consume completion from client
RegisterNetEvent('hydra:inventory:consume:complete', function(itemName)
    local src = source
    if type(itemName) ~= 'string' then return end

    -- Verify player still has the item
    if not Hydra.Inventory.HasItem(src, itemName, 1) then return end

    -- Remove one of the consumed item
    Hydra.Inventory.RemoveItem(src, itemName, 1)

    -- Apply effects
    applyConsumableEffects(src, itemName)

    -- Notify
    pcall(function()
        exports['hydra_notify']:Send(src, {
            title = 'Used',
            message = Hydra.Inventory.GetItemLabel(itemName),
            type = 'success',
            duration = 3000,
        })
    end)
end)

RegisterNetEvent('hydra:inventory:consume:cancel', function(itemName)
    -- Consume was cancelled — no item removal, no effects
end)

-- =========================================================================
-- NUI / CLIENT COMMUNICATION EVENTS
-- =========================================================================

--- Open player inventory
RegisterNetEvent('hydra:inventory:open', function()
    local src = source
    local identifier = getIdentifier(src)
    if not identifier then return end

    local inv = inventories[identifier]
    if not inv then return end

    local weight = Hydra.Inventory.GetWeight(src)
    local maxWeight = Hydra.Inventory.GetMaxWeight(src)
    local maxSlots = Hydra.Inventory.GetMaxSlots(src)
    local money = moneyAccounts[identifier] or { cash = 0, bank = 0, crypto = 0 }

    -- If cashAsItem, calculate cash from inventory
    if cfg.money.cashAsItem then
        money.cash = Hydra.Inventory.GetItemCount(src, cfg.money.cashItemName or 'cash')
    end

    TriggerClientEvent('hydra:inventory:client:open', src, {
        playerInventory = {
            items = enrichItems(inv.items),
            maxSlots = maxSlots,
            maxWeight = maxWeight,
            weight = weight,
        },
        money = money,
    })

    openInventories[src] = { type = 'player', identifier = identifier }
end)

--- Close inventory
RegisterNetEvent('hydra:inventory:close', function()
    local src = source
    local open = openInventories[src]
    if open then
        local identifier = getIdentifier(src)
        if identifier then
            saveInventory(identifier)
        end
        openInventories[src] = nil
    end
end)

--- Move item (drag-drop from NUI)
RegisterNetEvent('hydra:inventory:move', function(data)
    local src = source
    if type(data) ~= 'table' then return end

    local fromInv = data.fromInventory or 'player'
    local toInv = data.toInventory or 'player'
    local fromSlot = tonumber(data.fromSlot)
    local toSlot = tonumber(data.toSlot)
    local count = tonumber(data.count)

    if not fromSlot or not toSlot then return end

    local identifier = getIdentifier(src)
    if not identifier then return end

    -- Player to player move
    if fromInv == 'player' and toInv == 'player' then
        if count and count > 0 then
            -- Split operation
            local inv = inventories[identifier]
            if not inv then return end
            local item = inv.items[fromSlot]
            if not item or (item.count or 1) < count then return end

            -- Remove from source
            local remaining = (item.count or 1) - count
            if remaining <= 0 then
                inv.items[fromSlot] = nil
            else
                inv.items[fromSlot] = { name = item.name, count = remaining, metadata = item.metadata }
            end

            -- Add to destination
            local destItem = inv.items[toSlot]
            if destItem and destItem.name == item.name then
                local itemData = Hydra.Inventory.GetItemData(item.name)
                local maxStack = itemData and itemData.maxStack or 50
                inv.items[toSlot] = { name = item.name, count = math.min((destItem.count or 1) + count, maxStack), metadata = destItem.metadata }
            elseif not destItem then
                inv.items[toSlot] = { name = item.name, count = count, metadata = item.metadata }
            else
                -- Swap
                inv.items[fromSlot] = destItem
                inv.items[toSlot] = { name = item.name, count = count, metadata = item.metadata }
            end
        else
            Hydra.Inventory.MoveItem(src, fromSlot, toSlot, nil, nil)
        end
    elseif fromInv == 'player' and toInv == 'secondary' then
        -- Move from player to secondary (trunk/stash/drop)
        local open = openInventories[src]
        if not open or not open.secondaryId then return end
        local inv = inventories[identifier]
        if not inv then return end
        local item = inv.items[fromSlot]
        if not item then return end

        local moveCount = count or item.count or 1

        -- Get secondary inventory based on type
        local secInv
        if open.type == 'trunk' or open.type == 'glovebox' then
            secInv = Hydra.Inventory.GetVehicleInventory and Hydra.Inventory.GetVehicleInventory(open.secondaryId, open.type)
        elseif open.type == 'stash' then
            secInv = Hydra.Inventory.GetStash and Hydra.Inventory.GetStash(open.secondaryId)
        end
        if not secInv then return end

        -- Weight check on secondary
        local itemData = Hydra.Inventory.GetItemData(item.name)
        local addWeight = (itemData and itemData.weight or 0) * moveCount
        local secWeight = Hydra.Inventory.CalculateWeight(secInv.items)
        if secWeight + addWeight > secInv.maxWeight then return end

        -- Find slot in secondary
        local targetSlot = toSlot
        if not targetSlot or secInv.items[targetSlot] then
            targetSlot = Hydra.Inventory.FindStackableSlot(secInv.items, item.name) or Hydra.Inventory.FindFreeSlot(secInv.items, secInv.maxSlots)
        end
        if not targetSlot then return end

        -- Transfer
        local remaining = (item.count or 1) - moveCount
        if remaining <= 0 then
            inv.items[fromSlot] = nil
        else
            inv.items[fromSlot] = { name = item.name, count = remaining, metadata = item.metadata }
        end

        local existing = secInv.items[targetSlot]
        if existing and existing.name == item.name then
            existing.count = (existing.count or 1) + moveCount
        else
            secInv.items[targetSlot] = { name = item.name, count = moveCount, metadata = item.metadata }
        end

    elseif fromInv == 'secondary' and toInv == 'player' then
        -- Move from secondary to player
        local open = openInventories[src]
        if not open or not open.secondaryId then return end

        local secInv
        if open.type == 'trunk' or open.type == 'glovebox' then
            secInv = Hydra.Inventory.GetVehicleInventory and Hydra.Inventory.GetVehicleInventory(open.secondaryId, open.type)
        elseif open.type == 'stash' then
            secInv = Hydra.Inventory.GetStash and Hydra.Inventory.GetStash(open.secondaryId)
        end
        if not secInv then return end

        local item = secInv.items[fromSlot]
        if not item then return end

        local moveCount = count or item.count or 1

        -- Weight check on player
        if not Hydra.Inventory.CanCarry(src, item.name, moveCount) then return end

        -- Transfer
        local ok = Hydra.Inventory.AddItem(src, item.name, moveCount, item.metadata)
        if ok then
            local remaining = (item.count or 1) - moveCount
            if remaining <= 0 then
                secInv.items[fromSlot] = nil
            else
                secInv.items[fromSlot] = { name = item.name, count = remaining, metadata = item.metadata }
            end
        end
    end

    -- Send updated inventories to client
    local inv = inventories[identifier]
    if inv then
        TriggerClientEvent('hydra:inventory:client:update', src, {
            items = enrichItems(inv.items),
            weight = Hydra.Inventory.GetWeight(src),
            maxWeight = Hydra.Inventory.GetMaxWeight(src),
        })
    end
end)

--- Use item
RegisterNetEvent('hydra:inventory:use', function(slot)
    local src = source
    slot = tonumber(slot)
    if not slot then return end

    local identifier = getIdentifier(src)
    if not identifier or not inventories[identifier] then return end

    local item = inventories[identifier].items[slot]
    if not item then return end

    local itemData = Hydra.Inventory.GetItemData(item.name)
    if not itemData or not itemData.useable then return end

    -- Custom handler takes priority
    if useHandlers[item.name] then
        useHandlers[item.name](src, item, slot)
        return
    end

    -- Default consumable handler
    if itemData.consumable then
        defaultConsumeHandler(src, item, slot)
        return
    end
end)

--- Drop item
RegisterNetEvent('hydra:inventory:drop', function(slot, count)
    local src = source
    slot = tonumber(slot)
    count = tonumber(count) or 1
    if not slot then return end

    local identifier = getIdentifier(src)
    if not identifier or not inventories[identifier] then return end

    local item = inventories[identifier].items[slot]
    if not item or (item.count or 1) < count then return end

    -- Remove from inventory
    local remaining = (item.count or 1) - count
    if remaining <= 0 then
        inventories[identifier].items[slot] = nil
    else
        inventories[identifier].items[slot].count = remaining
    end

    -- Create world drop
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local dropItems = { { name = item.name, count = count, metadata = item.metadata } }

    if Hydra.Inventory.CreateDrop then
        Hydra.Inventory.CreateDrop(src, dropItems, coords)
    end

    -- Update client
    TriggerClientEvent('hydra:inventory:client:update', src, {
        items = enrichItems(inventories[identifier].items),
        weight = Hydra.Inventory.GetWeight(src),
    })
end)

-- =========================================================================
-- GIVE SYSTEM
-- =========================================================================

RegisterNetEvent('hydra:inventory:give', function(targetId, slot, count)
    local src = source
    targetId = tonumber(targetId)
    slot = tonumber(slot)
    count = tonumber(count) or 1
    if not targetId or not slot then return end

    local srcId = getIdentifier(src)
    local tgtId = getIdentifier(targetId)
    if not srcId or not tgtId then return end
    if not inventories[srcId] or not inventories[tgtId] then return end

    local item = inventories[srcId].items[slot]
    if not item or (item.count or 1) < count then return end

    -- Weight check on target
    if not Hydra.Inventory.CanCarry(targetId, item.name, count) then
        pcall(function()
            exports['hydra_notify']:Send(src, { title = 'Inventory', message = 'They cannot carry this item', type = 'error' })
        end)
        return
    end

    -- Transfer
    local remaining = (item.count or 1) - count
    if remaining <= 0 then
        inventories[srcId].items[slot] = nil
    else
        inventories[srcId].items[slot].count = remaining
    end

    Hydra.Inventory.AddItem(targetId, item.name, count, item.metadata)

    -- Play give animations
    TriggerClientEvent('hydra:inventory:client:giveAnim', src)
    TriggerClientEvent('hydra:inventory:client:receiveAnim', targetId)

    -- Notify both
    local label = Hydra.Inventory.GetItemLabel(item.name)
    pcall(function()
        exports['hydra_notify']:Send(src, { title = 'Given', message = count .. 'x ' .. label, type = 'success' })
        exports['hydra_notify']:Send(targetId, { title = 'Received', message = count .. 'x ' .. label, type = 'success' })
    end)

    -- Update both clients
    TriggerClientEvent('hydra:inventory:client:update', src, {
        items = enrichItems(inventories[srcId].items),
        weight = Hydra.Inventory.GetWeight(src),
    })
    TriggerClientEvent('hydra:inventory:client:update', targetId, {
        items = enrichItems(inventories[tgtId].items),
        weight = Hydra.Inventory.GetWeight(targetId),
    })
end)

-- =========================================================================
-- ROB / SEARCH SYSTEM
-- =========================================================================

RegisterNetEvent('hydra:inventory:rob', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId then return end
    if not cfg.rob.enabled then return end

    local srcId = getIdentifier(src)
    local tgtId = getIdentifier(targetId)
    if not srcId or not tgtId then return end
    if not inventories[tgtId] then return end

    local stolenItems = {}
    local stolenCount = 0
    local maxSteal = cfg.rob.maxItems or 3

    -- Steal cash first
    if cfg.rob.canStealCash then
        local cash = Hydra.Inventory.GetMoney(targetId, 'cash')
        if cash > 0 then
            local stealAmount = math.random(math.floor(cash * 0.3), math.floor(cash * 0.8))
            if stealAmount > 0 then
                Hydra.Inventory.RemoveMoney(targetId, 'cash', stealAmount, 'robbed')
                Hydra.Inventory.AddMoney(src, 'cash', stealAmount, 'robbery')
                stolenItems[#stolenItems + 1] = { name = 'cash', count = stealAmount }
            end
        end
    end

    -- Steal random items
    if cfg.rob.canStealItems then
        local targetItems = {}
        for slot, item in pairs(inventories[tgtId].items) do
            if item and item.name ~= (cfg.money.cashItemName or 'cash') then
                targetItems[#targetItems + 1] = { slot = slot, item = item }
            end
        end

        -- Shuffle
        for i = #targetItems, 2, -1 do
            local j = math.random(1, i)
            targetItems[i], targetItems[j] = targetItems[j], targetItems[i]
        end

        for _, entry in ipairs(targetItems) do
            if stolenCount >= maxSteal then break end
            local stealCount = math.random(1, entry.item.count or 1)

            if Hydra.Inventory.CanCarry(src, entry.item.name, stealCount) then
                Hydra.Inventory.RemoveItem(targetId, entry.item.name, stealCount, entry.slot)
                Hydra.Inventory.AddItem(src, entry.item.name, stealCount, entry.item.metadata)
                stolenItems[#stolenItems + 1] = { name = entry.item.name, count = stealCount }
                stolenCount = stolenCount + 1
            end
        end
    end

    -- Notify victim
    if cfg.rob.notifyVictim then
        TriggerClientEvent('hydra:inventory:client:robbed', targetId, stolenItems)
    end

    -- Police alert
    if cfg.rob.policeAlert and math.random(1, 100) <= (cfg.rob.policeAlertChance or 75) then
        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)
        pcall(function()
            TriggerEvent('hydra:dispatch:alert', {
                type = 'robbery',
                coords = coords,
                message = 'Robbery in progress',
            })
        end)
    end

    -- Update both clients
    TriggerClientEvent('hydra:inventory:client:update', src, {
        items = enrichItems(inventories[srcId].items),
        weight = Hydra.Inventory.GetWeight(src),
    })
    TriggerClientEvent('hydra:inventory:client:update', targetId, {
        items = enrichItems(inventories[tgtId].items),
        weight = Hydra.Inventory.GetWeight(targetId),
    })
end)

--- Search: opens target inventory as read-only secondary
RegisterNetEvent('hydra:inventory:search', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId then return end

    local tgtId = getIdentifier(targetId)
    if not tgtId or not inventories[tgtId] then return end

    -- Open as secondary inventory (read-only for police search)
    TriggerClientEvent('hydra:inventory:client:open', src, {
        playerInventory = {
            items = enrichItems(inventories[getIdentifier(src)].items),
            maxSlots = Hydra.Inventory.GetMaxSlots(src),
            maxWeight = Hydra.Inventory.GetMaxWeight(src),
            weight = Hydra.Inventory.GetWeight(src),
        },
        secondaryInventory = {
            id = 'search:' .. targetId,
            type = 'search',
            label = (GetPlayerName(targetId) or 'Player') .. "'s Inventory",
            items = enrichItems(inventories[tgtId].items),
            maxSlots = Hydra.Inventory.GetMaxSlots(targetId),
            maxWeight = Hydra.Inventory.GetMaxWeight(targetId),
            weight = Hydra.Inventory.GetWeight(targetId),
        },
        money = moneyAccounts[getIdentifier(src)] or { cash = 0, bank = 0, crypto = 0 },
    })

    openInventories[src] = { type = 'search', secondaryId = 'search:' .. targetId }
    TriggerClientEvent('hydra:inventory:client:searched', targetId)
end)

-- =========================================================================
-- DUMPSTER SEARCH (server-side loot calculation)
-- =========================================================================

RegisterNetEvent('hydra:inventory:dumpster:search', function()
    local src = source
    if not cfg.dumpsters or not cfg.dumpsters.enabled then return end

    local dcfg = cfg.dumpsters
    local foundItems = {}

    -- Roll for finding something
    if math.random(1, 100) > (dcfg.findChance or 40) then
        TriggerClientEvent('hydra:inventory:client:dumpster:result', src, {})
        return
    end

    -- Roll for each loot entry
    for _, loot in ipairs(dcfg.loot or {}) do
        if math.random(1, 100) <= (loot.chance or 10) then
            local count = math.random(loot.min or 1, loot.max or 1)
            if Hydra.Inventory.CanCarry(src, loot.item, count) then
                local ok = Hydra.Inventory.AddItem(src, loot.item, count)
                if ok then
                    foundItems[#foundItems + 1] = { name = loot.item, count = count }
                end
            end
        end
    end

    TriggerClientEvent('hydra:inventory:client:dumpster:result', src, foundItems)

    -- Update client inventory
    local identifier = getIdentifier(src)
    if identifier and inventories[identifier] then
        TriggerClientEvent('hydra:inventory:client:update', src, {
            items = enrichItems(inventories[identifier].items),
            weight = Hydra.Inventory.GetWeight(src),
        })
    end
end)

-- =========================================================================
-- OPEN SECONDARY INVENTORY (for vehicle/stash - called by other server files)
-- =========================================================================

function Hydra.Inventory.OpenSecondary(src, secondaryData)
    local identifier = getIdentifier(src)
    if not identifier or not inventories[identifier] then return end

    local money = moneyAccounts[identifier] or { cash = 0, bank = 0, crypto = 0 }
    if cfg.money.cashAsItem then
        money.cash = Hydra.Inventory.GetItemCount(src, cfg.money.cashItemName or 'cash')
    end

    TriggerClientEvent('hydra:inventory:client:open', src, {
        playerInventory = {
            items = enrichItems(inventories[identifier].items),
            maxSlots = Hydra.Inventory.GetMaxSlots(src),
            maxWeight = Hydra.Inventory.GetMaxWeight(src),
            weight = Hydra.Inventory.GetWeight(src),
        },
        secondaryInventory = secondaryData,
        money = money,
    })

    openInventories[src] = {
        type = secondaryData.type,
        secondaryId = secondaryData.id,
    }
end

-- =========================================================================
-- PLAYER LIFECYCLE
-- =========================================================================

AddEventHandler('playerConnecting', function()
    local src = source
    -- Defer inventory load to after full connection
end)

RegisterNetEvent('hydra:inventory:client:ready', function()
    local src = source
    local identifier = getIdentifier(src)
    if not identifier then return end
    loadInventory(identifier)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local identifier = getIdentifier(src)
    if identifier then
        saveInventory(identifier)
        -- Don't remove immediately — allow reconnection grace
        SetTimeout(60000, function()
            -- If player hasn't reconnected, clean up
            local stillOnline = false
            for _, id in ipairs(GetPlayers()) do
                if getIdentifier(tonumber(id)) == identifier then
                    stillOnline = true
                    break
                end
            end
            if not stillOnline then
                inventories[identifier] = nil
                moneyAccounts[identifier] = nil
            end
        end)
    end
    openInventories[src] = nil
end)

-- =========================================================================
-- HOT RELOAD — reload items config without restarting
-- =========================================================================

-- Save reference to shared registry rebuild before we overwrite
local sharedReloadItems = Hydra.Inventory.ReloadItems

--- Reload item definitions at runtime.
--- Re-executes config/items.lua and rebuilds the shared registry,
--- then pushes updated item data to all connected players.
function Hydra.Inventory.HotReloadItems(source)
    -- Re-execute the items config file to pick up changes
    local fileContent = LoadResourceFile(GetCurrentResourceName(), 'config/items.lua')

    if not fileContent then
        print('[Hydra] ^1Item reload failed — could not read config/items.lua^0')
        return false, 'Could not read config/items.lua'
    end

    -- Parse the updated config
    local fn, err = load(fileContent, '@hydra_inventory/config/items.lua')
    if not fn then
        print('[Hydra] ^1Item reload failed — syntax error: ' .. tostring(err) .. '^0')
        return false, 'Syntax error: ' .. tostring(err)
    end

    -- Execute — this overwrites HydraConfig.Items
    local ok, execErr = pcall(fn)
    if not ok then
        print('[Hydra] ^1Item reload failed — runtime error: ' .. tostring(execErr) .. '^0')
        return false, 'Runtime error: ' .. tostring(execErr)
    end

    -- Rebuild the shared registry
    local count
    if sharedReloadItems then
        count = sharedReloadItems()
    else
        count = #HydraConfig.Items
    end

    -- Build rarity map for NUI
    local rarityDefs = HydraConfig.Inventory.rarity or {}

    -- Push updated item data to all connected clients
    TriggerClientEvent('hydra:inventory:client:itemsReloaded', -1, HydraConfig.Items, rarityDefs)

    print('[Hydra] ^2Items reloaded — ' .. tostring(count) .. ' items registered^0')
    return true, count
end

--- Admin command: /reloaditems
RegisterCommand('reloaditems', function(src, args, raw)
    -- Console (src 0) or admin check
    if src ~= 0 then
        local allowed = false
        pcall(function()
            allowed = exports['hydra_core']:HasPermission(src, 'admin')
        end)
        if not allowed then
            -- Fallback: check for ace permission
            if not IsPlayerAceAllowed(src, 'hydra.admin') then
                pcall(function()
                    exports['hydra_notify']:Send(src, { title = 'Inventory', message = 'No permission', type = 'error' })
                end)
                return
            end
        end
    end

    local success, result = Hydra.Inventory.HotReloadItems(src)
    local msg = success
        and ('Items reloaded — ' .. tostring(result) .. ' items')
        or ('Reload failed — ' .. tostring(result))

    if src == 0 then
        print('[Hydra] ' .. msg)
    else
        pcall(function()
            exports['hydra_notify']:Send(src, { title = 'Inventory', message = msg, type = success and 'success' or 'error' })
        end)
    end
end, true) -- restricted by default

-- =========================================================================
-- MODULE REGISTRATION
-- =========================================================================

CreateThread(function()
    Wait(200)

    local ok = pcall(function()
        Hydra.Modules.Register('hydra_inventory', {
            priority = 80,
            dependencies = { 'hydra_core' },
            api = {
                GetInventory = Hydra.Inventory.GetInventory,
                AddItem = Hydra.Inventory.AddItem,
                RemoveItem = Hydra.Inventory.RemoveItem,
                HasItem = Hydra.Inventory.HasItem,
                GetItem = Hydra.Inventory.GetItem,
                GetItemCount = Hydra.Inventory.GetItemCount,
                GetWeight = Hydra.Inventory.GetWeight,
                GetMaxWeight = Hydra.Inventory.GetMaxWeight,
                GetMaxSlots = Hydra.Inventory.GetMaxSlots,
                CanCarry = Hydra.Inventory.CanCarry,
                MoveItem = Hydra.Inventory.MoveItem,
                GetMoney = Hydra.Inventory.GetMoney,
                AddMoney = Hydra.Inventory.AddMoney,
                RemoveMoney = Hydra.Inventory.RemoveMoney,
                SetMoney = Hydra.Inventory.SetMoney,
                TransferMoney = Hydra.Inventory.TransferMoney,
                RegisterUseHandler = Hydra.Inventory.RegisterUseHandler,
                GetItemData = Hydra.Inventory.GetItemData,
                OpenSecondary = Hydra.Inventory.OpenSecondary,
                ClearInventory = Hydra.Inventory.ClearInventory,
                HotReloadItems = Hydra.Inventory.HotReloadItems,
            },
            hooks = {
                onLoad = function()
                    print('[Hydra] Inventory system loaded — ' .. tostring(#HydraConfig.Items) .. ' items registered')
                end,
            },
        })
    end)
    if not ok then
        print('[Hydra] Inventory running standalone (module registration failed)')
    end
end)

-- =========================================================================
-- EXPORTS
-- =========================================================================

exports('GetInventory', Hydra.Inventory.GetInventory)
exports('AddItem', Hydra.Inventory.AddItem)
exports('RemoveItem', Hydra.Inventory.RemoveItem)
exports('SetItem', Hydra.Inventory.SetItem)
exports('ClearSlot', Hydra.Inventory.ClearSlot)
exports('HasItem', Hydra.Inventory.HasItem)
exports('GetItem', Hydra.Inventory.GetItem)
exports('GetItemCount', Hydra.Inventory.GetItemCount)
exports('GetWeight', Hydra.Inventory.GetWeight)
exports('GetMaxWeight', Hydra.Inventory.GetMaxWeight)
exports('GetMaxSlots', Hydra.Inventory.GetMaxSlots)
exports('CanCarry', Hydra.Inventory.CanCarry)
exports('MoveItem', Hydra.Inventory.MoveItem)
exports('SwapItems', Hydra.Inventory.SwapItems)
exports('ClearInventory', Hydra.Inventory.ClearInventory)
exports('GetMoney', Hydra.Inventory.GetMoney)
exports('AddMoney', Hydra.Inventory.AddMoney)
exports('RemoveMoney', Hydra.Inventory.RemoveMoney)
exports('SetMoney', Hydra.Inventory.SetMoney)
exports('TransferMoney', Hydra.Inventory.TransferMoney)
exports('RegisterUseHandler', Hydra.Inventory.RegisterUseHandler)
exports('GetItemData', Hydra.Inventory.GetItemData)
exports('OpenSecondary', Hydra.Inventory.OpenSecondary)
exports('GetItemLabel', Hydra.Inventory.GetItemLabel)
exports('ReloadItems', Hydra.Inventory.HotReloadItems)
exports('GetItemRarity', Hydra.Inventory.GetItemRarity)
