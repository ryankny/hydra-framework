--[[
    Hydra Zones - Client

    Client-side zone management. Tracks player position and
    fires enter/exit events. Zones can be registered locally
    (client-only) or received from server.
]]

Hydra = Hydra or {}
Hydra.Zones = Hydra.Zones or {}

local cfg = HydraZonesConfig

-- Zone registry
local zones = {}
local localNextId = 100000  -- Local zones start at high ID to avoid server collisions

-- Player zone state
local insideZones = {}  -- [zoneId] = true

-- Event handlers
local enterHandlers = {} -- [zoneId] = function|nil
local exitHandlers = {}  -- [zoneId] = function|nil
local globalEnterHandlers = {} -- array of functions
local globalExitHandlers = {}  -- array of functions

-- =============================================
-- LOCAL REGISTRATION API
-- =============================================

--- Register a zone on the client
--- @param data table zone definition
--- @return number zoneId
function Hydra.Zones.Add(data)
    local id = localNextId
    localNextId = localNextId + 1

    zones[id] = {
        id = id,
        name = data.name or ('zone_' .. id),
        type = data.type or 'poly',
        points = data.points,
        center = data.center,
        radius = data.radius,
        min = data.min,
        max = data.max,
        minZ = data.minZ,
        maxZ = data.maxZ,
        metadata = data.metadata or {},
        onEnter = data.onEnter,
        onExit = data.onExit,
    }

    if data.onEnter then enterHandlers[id] = data.onEnter end
    if data.onExit then exitHandlers[id] = data.onExit end

    return id
end

--- Convenience: Add a sphere zone
--- @param center vector3
--- @param radius number
--- @param data table|nil extra fields (name, metadata, onEnter, onExit)
--- @return number
function Hydra.Zones.AddSphere(center, radius, data)
    data = data or {}
    data.type = 'sphere'
    data.center = center
    data.radius = radius
    return Hydra.Zones.Add(data)
end

--- Convenience: Add a box zone
--- @param min vector3
--- @param max vector3
--- @param data table|nil
--- @return number
function Hydra.Zones.AddBox(min, max, data)
    data = data or {}
    data.type = 'box'
    data.min = min
    data.max = max
    return Hydra.Zones.Add(data)
end

--- Convenience: Add a poly zone
--- @param points table[] array of { x, y } or vector2
--- @param minZ number
--- @param maxZ number
--- @param data table|nil
--- @return number
function Hydra.Zones.AddPoly(points, minZ, maxZ, data)
    data = data or {}
    data.type = 'poly'
    data.points = points
    data.minZ = minZ
    data.maxZ = maxZ
    return Hydra.Zones.Add(data)
end

--- Remove a zone
--- @param id number
function Hydra.Zones.Remove(id)
    zones[id] = nil
    enterHandlers[id] = nil
    exitHandlers[id] = nil
    insideZones[id] = nil
end

--- Register a global enter handler (fires for any zone)
--- @param handler function(zoneId, zoneName, metadata)
--- @return number handlerId
function Hydra.Zones.OnEnter(handler)
    globalEnterHandlers[#globalEnterHandlers + 1] = handler
    return #globalEnterHandlers
end

--- Register a global exit handler
--- @param handler function(zoneId, zoneName, metadata)
--- @return number handlerId
function Hydra.Zones.OnExit(handler)
    globalExitHandlers[#globalExitHandlers + 1] = handler
    return #globalExitHandlers
end

--- Check if player is in a specific zone
--- @param id number
--- @return boolean
function Hydra.Zones.IsInZone(id)
    return insideZones[id] == true
end

--- Get all zones the player is currently inside
--- @return table
function Hydra.Zones.GetCurrentZones()
    local result = {}
    for id in pairs(insideZones) do
        result[#result + 1] = id
    end
    return result
end

-- =============================================
-- SERVER-SYNCED ZONES
-- =============================================

RegisterNetEvent('hydra:zones:register')
AddEventHandler('hydra:zones:register', function(zone)
    zones[zone.id] = zone
end)

RegisterNetEvent('hydra:zones:remove')
AddEventHandler('hydra:zones:remove', function(id)
    Hydra.Zones.Remove(id)
end)

-- Request sync on resource start
CreateThread(function()
    Wait(500)
    TriggerServerEvent('hydra:zones:requestSync')
end)

-- =============================================
-- ZONE CHECK LOOP
-- =============================================

--- Check if a point is inside a zone
--- @param point vector3
--- @param zone table
--- @return boolean
local function isPointInZone(point, zone)
    if zone.type == 'sphere' then
        return Hydra.Zones.Math.PointInSphere(point, zone.center, zone.radius)
    elseif zone.type == 'box' then
        return Hydra.Zones.Math.PointInBox(point, zone.min, zone.max)
    elseif zone.type == 'poly' then
        return Hydra.Zones.Math.PointInPolyZone(point, zone.points, zone.minZ or -100, zone.maxZ or 1000)
    end
    return false
end

--- Fire enter event
local function fireEnter(id, zone)
    insideZones[id] = true

    -- Zone-specific handler
    if enterHandlers[id] then
        pcall(enterHandlers[id], id, zone.name, zone.metadata)
    end

    -- Global handlers
    for _, handler in ipairs(globalEnterHandlers) do
        pcall(handler, id, zone.name, zone.metadata)
    end

    -- Event
    TriggerEvent('hydra:zones:enter', id, zone.name, zone.metadata)
end

--- Fire exit event
local function fireExit(id, zone)
    insideZones[id] = nil

    if exitHandlers[id] then
        pcall(exitHandlers[id], id, zone.name, zone.metadata)
    end

    for _, handler in ipairs(globalExitHandlers) do
        pcall(handler, id, zone.name, zone.metadata)
    end

    TriggerEvent('hydra:zones:exit', id, zone.name, zone.metadata)
end

-- Main check loop
CreateThread(function()
    while true do
        Wait(cfg.tick_rate)

        local playerPos = GetEntityCoords(PlayerPedId())

        for id, zone in pairs(zones) do
            local isInside = isPointInZone(playerPos, zone)
            local wasInside = insideZones[id]

            if isInside and not wasInside then
                fireEnter(id, zone)
            elseif not isInside and wasInside then
                fireExit(id, zone)
            end
        end
    end
end)

-- Debug draw
if cfg.debug then
    CreateThread(function()
        while true do
            Wait(0)
            for _, zone in pairs(zones) do
                if zone.type == 'sphere' and zone.center then
                    DrawMarker(28, zone.center.x, zone.center.y, zone.center.z,
                        0, 0, 0, 0, 0, 0,
                        zone.radius * 2, zone.radius * 2, zone.radius * 2,
                        108, 92, 231, 40, false, true, 2, nil, nil, false)
                end
            end
        end
    end)
end

-- =============================================
-- EXPORTS
-- =============================================

exports('AddZone', function(...) return Hydra.Zones.Add(...) end)
exports('AddSphere', function(...) return Hydra.Zones.AddSphere(...) end)
exports('AddBox', function(...) return Hydra.Zones.AddBox(...) end)
exports('AddPoly', function(...) return Hydra.Zones.AddPoly(...) end)
exports('RemoveZone', function(...) Hydra.Zones.Remove(...) end)
exports('IsInZone', function(...) return Hydra.Zones.IsInZone(...) end)
exports('GetCurrentZones', function() return Hydra.Zones.GetCurrentZones() end)
exports('OnZoneEnter', function(...) return Hydra.Zones.OnEnter(...) end)
exports('OnZoneExit', function(...) return Hydra.Zones.OnExit(...) end)
