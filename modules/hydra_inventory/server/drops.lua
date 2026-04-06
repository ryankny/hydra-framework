--[[
    Hydra Inventory - World Drops

    Items dropped on the ground as props. Manages drop lifecycle
    including creation, pickup, expiry, and client synchronization.
]]

Hydra = Hydra or {}
Hydra.Inventory = Hydra.Inventory or {}

local cfg = HydraConfig.Inventory

-- All active drops: [dropId] = { id, items, coords, createdAt, ownerId }
local drops = {}
local dropCounter = 0

-- =============================================
-- DROP MANAGEMENT
-- =============================================

--- Create a new world drop at the given coordinates
--- @param src number Player source who created the drop
--- @param items table Array of item tables { name, count, metadata? }
--- @param coords vector3 World position
--- @return number|nil dropId
function Hydra.Inventory.CreateDrop(src, items, coords)
    if not cfg.drops.enabled then return nil end
    if not items or #items == 0 then return nil end
    if not coords then return nil end

    dropCounter = dropCounter + 1
    local dropId = dropCounter

    -- Calculate total weight for prop selection
    local totalWeight = Hydra.Inventory.CalculateWeight(items)

    drops[dropId] = {
        id = dropId,
        items = items,
        coords = coords,
        createdAt = os.time(),
        ownerId = src or 0,
        weight = totalWeight,
    }

    -- Broadcast to all clients
    TriggerClientEvent('hydra:inventory:drops:add', -1, dropId, {
        id = dropId,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        weight = totalWeight,
    })

    Hydra.Utils.Log('debug', 'Drop #%d created at %.1f, %.1f, %.1f (%d items, owner: %s)',
        dropId, coords.x, coords.y, coords.z, #items, tostring(src))

    return dropId
end

--- Get drop data by ID
--- @param dropId number
--- @return table|nil
function Hydra.Inventory.GetDrop(dropId)
    return drops[dropId]
end

--- Remove a drop from the world
--- @param dropId number
function Hydra.Inventory.RemoveDrop(dropId)
    if not drops[dropId] then return end

    drops[dropId] = nil

    -- Broadcast removal to all clients
    TriggerClientEvent('hydra:inventory:drops:remove', -1, dropId)

    Hydra.Utils.Log('debug', 'Drop #%d removed', dropId)
end

--- Transfer items from drop to player inventory
--- @param src number Player source picking up the drop
--- @param dropId number
--- @return boolean success
function Hydra.Inventory.PickupDrop(src, dropId)
    local drop = drops[dropId]
    if not drop then return false end

    local player = Hydra.Players and Hydra.Players.GetPlayer(src)
    if not player then return false end

    local playerItems = player.inventory or {}
    local maxWeight = cfg.player.maxWeight
    local maxSlots = cfg.player.slots

    -- Transfer each item, checking capacity
    local remaining = {}
    for _, item in ipairs(drop.items) do
        local canCarry = Hydra.Inventory.CanCarry(playerItems, item.name, item.count or 1, maxWeight)
        local freeSlot = Hydra.Inventory.FindStackableSlot(playerItems, item.name) or
                         Hydra.Inventory.FindFreeSlot(playerItems, maxSlots)

        if canCarry and freeSlot then
            -- Add to player inventory
            local stackSlot = Hydra.Inventory.FindStackableSlot(playerItems, item.name)
            if stackSlot then
                playerItems[stackSlot].count = (playerItems[stackSlot].count or 1) + (item.count or 1)
            else
                playerItems[freeSlot] = {
                    name = item.name,
                    count = item.count or 1,
                    metadata = item.metadata,
                }
            end
        else
            -- Cannot carry this item, leave in drop
            remaining[#remaining + 1] = item
        end
    end

    -- Sync player inventory to client
    TriggerClientEvent('hydra:inventory:update', src, playerItems)
    TriggerEvent('hydra:inventory:changed', src, playerItems)

    if #remaining == 0 then
        -- Drop is empty, remove it
        Hydra.Inventory.RemoveDrop(dropId)
    else
        -- Update drop with remaining items
        drop.items = remaining
        drop.weight = Hydra.Inventory.CalculateWeight(remaining)
    end

    Hydra.Utils.Log('debug', 'Player %d picked up drop #%d (%d items taken, %d remaining)',
        src, dropId, #drop.items - #remaining + (#remaining == 0 and #drop.items or 0), #remaining)

    return true
end

--- Find all drops within a radius of given coordinates
--- @param coords vector3
--- @param radius number
--- @return table Array of drop data
function Hydra.Inventory.GetNearbyDrops(coords, radius)
    radius = radius or cfg.drops.pickupDistance
    local nearby = {}

    for _, drop in pairs(drops) do
        local dist = #(coords - drop.coords)
        if dist <= radius then
            nearby[#nearby + 1] = drop
        end
    end

    return nearby
end

-- =============================================
-- EVENTS
-- =============================================

--- Player drops item(s) from their inventory
RegisterNetEvent('hydra:inventory:drop')
AddEventHandler('hydra:inventory:drop', function(itemName, count, slot)
    local src = source
    if not src or src <= 0 then return end
    if type(itemName) ~= 'string' or #itemName > 64 then return end

    count = tonumber(count)
    if not count or count <= 0 then return end

    if not Hydra.Inventory.ItemExists(itemName) then return end

    local player = Hydra.Players and Hydra.Players.GetPlayer(src)
    if not player then return end

    local playerItems = player.inventory or {}

    -- Verify player has the item
    local totalOwned = Hydra.Inventory.CountItem(playerItems, itemName)
    if totalOwned < count then return end

    -- Remove from player inventory
    local toRemove = count
    for s, item in pairs(playerItems) do
        if item and item.name == itemName and toRemove > 0 then
            local available = item.count or 1
            if available <= toRemove then
                toRemove = toRemove - available
                playerItems[s] = nil
            else
                playerItems[s].count = available - toRemove
                toRemove = 0
            end
            if toRemove <= 0 then break end
        end
    end

    -- Sync player inventory
    TriggerClientEvent('hydra:inventory:update', src, playerItems)
    TriggerEvent('hydra:inventory:changed', src, playerItems)

    -- Get player position for drop location
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local coords = GetEntityCoords(ped)

    -- Create the world drop
    local dropItems = {
        { name = itemName, count = count, metadata = slot and playerItems[slot] and playerItems[slot].metadata or nil },
    }

    Hydra.Inventory.CreateDrop(src, dropItems, coords)
end)

--- Player picks up a world drop
RegisterNetEvent('hydra:inventory:pickup')
AddEventHandler('hydra:inventory:pickup', function(dropId)
    local src = source
    if not src or src <= 0 then return end

    dropId = tonumber(dropId)
    if not dropId then return end

    local drop = drops[dropId]
    if not drop then return end

    -- Distance validation
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local playerPos = GetEntityCoords(ped)
    local dist = #(playerPos - drop.coords)
    if dist > cfg.drops.pickupDistance + 1.0 then return end

    Hydra.Inventory.PickupDrop(src, dropId)
end)

--- Client requests all active drops (on join / resource start)
RegisterNetEvent('hydra:inventory:drops:request')
AddEventHandler('hydra:inventory:drops:request', function()
    local src = source
    if not src or src <= 0 then return end

    local dropList = {}
    for id, drop in pairs(drops) do
        dropList[id] = {
            id = drop.id,
            coords = { x = drop.coords.x, y = drop.coords.y, z = drop.coords.z },
            weight = drop.weight,
        }
    end

    TriggerClientEvent('hydra:inventory:drops:sync', src, dropList)
end)

-- =============================================
-- EXPIRY THREAD
-- =============================================

CreateThread(function()
    while true do
        Wait(60000) -- Check every 60 seconds

        local now = os.time()
        local expireTime = cfg.drops.expireTime
        local maxDrops = cfg.drops.maxDrops

        -- Remove expired drops
        if expireTime > 0 then
            for id, drop in pairs(drops) do
                if (now - drop.createdAt) >= expireTime then
                    Hydra.Inventory.RemoveDrop(id)
                    Hydra.Utils.Log('debug', 'Drop #%d expired', id)
                end
            end
        end

        -- Enforce max drops (remove oldest first)
        local dropCount = 0
        for _ in pairs(drops) do dropCount = dropCount + 1 end

        if dropCount > maxDrops then
            -- Collect and sort by creation time
            local sorted = {}
            for id, drop in pairs(drops) do
                sorted[#sorted + 1] = { id = id, createdAt = drop.createdAt }
            end
            table.sort(sorted, function(a, b) return a.createdAt < b.createdAt end)

            -- Remove oldest until within limit
            local toRemove = dropCount - maxDrops
            for i = 1, toRemove do
                Hydra.Inventory.RemoveDrop(sorted[i].id)
                Hydra.Utils.Log('debug', 'Drop #%d removed (max drops exceeded)', sorted[i].id)
            end
        end
    end
end)

-- =============================================
-- CLEANUP ON PLAYER DROP
-- =============================================

AddEventHandler('playerDropped', function()
    -- Drops persist after player leaves; no cleanup needed
end)

-- =============================================
-- EXPORTS
-- =============================================

exports('CreateDrop', function(...) return Hydra.Inventory.CreateDrop(...) end)
exports('GetDrop', function(...) return Hydra.Inventory.GetDrop(...) end)
exports('RemoveDrop', function(...) return Hydra.Inventory.RemoveDrop(...) end)
exports('GetNearbyDrops', function(...) return Hydra.Inventory.GetNearbyDrops(...) end)
