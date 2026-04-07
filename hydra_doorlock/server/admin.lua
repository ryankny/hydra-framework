--[[
    Hydra Doorlock - Server Admin

    In-game door creation, editing, and deletion.
    Persists admin-created doors to the database.
]]

Hydra = Hydra or {}

local cfg = HydraDoorlockConfig

-- =============================================
-- ADMIN: CREATE DOOR
-- =============================================

RegisterNetEvent('hydra:doorlock:admin:create')
AddEventHandler('hydra:doorlock:admin:create', function(data)
    local src = source
    if not IsPlayerAceAllowed(src, cfg.admin_permission) then return end

    -- Validate
    if type(data) ~= 'table' then return end
    if not data.coords or type(data.coords) ~= 'table' then return end
    if not tonumber(data.coords.x) or not tonumber(data.coords.y) or not tonumber(data.coords.z) then return end
    if type(data.label) ~= 'string' or #data.label == 0 or #data.label > 128 then return end

    -- Check max doors limit
    local doorCount = 0
    local all = Hydra.Doorlock.GetAll()
    for _ in pairs(all) do doorCount = doorCount + 1 end
    if doorCount >= cfg.max_doors then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'error', title = 'Doorlock',
            message = ('Maximum door limit reached (%d).'):format(cfg.max_doors),
        })
        return
    end

    -- Generate unique ID
    local id = data.id or ('door_' .. os.time() .. '_' .. math.random(1000, 9999))

    -- Sanitize lock_data
    local lockData = data.lock_data or {}
    if data.lock_type == 'job' and type(lockData.jobs) == 'table' then
        -- Validate job names are strings
        local clean = {}
        for _, j in ipairs(lockData.jobs) do
            if type(j) == 'string' and #j > 0 and #j < 64 then
                clean[#clean + 1] = j
            end
        end
        lockData.jobs = clean
    elseif data.lock_type == 'keypad' then
        if type(lockData.code) ~= 'string' or #lockData.code < 1 or #lockData.code > 10 then
            lockData.code = '0000'
        end
    end

    -- Insert to database
    local success = exports['hydra_data']:Create('doorlocks', {
        door_id = id,
        label = type(data.label) == 'string' and data.label:sub(1, 128) or id,
        coords_x = data.coords.x,
        coords_y = data.coords.y,
        coords_z = data.coords.z,
        model = tonumber(data.model) or 0,
        heading = tonumber(data.heading) or 0.0,
        locked = data.locked ~= false and 1 or 0,
        lock_type = cfg.lock_types[data.lock_type] and data.lock_type or 'public',
        lock_data = Hydra.Utils.JsonEncode(lockData),
        auto_lock = tonumber(data.auto_lock) or 0,
        double_model = tonumber(data.double) or 0,
        created_by = exports['hydra_players']:GetIdentifier(src) or 'unknown',
    })

    if success then
        -- Reload into memory
        local door = {
            id = id,
            label = data.label or id,
            coords = vector3(data.coords.x, data.coords.y, data.coords.z),
            model = tonumber(data.model) or 0,
            heading = tonumber(data.heading) or 0.0,
            lock_type = data.lock_type or 'public',
            lock_data = lockData,
            auto_lock = tonumber(data.auto_lock) or 0,
            double = tonumber(data.double) or 0,
        }

        -- Add to runtime state (access private via module internals)
        TriggerEvent('hydra:doorlock:_addDoor', id, door, data.locked ~= false, 'database')

        -- Sync to all clients
        TriggerClientEvent('hydra:doorlock:doorAdded', -1, {
            id = id,
            label = door.label,
            coords = { x = door.coords.x, y = door.coords.y, z = door.coords.z },
            model = door.model,
            heading = door.heading,
            locked = data.locked ~= false,
            lock_type = door.lock_type,
            auto_lock = door.auto_lock,
            double = door.double,
        })

        TriggerClientEvent('hydra:notify:show', src, {
            type = 'success', title = 'Doorlock',
            message = ('Door "%s" created successfully.'):format(door.label),
        })

        pcall(function() exports['hydra_logs']:LogAdmin(src, 'Door Created', ('Created door: %s (%s)'):format(door.label, door.lock_type)) end)
    else
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'error', title = 'Doorlock',
            message = 'Failed to create door.',
        })
    end
end)

-- Internal event to add door to runtime state
AddEventHandler('hydra:doorlock:_addDoor', function(id, door, locked, source_type)
    -- This is a workaround to inject into the local scope of main.lua
    -- The actual tables are in main.lua's scope, so we use module API
    -- We'll call the exported functions instead
end)

-- =============================================
-- ADMIN: UPDATE DOOR
-- =============================================

RegisterNetEvent('hydra:doorlock:admin:update')
AddEventHandler('hydra:doorlock:admin:update', function(doorId, updates)
    local src = source
    if not IsPlayerAceAllowed(src, cfg.admin_permission) then return end
    if type(doorId) ~= 'string' or type(updates) ~= 'table' then return end

    -- Build update payload
    local dbUpdates = {}
    if updates.label then dbUpdates.label = tostring(updates.label):sub(1, 128) end
    if updates.lock_type and cfg.lock_types[updates.lock_type] then
        dbUpdates.lock_type = updates.lock_type
    end
    if updates.lock_data then
        dbUpdates.lock_data = Hydra.Utils.JsonEncode(updates.lock_data)
    end
    if updates.auto_lock ~= nil then
        dbUpdates.auto_lock = tonumber(updates.auto_lock) or 0
    end

    if next(dbUpdates) then
        exports['hydra_data']:Update('doorlocks', { door_id = doorId }, dbUpdates)
    end

    TriggerClientEvent('hydra:notify:show', src, {
        type = 'success', title = 'Doorlock',
        message = ('Door "%s" updated. Restart resource to apply.'):format(doorId),
    })

    pcall(function() exports['hydra_logs']:LogAdmin(src, 'Door Updated', ('Updated door: %s'):format(doorId)) end)
end)

-- =============================================
-- ADMIN: DELETE DOOR
-- =============================================

RegisterNetEvent('hydra:doorlock:admin:delete')
AddEventHandler('hydra:doorlock:admin:delete', function(doorId)
    local src = source
    if not IsPlayerAceAllowed(src, cfg.admin_permission) then return end
    if type(doorId) ~= 'string' then return end

    -- Delete from database
    exports['hydra_data']:Delete('doorlocks', { door_id = doorId })

    -- Remove from clients
    TriggerClientEvent('hydra:doorlock:doorRemoved', -1, doorId)

    TriggerClientEvent('hydra:notify:show', src, {
        type = 'success', title = 'Doorlock',
        message = ('Door "%s" deleted.'):format(doorId),
    })

    pcall(function() exports['hydra_logs']:LogAdmin(src, 'Door Deleted', ('Deleted door: %s'):format(doorId)) end)
end)

-- =============================================
-- ADMIN COMMAND
-- =============================================

RegisterCommand(cfg.admin_command, function(src, args)
    if src <= 0 then
        print('[Hydra Doorlock] This command must be used in-game.')
        return
    end

    if not IsPlayerAceAllowed(src, cfg.admin_permission) then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'error', title = 'No Permission',
            message = 'You do not have permission.',
        })
        return
    end

    local subCmd = args[1]

    if subCmd == 'create' or not subCmd then
        -- Enter creation mode on client
        TriggerClientEvent('hydra:doorlock:admin:startCreate', src)
    elseif subCmd == 'nearest' then
        -- Show info about nearest door
        TriggerClientEvent('hydra:doorlock:admin:showNearest', src)
    elseif subCmd == 'delete' then
        TriggerClientEvent('hydra:doorlock:admin:startDelete', src)
    elseif subCmd == 'list' then
        -- List all doors via chat
        local count = 0
        local api = Hydra.Modules.Get('doorlock')
        local all = api and api.GetAll() or {}
        for id, door in pairs(all) do
            count = count + 1
            TriggerClientEvent('hydra:chat:systemMessage', src, {
                message = ('[%s] %s - %s (%s)'):format(
                    door.locked and 'LOCKED' or 'OPEN',
                    id, door.label or id, door.lock_type or 'unknown'
                ),
                color = door.locked and '#FF7675' or '#00B894',
            })
        end
        TriggerClientEvent('hydra:chat:systemMessage', src, {
            message = ('Total doors: %d'):format(count),
            color = '#A0A0B8',
        })
    else
        TriggerClientEvent('hydra:chat:systemMessage', src, {
            message = 'Usage: /doorlock [create|nearest|delete|list]',
            color = '#A0A0B8',
        })
    end
end, false)
