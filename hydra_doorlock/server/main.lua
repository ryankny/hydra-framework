--[[
    Hydra Doorlock - Server

    Authoritative door state management. Loads doors from both
    config and database, syncs state to clients, handles
    lock/unlock authorization for all lock types.
]]

Hydra = Hydra or {}
Hydra.Doorlock = {}

local cfg = HydraDoorlockConfig

-- All doors: [id] = doorData
local doors = {}
-- Door states: [id] = locked (bool)
local doorStates = {}
-- Auto-lock timers: [id] = os.time when to lock
local autoLockTimers = {}
-- Source of config vs database
local doorSource = {} -- [id] = 'config' | 'database'

-- =============================================
-- DATABASE COLLECTION
-- =============================================

local function createCollection()
    if Hydra.Data and Hydra.Data.Collections then
        Hydra.Data.Collections.Create('doorlocks', {
            { name = 'door_id',    type = 'VARCHAR(64)',   nullable = false },
            { name = 'label',      type = 'VARCHAR(128)',  nullable = true },
            { name = 'coords_x',   type = 'FLOAT',        nullable = false },
            { name = 'coords_y',   type = 'FLOAT',        nullable = false },
            { name = 'coords_z',   type = 'FLOAT',        nullable = false },
            { name = 'model',      type = 'BIGINT',        default = '0' },
            { name = 'heading',    type = 'FLOAT',         default = '0' },
            { name = 'locked',     type = 'TINYINT(1)',    default = '1' },
            { name = 'lock_type',  type = 'VARCHAR(32)',   default = 'public' },
            { name = 'lock_data',  type = 'TEXT',          default = '{}' },
            { name = 'auto_lock',  type = 'INT',           default = '0' },
            { name = 'double_model', type = 'BIGINT',      default = '0' },
            { name = 'created_by', type = 'VARCHAR(64)',   nullable = true },
        }, {
            indexes = {
                { name = 'idx_door_id', columns = { 'door_id' }, unique = true },
            },
        })
    end
end

-- =============================================
-- DOOR LOADING
-- =============================================

--- Load all doors from config and database
local function loadDoors()
    -- Load config doors
    for _, door in ipairs(cfg.doors) do
        if door.id then
            doors[door.id] = {
                id = door.id,
                label = door.label or door.id,
                coords = door.coords,
                model = door.model or 0,
                heading = door.heading or 0.0,
                lock_type = door.lock_type or 'public',
                lock_data = door.lock_data or {},
                auto_lock = door.auto_lock or 0,
                double = door.double or 0,
            }
            doorStates[door.id] = door.locked ~= false
            doorSource[door.id] = 'config'
        end
    end

    -- Load database doors
    if Hydra.Data and Hydra.Data.Find then
        local dbDoors = Hydra.Data.Find('doorlocks', {})
        if dbDoors then
            for _, row in ipairs(dbDoors) do
                local id = row.door_id
                if not doors[id] then -- Don't override config doors
                    local lockData = {}
                    if row.lock_data and row.lock_data ~= '' then
                        lockData = Hydra.Utils.JsonDecode(row.lock_data) or {}
                    end

                    doors[id] = {
                        id = id,
                        label = row.label or id,
                        coords = vector3(row.coords_x, row.coords_y, row.coords_z),
                        model = row.model or 0,
                        heading = row.heading or 0.0,
                        lock_type = row.lock_type or 'public',
                        lock_data = lockData,
                        auto_lock = row.auto_lock or 0,
                        double = row.double_model or 0,
                    }
                    doorStates[id] = row.locked == 1
                    doorSource[id] = 'database'
                end
            end
        end
    end

    Hydra.Utils.Log('info', 'Loaded %d doors (%d config, %d database)',
        countTable(doors),
        countSource('config'),
        countSource('database'))
end

local function countTable(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function countSource(src)
    local n = 0
    for _, s in pairs(doorSource) do
        if s == src then n = n + 1 end
    end
    return n
end

-- =============================================
-- DOOR STATE MANAGEMENT
-- =============================================

--- Get all door data and states for sync
--- @return table
function Hydra.Doorlock.GetAll()
    local all = {}
    for id, door in pairs(doors) do
        all[id] = {
            id = door.id,
            label = door.label,
            coords = { x = door.coords.x, y = door.coords.y, z = door.coords.z },
            model = door.model,
            heading = door.heading,
            locked = doorStates[id] or false,
            lock_type = door.lock_type,
            auto_lock = door.auto_lock,
            double = door.double,
        }
    end
    return all
end

--- Set door locked state
--- @param id string
--- @param locked boolean
--- @param src number|nil who toggled
function Hydra.Doorlock.SetLocked(id, locked, src)
    if not doors[id] then return end

    doorStates[id] = locked

    -- Broadcast to clients
    TriggerClientEvent('hydra:doorlock:stateUpdate', -1, id, locked)

    -- Auto-lock timer
    if not locked and doors[id].auto_lock > 0 then
        autoLockTimers[id] = os.time() + doors[id].auto_lock
    else
        autoLockTimers[id] = nil
    end

    -- Save to database if it's a DB door
    if doorSource[id] == 'database' then
        Hydra.Data.Update('doorlocks', { door_id = id }, {
            locked = locked and 1 or 0,
        })
    end

    -- Log
    if src and src > 0 and Hydra.Logs then
        local name = GetPlayerName(src) or 'Unknown'
        Hydra.Logs.Quick('general', 'Door ' .. (locked and 'Locked' or 'Unlocked'),
            ('**%s** %s door: %s'):format(name, locked and 'locked' or 'unlocked', doors[id].label), src)
    end
end

--- Toggle door state
--- @param id string
--- @param src number
function Hydra.Doorlock.Toggle(id, src)
    if not doors[id] then return end
    Hydra.Doorlock.SetLocked(id, not doorStates[id], src)
end

--- Check if player can access a door
--- @param src number
--- @param id string
--- @return boolean, string|nil reason
function Hydra.Doorlock.CanAccess(src, id)
    local door = doors[id]
    if not door then return false, 'Door not found' end

    local lockType = door.lock_type
    local lockData = door.lock_data or {}

    if lockType == 'public' then
        return true

    elseif lockType == 'job' then
        local player = Hydra.Players and Hydra.Players.GetPlayer(src)
        if not player or not player.job then return false, 'No job data' end

        local jobs = lockData.jobs or {}
        local minGrade = lockData.min_grade or 0
        local found = false

        for _, jobName in ipairs(jobs) do
            if player.job.name == jobName then
                found = true
                break
            end
        end

        if not found then return false, 'Wrong job' end
        if (player.job.grade or 0) < minGrade then return false, 'Insufficient grade' end
        return true

    elseif lockType == 'keypad' then
        -- Keypad is handled via separate event with code input
        return true -- Access check passes; code validation is separate

    elseif lockType == 'item' then
        -- Check inventory for item (if inventory module exists)
        local itemName = lockData.item
        if not itemName then return false, 'No item configured' end

        -- Use export if available
        local hasItem = false
        if exports and exports.hydra_inventory then
            pcall(function()
                hasItem = exports.hydra_inventory:HasItem(src, itemName)
            end)
        end

        -- Fallback: check metadata
        if not hasItem and Hydra.Players then
            local player = Hydra.Players.GetPlayer(src)
            if player and player.inventory then
                for _, item in ipairs(player.inventory) do
                    if type(item) == 'table' and item.name == itemName then
                        hasItem = true
                        break
                    end
                end
            end
        end

        if not hasItem then return false, 'Missing key item: ' .. itemName end
        return true

    elseif lockType == 'permission' then
        local perm = lockData.permission
        if not perm then return false, 'No permission configured' end
        if not IsPlayerAceAllowed(src, perm) then return false, 'No permission' end
        return true

    elseif lockType == 'owner' then
        local identifier = lockData.identifier
        if not identifier then return false, 'No owner set' end

        local playerIdent = Hydra.Players and Hydra.Players.GetIdentifier(src)
        if playerIdent ~= identifier then return false, 'Not the owner' end
        return true
    end

    return false, 'Unknown lock type'
end

-- =============================================
-- EVENTS
-- =============================================

--- Client requests to toggle a door
RegisterNetEvent('hydra:doorlock:toggle')
AddEventHandler('hydra:doorlock:toggle', function(doorId)
    local src = source
    if type(doorId) ~= 'string' then return end

    local door = doors[doorId]
    if not door then return end

    -- Distance validation
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local playerPos = GetEntityCoords(ped)
    local dist = #(playerPos - door.coords)
    if dist > cfg.interact_distance + 1.0 then return end

    -- Access check
    local canAccess, reason = Hydra.Doorlock.CanAccess(src, doorId)
    if not canAccess then
        TriggerClientEvent('hydra:doorlock:denied', src, doorId, reason)
        return
    end

    Hydra.Doorlock.Toggle(doorId, src)
end)

--- Client submits keypad code
RegisterNetEvent('hydra:doorlock:keypadSubmit')
AddEventHandler('hydra:doorlock:keypadSubmit', function(doorId, code)
    local src = source
    if type(doorId) ~= 'string' or type(code) ~= 'string' then return end

    local door = doors[doorId]
    if not door or door.lock_type ~= 'keypad' then return end

    -- Validate code
    local correctCode = door.lock_data and door.lock_data.code or ''
    if code ~= correctCode then
        TriggerClientEvent('hydra:doorlock:denied', src, doorId, 'Incorrect code')
        return
    end

    Hydra.Doorlock.Toggle(doorId, src)
end)

--- Full sync request (player join or resource start)
RegisterNetEvent('hydra:doorlock:requestSync')
AddEventHandler('hydra:doorlock:requestSync', function()
    local src = source
    TriggerClientEvent('hydra:doorlock:fullSync', src, Hydra.Doorlock.GetAll())
end)

-- =============================================
-- AUTO-LOCK TIMER
-- =============================================

CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()
        for id, lockTime in pairs(autoLockTimers) do
            if now >= lockTime then
                autoLockTimers[id] = nil
                if not doorStates[id] then
                    Hydra.Doorlock.SetLocked(id, true)
                end
            end
        end
    end
end)

-- =============================================
-- MODULE REGISTRATION
-- =============================================

Hydra.Modules.Register('doorlock', {
    label = 'Hydra Doorlock',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 40,
    dependencies = { 'data' },

    onLoad = function()
        createCollection()
        loadDoors()
    end,

    onPlayerJoin = function(src)
        TriggerClientEvent('hydra:doorlock:fullSync', src, Hydra.Doorlock.GetAll())
    end,

    api = {
        GetAll = function() return Hydra.Doorlock.GetAll() end,
        SetLocked = function(...) Hydra.Doorlock.SetLocked(...) end,
        Toggle = function(...) Hydra.Doorlock.Toggle(...) end,
        CanAccess = function(...) return Hydra.Doorlock.CanAccess(...) end,
        GetDoor = function(id) return doors[id] end,
        IsLocked = function(id) return doorStates[id] or false end,
    },
})

exports('GetDoor', function(id) return doors[id] end)
exports('IsLocked', function(id) return doorStates[id] or false end)
exports('SetLocked', function(...) Hydra.Doorlock.SetLocked(...) end)
exports('ToggleDoor', function(...) Hydra.Doorlock.Toggle(...) end)
exports('CanAccess', function(...) return Hydra.Doorlock.CanAccess(...) end)
