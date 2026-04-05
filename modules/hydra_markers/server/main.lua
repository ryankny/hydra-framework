--[[
    Hydra Markers - Server

    Module registration, admin commands, and server-side marker
    creation that syncs to clients.
]]

Hydra = Hydra or {}
Hydra.Markers = Hydra.Markers or {}

local cfg = HydraConfig.Markers
local syncedMarkers = {}
local nextSyncId = 1

-- =============================================
-- SERVER API
-- =============================================

--- Create a marker on a specific client
--- @param playerId number server ID (-1 for all)
--- @param options table marker options (same as client Add)
--- @return number syncId
function Hydra.Markers.CreateClient(playerId, options)
    local id = nextSyncId
    nextSyncId = nextSyncId + 1

    options._syncId = id
    syncedMarkers[id] = { target = playerId, options = options }

    TriggerClientEvent('hydra:markers:create', playerId, options)
    return id
end

--- Create a marker on all clients
--- @param options table
--- @return number syncId
function Hydra.Markers.CreateAll(options)
    return Hydra.Markers.CreateClient(-1, options)
end

--- Remove a synced marker from a specific client
--- @param playerId number server ID (-1 for all)
--- @param syncId number
function Hydra.Markers.RemoveClient(playerId, syncId)
    syncedMarkers[syncId] = nil
    TriggerClientEvent('hydra:markers:remove', playerId, syncId)
end

--- Remove a synced marker from all clients
--- @param syncId number
function Hydra.Markers.RemoveAll(syncId)
    Hydra.Markers.RemoveClient(-1, syncId)
end

-- =============================================
-- SERVER EVENTS
-- =============================================

RegisterNetEvent('hydra:markers:create')
AddEventHandler('hydra:markers:create', function(options)
    -- Server-originated only; block client spoofing
end)

RegisterNetEvent('hydra:markers:remove')
AddEventHandler('hydra:markers:remove', function(id)
    -- Server-originated only
end)

RegisterNetEvent('hydra:markers:removeByTag')
AddEventHandler('hydra:markers:removeByTag', function(tag)
    -- Server-originated only
end)

-- Sync existing markers to joining players
RegisterNetEvent('hydra:markers:requestSync')
AddEventHandler('hydra:markers:requestSync', function()
    local src = source
    for id, entry in pairs(syncedMarkers) do
        if entry.target == -1 or entry.target == src then
            TriggerClientEvent('hydra:markers:create', src, entry.options)
        end
    end
end)

-- =============================================
-- ADMIN COMMANDS
-- =============================================

RegisterCommand('markers', function(source, args, rawCommand)
    local src = source

    -- Console always allowed; for players check admin
    if src > 0 then
        if Hydra.Admin and not Hydra.Admin.HasPermission(src, 'markers') then
            TriggerClientEvent('chat:addMessage', src, {
                args = { 'Hydra', 'Insufficient permissions.' },
            })
            return
        end
    end

    local sub = args[1]

    if sub == 'info' then
        local count = 0
        for _ in pairs(syncedMarkers) do count = count + 1 end

        local msg = ('[hydra_markers] Synced markers: %d'):format(count)
        if src > 0 then
            TriggerClientEvent('chat:addMessage', src, {
                args = { 'Hydra Markers', msg },
            })
        else
            print(msg)
        end

    elseif sub == 'clear' then
        local targetId = tonumber(args[2])

        if targetId then
            -- Clear markers for specific player
            local toRemove = {}
            for id, entry in pairs(syncedMarkers) do
                if entry.target == targetId or entry.target == -1 then
                    toRemove[#toRemove + 1] = id
                end
            end
            for _, id in ipairs(toRemove) do
                TriggerClientEvent('hydra:markers:remove', targetId, id)
                if syncedMarkers[id] and syncedMarkers[id].target == targetId then
                    syncedMarkers[id] = nil
                end
            end

            local msg = ('[hydra_markers] Cleared %d markers for player %d'):format(#toRemove, targetId)
            if src > 0 then
                TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Markers', msg } })
            else
                print(msg)
            end
        else
            -- Clear all synced markers
            local count = 0
            for id in pairs(syncedMarkers) do
                count = count + 1
            end
            TriggerClientEvent('hydra:markers:removeByTag', -1, '__all__')
            syncedMarkers = {}

            local msg = ('[hydra_markers] Cleared all %d synced markers'):format(count)
            if src > 0 then
                TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Markers', msg } })
            else
                print(msg)
            end
        end
    else
        local usage = 'Usage: /markers [info|clear [playerId]]'
        if src > 0 then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Markers', usage } })
        else
            print(usage)
        end
    end
end, false)

-- =============================================
-- MODULE REGISTRATION
-- =============================================

Hydra.Modules.Register('markers', {
    label = 'Hydra Markers',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 50,
    dependencies = {},

    onLoad = function()
        Hydra.Utils.Log('info', 'Markers module loaded')
    end,

    onPlayerJoin = function(src)
        for id, entry in pairs(syncedMarkers) do
            if entry.target == -1 or entry.target == src then
                TriggerClientEvent('hydra:markers:create', src, entry.options)
            end
        end
    end,

    api = {
        CreateClient = function(...) return Hydra.Markers.CreateClient(...) end,
        CreateAll = function(...) return Hydra.Markers.CreateAll(...) end,
        RemoveClient = function(...) Hydra.Markers.RemoveClient(...) end,
        RemoveAll = function(...) Hydra.Markers.RemoveAll(...) end,
    },
})

-- =============================================
-- EXPORTS
-- =============================================

exports('CreateClient', function(...) return Hydra.Markers.CreateClient(...) end)
exports('CreateAll', function(...) return Hydra.Markers.CreateAll(...) end)
exports('RemoveClient', function(...) Hydra.Markers.RemoveClient(...) end)
exports('RemoveAllServer', function(...) Hydra.Markers.RemoveAll(...) end)
