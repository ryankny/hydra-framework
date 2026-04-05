--[[
    Hydra Zones - Server

    Server-side zone registry. Zones can be registered from
    server and synced to clients. Also supports server-side
    point-in-zone checks for validation.
]]

Hydra = Hydra or {}
Hydra.Zones = Hydra.Zones or {}

local zones = {}
local nextId = 1

--- Register a zone (server-side, will be synced to clients)
--- @param data table zone definition
--- @return number zoneId
function Hydra.Zones.Register(data)
    local id = nextId
    nextId = nextId + 1

    zones[id] = {
        id = id,
        name = data.name or ('zone_' .. id),
        type = data.type or 'poly', -- 'poly', 'sphere', 'box'
        points = data.points,        -- polygon vertices
        center = data.center,        -- sphere/box center
        radius = data.radius,        -- sphere radius
        min = data.min,              -- box min corner
        max = data.max,              -- box max corner
        minZ = data.minZ,
        maxZ = data.maxZ,
        metadata = data.metadata or {},
    }

    -- Sync to all clients
    TriggerClientEvent('hydra:zones:register', -1, zones[id])

    return id
end

--- Remove a zone
--- @param id number
function Hydra.Zones.Remove(id)
    zones[id] = nil
    TriggerClientEvent('hydra:zones:remove', -1, id)
end

--- Get all zones
function Hydra.Zones.GetAll()
    return zones
end

--- Check if a point is in a registered zone (server-side)
--- @param point vector3
--- @param zoneId number
--- @return boolean
function Hydra.Zones.IsPointInZone(point, zoneId)
    local zone = zones[zoneId]
    if not zone then return false end

    if zone.type == 'sphere' then
        return Hydra.Zones.Math.PointInSphere(point, zone.center, zone.radius)
    elseif zone.type == 'box' then
        return Hydra.Zones.Math.PointInBox(point, zone.min, zone.max)
    elseif zone.type == 'poly' then
        return Hydra.Zones.Math.PointInPolyZone(point, zone.points, zone.minZ or -100, zone.maxZ or 1000)
    end
    return false
end

--- Sync all zones to a newly joined player
RegisterNetEvent('hydra:zones:requestSync')
AddEventHandler('hydra:zones:requestSync', function()
    local src = source
    for _, zone in pairs(zones) do
        TriggerClientEvent('hydra:zones:register', src, zone)
    end
end)

--- Module registration
Hydra.Modules.Register('zones', {
    label = 'Hydra Zones',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 55,
    dependencies = {},

    onLoad = function()
        Hydra.Utils.Log('info', 'Zones module loaded')
    end,

    onPlayerJoin = function(src)
        -- Send all registered zones to new player
        for _, zone in pairs(zones) do
            TriggerClientEvent('hydra:zones:register', src, zone)
        end
    end,

    api = {
        Register = function(...) return Hydra.Zones.Register(...) end,
        Remove = function(...) Hydra.Zones.Remove(...) end,
        GetAll = function() return Hydra.Zones.GetAll() end,
        IsPointInZone = function(...) return Hydra.Zones.IsPointInZone(...) end,
    },
})

exports('RegisterZone', function(...) return Hydra.Zones.Register(...) end)
exports('RemoveZone', function(...) Hydra.Zones.Remove(...) end)
exports('IsPointInZone', function(...) return Hydra.Zones.IsPointInZone(...) end)
