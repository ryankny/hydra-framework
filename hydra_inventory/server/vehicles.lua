--[[
    Hydra Inventory - Vehicle Storage

    Trunk and glovebox inventory management for vehicles.
    Inventories are keyed by plate + type and persist via hydra_data.
]]

Hydra = Hydra or {}
Hydra.Inventory = Hydra.Inventory or {}

local cfg = HydraConfig.Inventory

-- Vehicle inventories: ["plate:type"] = { items, maxSlots, maxWeight }
local vehicleInventories = {}

-- Track which players have a vehicle inventory open: [src] = "plate:type"
local openInventories = {}

-- =============================================
-- COLLECTION REGISTRATION
-- =============================================

CreateThread(function()
    Wait(0)
    pcall(function()
        exports['hydra_data']:CreateCollection('vehicle_inventories', {
            { name = 'plate', type = 'VARCHAR(32)', index = true },
            { name = 'type',  type = 'VARCHAR(16)' },
            { name = 'items', type = 'LONGTEXT' },
        })
    end)
end)

-- =============================================
-- HELPERS
-- =============================================

--- Build a storage key from plate and type
--- @param plate string
--- @param type string 'trunk' or 'glovebox'
--- @return string
local function storageKey(plate, type)
    return plate .. ':' .. type
end

--- Get slot/weight config for a vehicle class and type
--- @param vehicleClass number|nil
--- @param type string 'trunk' or 'glovebox'
--- @return number slots, number weight
local function getVehicleCapacity(vehicleClass, type)
    if type == 'glovebox' then
        return cfg.vehicle.gloveboxSlots, cfg.vehicle.gloveboxWeight
    end

    vehicleClass = vehicleClass or 'default'
    local slots = cfg.vehicle.trunkSlots[vehicleClass] or cfg.vehicle.trunkSlots.default
    local weight = cfg.vehicle.trunkWeight[vehicleClass] or cfg.vehicle.trunkWeight.default
    return slots, weight
end

-- =============================================
-- VEHICLE INVENTORY FUNCTIONS
-- =============================================

--- Get or create a vehicle inventory
--- @param plate string Vehicle plate
--- @param type string 'trunk' or 'glovebox'
--- @param vehicleClass number|nil Vehicle class for capacity lookup
--- @return table { items, maxSlots, maxWeight }
function Hydra.Inventory.GetVehicleInventory(plate, type, vehicleClass)
    if not plate or not type then return nil end
    if type ~= 'trunk' and type ~= 'glovebox' then return nil end

    local key = storageKey(plate, type)

    -- Return cached if available
    if vehicleInventories[key] then
        return vehicleInventories[key]
    end

    -- Try loading from database
    local loaded = Hydra.Inventory.LoadVehicleInventory(plate, type)
    if loaded then
        -- Update capacity based on current class (may change with vehicle mods)
        local slots, weight = getVehicleCapacity(vehicleClass, type)
        loaded.maxSlots = slots
        loaded.maxWeight = weight
        return loaded
    end

    -- Create new empty inventory
    local slots, weight = getVehicleCapacity(vehicleClass, type)
    vehicleInventories[key] = {
        items = {},
        maxSlots = slots,
        maxWeight = weight,
    }

    return vehicleInventories[key]
end

--- Open vehicle inventory for a player (sends data to client)
--- @param src number Player source
--- @param plate string Vehicle plate
--- @param type string 'trunk' or 'glovebox'
--- @param vehicleClass number|nil
function Hydra.Inventory.OpenVehicleInventory(src, plate, type, vehicleClass)
    if not src or src <= 0 then return end
    if not plate or not type then return end

    local inv = Hydra.Inventory.GetVehicleInventory(plate, type, vehicleClass)
    if not inv then return end

    local key = storageKey(plate, type)
    openInventories[src] = key

    -- Get player inventory
    local ok, p = pcall(function() return exports['hydra_players']:GetPlayer(src) end)
    if not ok then p = nil end
    local player = p
    local playerItems = player and player.inventory or {}

    -- Send both inventories to client
    TriggerClientEvent('hydra:inventory:vehicle:opened', src, {
        plate = plate,
        type = type,
        items = inv.items,
        maxSlots = inv.maxSlots,
        maxWeight = inv.maxWeight,
    }, playerItems)

    Hydra.Utils.Log('debug', 'Player %d opened %s inventory for vehicle %s', src, type, plate)
end

--- Save a vehicle inventory to hydra_data
--- @param plate string
--- @param type string 'trunk' or 'glovebox'
function Hydra.Inventory.SaveVehicleInventory(plate, type)
    local key = storageKey(plate, type)
    local inv = vehicleInventories[key]
    if not inv then return end

    local ok, err = pcall(function()
        local existing = exports['hydra_data']:FindOne('vehicle_inventories', {
            plate = plate,
            type = type,
        })

        local data = {
            plate = plate,
            type = type,
            items = json.encode(inv.items),
            max_slots = inv.maxSlots,
            max_weight = inv.maxWeight,
        }

        if existing then
            exports['hydra_data']:Update('vehicle_inventories', { plate = plate, type = type }, data)
        else
            exports['hydra_data']:Create('vehicle_inventories', data)
        end
    end)

    if not ok then
        Hydra.Utils.Log('error', 'Failed to save vehicle inventory %s: %s', key, tostring(err))
    end
end

--- Load a vehicle inventory from hydra_data
--- @param plate string
--- @param type string 'trunk' or 'glovebox'
--- @return table|nil
function Hydra.Inventory.LoadVehicleInventory(plate, type)
    local key = storageKey(plate, type)

    local result
    local ok, err = pcall(function()
        result = exports['hydra_data']:FindOne('vehicle_inventories', {
            plate = plate,
            type = type,
        })
    end)

    if not ok then
        Hydra.Utils.Log('error', 'Failed to load vehicle inventory %s: %s', key, tostring(err))
        return nil
    end

    if not result then return nil end

    local items = {}
    if result.items and result.items ~= '' then
        local decoded
        local decodeOk = pcall(function()
            decoded = json.decode(result.items)
        end)
        if decodeOk and decoded then
            items = decoded
        end
    end

    vehicleInventories[key] = {
        items = items,
        maxSlots = result.max_slots or cfg.vehicle.trunkSlots.default,
        maxWeight = result.max_weight or cfg.vehicle.trunkWeight.default,
    }

    return vehicleInventories[key]
end

--- Clear a vehicle inventory
--- @param plate string
--- @param type string 'trunk' or 'glovebox'
function Hydra.Inventory.ClearVehicleInventory(plate, type)
    local key = storageKey(plate, type)
    if vehicleInventories[key] then
        vehicleInventories[key].items = {}
    end

    -- Also clear in database
    pcall(function()
        exports['hydra_data']:Update('vehicle_inventories', { plate = plate, type = type }, {
            items = json.encode({}),
        })
    end)

    Hydra.Utils.Log('debug', 'Cleared vehicle inventory %s', key)
end

-- =============================================
-- EVENTS
-- =============================================

--- Client requests to open a vehicle trunk or glovebox
RegisterNetEvent('hydra:inventory:vehicle:open')
AddEventHandler('hydra:inventory:vehicle:open', function(netId, type, vehicleClass)
    local src = source
    if not src or src <= 0 then return end
    if type ~= 'trunk' and type ~= 'glovebox' then return end

    netId = tonumber(netId)
    if not netId then return end

    -- Validate vehicle exists on server
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 then return end

    -- Validate player distance to vehicle
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local playerPos = GetEntityCoords(ped)
    local vehiclePos = GetEntityCoords(vehicle)
    local dist = #(playerPos - vehiclePos)
    if dist > cfg.vehicle.accessDistance + 1.0 then return end

    -- Check if vehicle is locked (if lockWithVehicle is enabled)
    if cfg.vehicle.lockWithVehicle then
        local lockStatus = GetVehicleDoorLockStatus(vehicle)
        -- 1 = unlocked, 2+ = various lock states
        if lockStatus and lockStatus >= 2 then
            TriggerClientEvent('hydra:notify', src, 'Vehicle is locked', 'error')
            return
        end
    end

    -- Get vehicle plate
    local plate = GetVehicleNumberPlateText(vehicle)
    if not plate or plate == '' then return end
    plate = plate:gsub('^%s+', ''):gsub('%s+$', '') -- Trim whitespace

    vehicleClass = tonumber(vehicleClass)

    Hydra.Inventory.OpenVehicleInventory(src, plate, type, vehicleClass)
end)

--- Client closes a vehicle inventory
RegisterNetEvent('hydra:inventory:vehicle:close')
AddEventHandler('hydra:inventory:vehicle:close', function(updatedItems)
    local src = source
    if not src or src <= 0 then return end

    local key = openInventories[src]
    if not key then return end

    -- Update items if provided by client (after drag-drop operations)
    if updatedItems and vehicleInventories[key] then
        vehicleInventories[key].items = updatedItems
    end

    -- Extract plate and type from key for saving
    local plate, type = key:match('^(.+):(%w+)$')
    if plate and type then
        Hydra.Inventory.SaveVehicleInventory(plate, type)
    end

    openInventories[src] = nil

    Hydra.Utils.Log('debug', 'Player %d closed vehicle inventory %s', src, key)
end)

-- =============================================
-- CLEANUP ON PLAYER DROP
-- =============================================

AddEventHandler('playerDropped', function()
    local src = source

    -- Save and close any open vehicle inventory
    local key = openInventories[src]
    if key then
        local plate, type = key:match('^(.+):(%w+)$')
        if plate and type then
            Hydra.Inventory.SaveVehicleInventory(plate, type)
        end
        openInventories[src] = nil
    end
end)

-- =============================================
-- EXPORTS
-- =============================================

exports('GetVehicleInventory', function(...) return Hydra.Inventory.GetVehicleInventory(...) end)
exports('OpenVehicleInventory', function(...) return Hydra.Inventory.OpenVehicleInventory(...) end)
exports('SaveVehicleInventory', function(...) return Hydra.Inventory.SaveVehicleInventory(...) end)
exports('ClearVehicleInventory', function(...) return Hydra.Inventory.ClearVehicleInventory(...) end)
