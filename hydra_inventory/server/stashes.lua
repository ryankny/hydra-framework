--[[
    Hydra Inventory - Stash Storage

    Named stash storage for houses, businesses, police evidence, etc.
    Stashes are keyed by a unique ID and persist via hydra_data.
]]

Hydra = Hydra or {}
Hydra.Inventory = Hydra.Inventory or {}

local cfg = HydraConfig.Inventory

-- Registered stashes: [stashId] = { items, maxSlots, maxWeight, label, owner, groups }
local stashes = {}

-- Track which players have a stash open: [src] = stashId
local openStashes = {}

-- =============================================
-- COLLECTION REGISTRATION
-- =============================================

CreateThread(function()
    Wait(0)
    if Hydra.Data and Hydra.Data.Collections then
        Hydra.Data.Collections.Create('stash_inventories', {
            { name = 'stash_id', type = 'VARCHAR(128)', index = true },
            { name = 'items',    type = 'LONGTEXT' },
            { name = 'owner',    type = 'VARCHAR(128)' },
        })
    end
end)

-- =============================================
-- STASH MANAGEMENT
-- =============================================

--- Register a stash with given options
--- @param id string Unique stash identifier
--- @param options table { label, maxSlots, maxWeight, owner, groups }
--- @return table|nil stash
function Hydra.Inventory.RegisterStash(id, options)
    if not id then return nil end

    options = options or {}

    stashes[id] = {
        id = id,
        label = options.label or ('Stash: ' .. id),
        maxSlots = options.maxSlots or cfg.stash.defaultSlots,
        maxWeight = options.maxWeight or cfg.stash.defaultWeight,
        owner = options.owner or nil,
        groups = options.groups or nil,
        items = stashes[id] and stashes[id].items or {},
    }

    Hydra.Utils.Log('debug', 'Stash "%s" registered (slots=%d, weight=%d, owner=%s)',
        id, stashes[id].maxSlots, stashes[id].maxWeight, tostring(stashes[id].owner))

    return stashes[id]
end

--- Get or load a stash by ID
--- @param id string Stash identifier
--- @return table|nil stash
function Hydra.Inventory.GetStash(id)
    if not id then return nil end

    -- Return cached if available
    if stashes[id] then
        return stashes[id]
    end

    -- Try loading from database
    local loaded = Hydra.Inventory.LoadStash(id)
    if loaded then
        return loaded
    end

    return nil
end

--- Open a stash for a player (sends data to client as secondary inventory)
--- @param src number Player source
--- @param stashId string Stash identifier
function Hydra.Inventory.OpenStash(src, stashId)
    if not src or src <= 0 then return end
    if not stashId then return end

    local stash = Hydra.Inventory.GetStash(stashId)
    if not stash then
        Hydra.Utils.Log('warn', 'Player %d tried to open unregistered stash "%s"', src, stashId)
        return
    end

    -- Check owner restriction
    if stash.owner then
        local player = Hydra.Players and Hydra.Players.GetPlayer(src)
        if not player then return end

        local identifier = player.identifier or player.citizenid or nil
        if identifier ~= stash.owner then
            TriggerClientEvent('hydra:notify', src, 'You do not have access to this stash', 'error')
            return
        end
    end

    -- Check group restriction
    if stash.groups then
        local player = Hydra.Players and Hydra.Players.GetPlayer(src)
        if not player then return end

        local hasAccess = false
        local playerJob = player.job and player.job.name or nil

        if playerJob then
            for _, group in ipairs(stash.groups) do
                if type(group) == 'string' and group == playerJob then
                    hasAccess = true
                    break
                elseif type(group) == 'table' and group.name == playerJob then
                    local minGrade = group.grade or 0
                    local playerGrade = player.job and player.job.grade or 0
                    if playerGrade >= minGrade then
                        hasAccess = true
                        break
                    end
                end
            end
        end

        if not hasAccess then
            TriggerClientEvent('hydra:notify', src, 'You do not have access to this stash', 'error')
            return
        end
    end

    openStashes[src] = stashId

    -- Get player inventory
    local player = Hydra.Players and Hydra.Players.GetPlayer(src)
    local playerItems = player and player.inventory or {}

    -- Send stash and player inventory to client
    TriggerClientEvent('hydra:inventory:stash:opened', src, {
        id = stash.id,
        label = stash.label,
        items = stash.items,
        maxSlots = stash.maxSlots,
        maxWeight = stash.maxWeight,
    }, playerItems)

    Hydra.Utils.Log('debug', 'Player %d opened stash "%s"', src, stashId)
end

--- Save a stash to hydra_data
--- @param id string Stash identifier
function Hydra.Inventory.SaveStash(id)
    local stash = stashes[id]
    if not stash then return end

    local ok, err = pcall(function()
        if Hydra.Data and Hydra.Data.Update then
            local existing = Hydra.Data.FindOne('stash_inventories', {
                stash_id = id,
            })

            local data = {
                stash_id = id,
                label = stash.label,
                items = json.encode(stash.items),
                max_slots = stash.maxSlots,
                max_weight = stash.maxWeight,
                owner = stash.owner,
            }

            if existing then
                Hydra.Data.Update('stash_inventories', { stash_id = id }, data)
            else
                Hydra.Data.Create('stash_inventories', data)
            end
        end
    end)

    if not ok then
        Hydra.Utils.Log('error', 'Failed to save stash "%s": %s', id, tostring(err))
    end
end

--- Load a stash from hydra_data
--- @param id string Stash identifier
--- @return table|nil
function Hydra.Inventory.LoadStash(id)
    local result
    local ok, err = pcall(function()
        if Hydra.Data and Hydra.Data.FindOne then
            result = Hydra.Data.FindOne('stash_inventories', {
                stash_id = id,
            })
        end
    end)

    if not ok then
        Hydra.Utils.Log('error', 'Failed to load stash "%s": %s', id, tostring(err))
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

    stashes[id] = {
        id = id,
        label = result.label or ('Stash: ' .. id),
        items = items,
        maxSlots = result.max_slots or cfg.stash.defaultSlots,
        maxWeight = result.max_weight or cfg.stash.defaultWeight,
        owner = result.owner or nil,
        groups = stashes[id] and stashes[id].groups or nil,
    }

    return stashes[id]
end

--- Clear a stash (empty all items)
--- @param id string Stash identifier
function Hydra.Inventory.ClearStash(id)
    if stashes[id] then
        stashes[id].items = {}
    end

    -- Also clear in database
    pcall(function()
        if Hydra.Data and Hydra.Data.Update then
            Hydra.Data.Update('stash_inventories', { stash_id = id }, {
                items = json.encode({}),
            })
        end
    end)

    Hydra.Utils.Log('debug', 'Cleared stash "%s"', id)
end

-- =============================================
-- EVENTS
-- =============================================

--- Client requests to open a stash
RegisterNetEvent('hydra:inventory:stash:open')
AddEventHandler('hydra:inventory:stash:open', function(stashId)
    local src = source
    if not src or src <= 0 then return end
    if type(stashId) ~= 'string' or #stashId > 128 then return end

    Hydra.Inventory.OpenStash(src, stashId)
end)

--- Client closes a stash
RegisterNetEvent('hydra:inventory:stash:close')
AddEventHandler('hydra:inventory:stash:close', function(updatedItems)
    local src = source
    if not src or src <= 0 then return end

    local stashId = openStashes[src]
    if not stashId then return end

    -- Update items if provided by client (after drag-drop operations)
    if updatedItems and stashes[stashId] then
        stashes[stashId].items = updatedItems
    end

    Hydra.Inventory.SaveStash(stashId)

    openStashes[src] = nil

    Hydra.Utils.Log('debug', 'Player %d closed stash "%s"', src, stashId)
end)

-- =============================================
-- CLEANUP ON PLAYER DROP
-- =============================================

AddEventHandler('playerDropped', function()
    local src = source

    -- Save and close any open stash
    local stashId = openStashes[src]
    if stashId then
        Hydra.Inventory.SaveStash(stashId)
        openStashes[src] = nil
    end
end)

-- =============================================
-- EXPORTS
-- =============================================

exports('RegisterStash', function(...) return Hydra.Inventory.RegisterStash(...) end)
exports('GetStash', function(...) return Hydra.Inventory.GetStash(...) end)
exports('OpenStash', function(...) return Hydra.Inventory.OpenStash(...) end)
exports('SaveStash', function(...) return Hydra.Inventory.SaveStash(...) end)
exports('ClearStash', function(...) return Hydra.Inventory.ClearStash(...) end)
