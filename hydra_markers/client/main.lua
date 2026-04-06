--[[
    Hydra Markers - Client

    Client-side 3D marker, checkpoint, and floating text management.
    Uses a two-thread architecture: a slow proximity check thread
    maintains a small set of nearby markers, and a fast render thread
    only iterates that subset every frame.
]]

Hydra = Hydra or {}
Hydra.Markers = Hydra.Markers or {}

local cfg = HydraConfig.Markers

-- =============================================
-- INTERNAL STATE
-- =============================================

local markers = {}          -- [id] = marker data
local floatingTexts = {}    -- [id] = floating text data
local checkpoints = {}      -- [id] = checkpoint data

local markerCounter = 0
local textCounter = 0
local cpCounter = 0

local nearbyMarkers = {}    -- [id] = marker ref (subset within drawDistance)
local nearbyTexts = {}      -- [id] = text ref (subset within drawDistance)
local insideMarkers = {}    -- [id] = true (markers the player is currently inside)

local globalEnterHandlers = {}
local globalExitHandlers = {}

-- Cache frequently used functions
local GetEntityCoords = GetEntityCoords
local PlayerPedId = PlayerPedId
local DrawMarker = DrawMarker
local Wait = Citizen.Wait
local pairs = pairs
local pcall = pcall

-- =============================================
-- UTILITY
-- =============================================

--- Squared distance between two vec3 points (avoids sqrt)
--- @param a vector3
--- @param b vector3
--- @return number
local function distSq(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return dx * dx + dy * dy + dz * dz
end

--- Actual distance between two vec3 points
--- @param a vector3
--- @param b vector3
--- @return number
local function dist(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

--- Draw 3D floating text at world coords
--- @param text string
--- @param coords vector3
--- @param color table {r,g,b,a}
--- @param font number|nil
--- @param scale number|nil
local function drawFloatingText(text, coords, color, font, scale)
    SetTextFont(font or cfg.float_text_font)
    SetTextScale(0.0, scale or cfg.float_text_scale)
    SetTextColour(color.r, color.g, color.b, color.a)
    SetTextDropshadow(1, 0, 0, 0, 200)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

--- Fire enter event for a marker
--- @param id number
--- @param marker table
--- @param coords vector3
local function fireEnter(id, marker, coords)
    insideMarkers[id] = true

    if marker.onEnter then
        pcall(marker.onEnter, id)
    end

    for i = 1, #globalEnterHandlers do
        pcall(globalEnterHandlers[i], id, coords)
    end

    TriggerEvent('hydra:markers:enter', id, coords)
end

--- Fire exit event for a marker
--- @param id number
--- @param marker table
--- @param coords vector3
local function fireExit(id, marker, coords)
    insideMarkers[id] = nil

    if marker.onExit then
        pcall(marker.onExit, id)
    end

    for i = 1, #globalExitHandlers do
        pcall(globalExitHandlers[i], id, coords)
    end

    TriggerEvent('hydra:markers:exit', id, coords)
end

-- =============================================
-- CORE API - MARKERS
-- =============================================

--- Add a 3D marker
--- @param options table
--- @return number markerId
function Hydra.Markers.Add(options)
    if not options or not options.coords then
        error('Hydra.Markers.Add: coords is required')
    end

    -- Enforce max markers
    if markerCounter >= cfg.max_markers then
        if cfg.debug then
            print('[hydra_markers] WARNING: Max marker limit reached (' .. cfg.max_markers .. ')')
        end
        return -1
    end

    markerCounter = markerCounter + 1
    local id = markerCounter

    local drawDist = options.drawDistance or cfg.default_draw_distance
    if drawDist > cfg.max_draw_distance then
        drawDist = cfg.max_draw_distance
    end

    local enterDist = options.enterDistance or 1.5

    markers[id] = {
        type        = options.type or cfg.default_marker_type,
        coords      = options.coords,
        scale       = options.scale or cfg.default_scale,
        color       = options.color or {
            r = cfg.default_color.r,
            g = cfg.default_color.g,
            b = cfg.default_color.b,
            a = cfg.default_color.a,
        },
        rotation    = options.rotation or vector3(0.0, 0.0, 0.0),
        direction   = options.direction or vector3(0.0, 0.0, 0.0),
        bobUpDown   = options.bobUpDown ~= nil and options.bobUpDown or cfg.default_bob,
        faceCamera  = options.faceCamera or false,
        rotate      = options.rotate ~= nil and options.rotate or cfg.default_rotate,
        drawDist    = drawDist,
        drawDistSq  = drawDist * drawDist,
        enterDist   = enterDist,
        enterDistSq = enterDist * enterDist,
        visible     = options.visible ~= false,
        label       = options.label,
        labelOffset = options.labelOffset or vector3(0.0, 0.0, 1.5),
        labelColor  = options.labelColor,
        owner       = options.owner,
        tag         = options.tag,
        metadata    = options.metadata or {},
        onEnter     = options.onEnter,
        onExit      = options.onExit,
        onNearby    = options.onNearby,
        _distance   = 0.0,
    }

    return id
end

--- Remove a marker
--- @param id number
function Hydra.Markers.Remove(id)
    if not markers[id] then return end

    -- Clean up proximity state
    nearbyMarkers[id] = nil

    -- Fire exit if player was inside
    if insideMarkers[id] then
        fireExit(id, markers[id], GetEntityCoords(PlayerPedId()))
    end

    markers[id] = nil
end

--- Bulk remove by owner
--- @param owner string
--- @return number count removed
function Hydra.Markers.RemoveByOwner(owner)
    local count = 0
    local toRemove = {}
    for id, m in pairs(markers) do
        if m.owner == owner then
            toRemove[#toRemove + 1] = id
        end
    end
    for i = 1, #toRemove do
        Hydra.Markers.Remove(toRemove[i])
        count = count + 1
    end
    return count
end

--- Bulk remove by tag
--- @param tag string
--- @return number count removed
function Hydra.Markers.RemoveByTag(tag)
    local count = 0
    local toRemove = {}
    for id, m in pairs(markers) do
        if m.tag == tag then
            toRemove[#toRemove + 1] = id
        end
    end
    for i = 1, #toRemove do
        Hydra.Markers.Remove(toRemove[i])
        count = count + 1
    end
    return count
end

--- Remove all markers
--- @return number count removed
function Hydra.Markers.RemoveAll()
    local count = 0
    local toRemove = {}
    for id in pairs(markers) do
        toRemove[#toRemove + 1] = id
    end
    for i = 1, #toRemove do
        Hydra.Markers.Remove(toRemove[i])
        count = count + 1
    end
    return count
end

-- =============================================
-- MODIFY API
-- =============================================

--- Set marker coords
--- @param id number
--- @param coords vector3
function Hydra.Markers.SetCoords(id, coords)
    if not markers[id] then return end
    markers[id].coords = coords
end

--- Set marker color
--- @param id number
--- @param r number
--- @param g number
--- @param b number
--- @param a number
function Hydra.Markers.SetColor(id, r, g, b, a)
    if not markers[id] then return end
    markers[id].color = { r = r, g = g, b = b, a = a }
end

--- Set marker scale
--- @param id number
--- @param scale vector3
function Hydra.Markers.SetScale(id, scale)
    if not markers[id] then return end
    markers[id].scale = scale
end

--- Set marker visibility
--- @param id number
--- @param visible boolean
function Hydra.Markers.SetVisible(id, visible)
    if not markers[id] then return end
    markers[id].visible = visible
end

--- Set marker label text
--- @param id number
--- @param text string|nil
function Hydra.Markers.SetLabel(id, text)
    if not markers[id] then return end
    markers[id].label = text
end

--- Set a metadata value
--- @param id number
--- @param key string
--- @param value any
function Hydra.Markers.SetMetadata(id, key, value)
    if not markers[id] then return end
    markers[id].metadata[key] = value
end

--- Get a metadata value
--- @param id number
--- @param key string
--- @return any
function Hydra.Markers.GetMetadata(id, key)
    if not markers[id] then return nil end
    return markers[id].metadata[key]
end

-- =============================================
-- QUERY API
-- =============================================

--- Get marker info (safe copy of relevant fields)
--- @param id number
--- @return table|nil
function Hydra.Markers.Get(id)
    local m = markers[id]
    if not m then return nil end
    return {
        id = id,
        type = m.type,
        coords = m.coords,
        scale = m.scale,
        color = m.color,
        rotation = m.rotation,
        visible = m.visible,
        label = m.label,
        owner = m.owner,
        tag = m.tag,
        metadata = m.metadata,
        drawDistance = m.drawDist,
        enterDistance = m.enterDist,
    }
end

--- Check if marker exists
--- @param id number
--- @return boolean
function Hydra.Markers.Exists(id)
    return markers[id] ~= nil
end

--- Get all marker IDs
--- @return table
function Hydra.Markers.GetAll()
    local result = {}
    for id in pairs(markers) do
        result[#result + 1] = id
    end
    return result
end

--- Get marker IDs by tag
--- @param tag string
--- @return table
function Hydra.Markers.GetByTag(tag)
    local result = {}
    for id, m in pairs(markers) do
        if m.tag == tag then
            result[#result + 1] = id
        end
    end
    return result
end

--- Get markers near a position
--- @param coords vector3
--- @param radius number
--- @return table array of {id, distance}
function Hydra.Markers.GetNearby(coords, radius)
    local result = {}
    local radiusSq = radius * radius
    for id, m in pairs(markers) do
        local dSq = distSq(coords, m.coords)
        if dSq <= radiusSq then
            result[#result + 1] = { id = id, distance = math.sqrt(dSq) }
        end
    end
    -- Sort by distance ascending
    table.sort(result, function(a, b) return a.distance < b.distance end)
    return result
end

--- Check if player is inside a specific marker
--- @param id number
--- @return boolean
function Hydra.Markers.IsInside(id)
    return insideMarkers[id] == true
end

--- Get all markers the player is currently inside
--- @return table array of IDs
function Hydra.Markers.GetInsideMarkers()
    local result = {}
    for id in pairs(insideMarkers) do
        result[#result + 1] = id
    end
    return result
end

--- Get total marker count
--- @return number
function Hydra.Markers.GetCount()
    local count = 0
    for _ in pairs(markers) do
        count = count + 1
    end
    return count
end

-- =============================================
-- FLOATING TEXT API
-- =============================================

--- Add standalone floating text (not attached to a marker)
--- @param options table { coords, text, color, font, scale, drawDistance, owner, tag }
--- @return number textId
function Hydra.Markers.AddText(options)
    if not options or not options.coords or not options.text then
        error('Hydra.Markers.AddText: coords and text are required')
    end

    textCounter = textCounter + 1
    local id = textCounter

    local drawDist = options.drawDistance or cfg.default_draw_distance
    if drawDist > cfg.max_draw_distance then
        drawDist = cfg.max_draw_distance
    end

    floatingTexts[id] = {
        coords     = options.coords,
        text       = options.text,
        color      = options.color or {
            r = cfg.float_text_color.r,
            g = cfg.float_text_color.g,
            b = cfg.float_text_color.b,
            a = cfg.float_text_color.a,
        },
        font       = options.font or cfg.float_text_font,
        scale      = options.scale or cfg.float_text_scale,
        drawDist   = drawDist,
        drawDistSq = drawDist * drawDist,
        owner      = options.owner,
        tag        = options.tag,
    }

    return id
end

--- Remove floating text
--- @param id number
function Hydra.Markers.RemoveText(id)
    if not floatingTexts[id] then return end
    nearbyTexts[id] = nil
    floatingTexts[id] = nil
end

--- Update floating text content
--- @param id number
--- @param text string
function Hydra.Markers.SetText(id, text)
    if not floatingTexts[id] then return end
    floatingTexts[id].text = text
end

--- Remove all floating texts by tag
--- @param tag string
--- @return number count removed
function Hydra.Markers.RemoveTextByTag(tag)
    local count = 0
    local toRemove = {}
    for id, ft in pairs(floatingTexts) do
        if ft.tag == tag then
            toRemove[#toRemove + 1] = id
        end
    end
    for i = 1, #toRemove do
        Hydra.Markers.RemoveText(toRemove[i])
        count = count + 1
    end
    return count
end

-- =============================================
-- CHECKPOINT API
-- =============================================

--- Add a GTA native checkpoint
--- @param options table { type, coords, nextCoords, radius, color, onReach }
--- @return number cpId
function Hydra.Markers.AddCheckpoint(options)
    if not options or not options.coords then
        error('Hydra.Markers.AddCheckpoint: coords is required')
    end

    cpCounter = cpCounter + 1
    local id = cpCounter

    local cpType = options.type or 0
    local coords = options.coords
    local nextCoords = options.nextCoords or coords
    local radius = options.radius or 3.0
    local color = options.color or {
        r = cfg.default_color.r,
        g = cfg.default_color.g,
        b = cfg.default_color.b,
        a = cfg.default_color.a,
    }

    local handle = CreateCheckpoint(
        cpType,
        coords.x, coords.y, coords.z,
        nextCoords.x, nextCoords.y, nextCoords.z,
        radius,
        color.r, color.g, color.b, color.a,
        0
    )

    -- Set the cylinder height for ground-level checkpoints
    SetCheckpointCylinderHeight(handle, radius, radius, radius)

    checkpoints[id] = {
        handle     = handle,
        coords     = coords,
        nextCoords = nextCoords,
        type       = cpType,
        radius     = radius,
        radiusSq   = radius * radius,
        color      = color,
        onReach    = options.onReach,
        reached    = false,
    }

    return id
end

--- Remove a checkpoint
--- @param id number
function Hydra.Markers.RemoveCheckpoint(id)
    local cp = checkpoints[id]
    if not cp then return end
    DeleteCheckpoint(cp.handle)
    checkpoints[id] = nil
end

--- Remove all checkpoints
--- @return number count removed
function Hydra.Markers.RemoveAllCheckpoints()
    local count = 0
    local toRemove = {}
    for id in pairs(checkpoints) do
        toRemove[#toRemove + 1] = id
    end
    for i = 1, #toRemove do
        Hydra.Markers.RemoveCheckpoint(toRemove[i])
        count = count + 1
    end
    return count
end

-- =============================================
-- GLOBAL HOOKS
-- =============================================

--- Register a global enter handler (fires for any marker)
--- @param handler function(markerId, coords)
--- @return number handlerId
function Hydra.Markers.OnEnter(handler)
    globalEnterHandlers[#globalEnterHandlers + 1] = handler
    return #globalEnterHandlers
end

--- Register a global exit handler (fires for any marker)
--- @param handler function(markerId, coords)
--- @return number handlerId
function Hydra.Markers.OnExit(handler)
    globalExitHandlers[#globalExitHandlers + 1] = handler
    return #globalExitHandlers
end

-- =============================================
-- PROXIMITY CHECK THREAD
-- =============================================

CreateThread(function()
    if not cfg.enabled then return end

    while true do
        Wait(cfg.proximity_check_rate)

        local playerCoords = GetEntityCoords(PlayerPedId())
        local newNearbyMarkers = {}
        local newNearbyTexts = {}

        -- Check markers
        for id, m in pairs(markers) do
            local dSq = distSq(playerCoords, m.coords)
            m._distance = math.sqrt(dSq)

            -- Draw distance check
            if dSq <= m.drawDistSq then
                newNearbyMarkers[id] = m
            else
                -- If was nearby but no longer, also handle exit
                if insideMarkers[id] then
                    fireExit(id, m, playerCoords)
                end
            end

            -- Enter/exit distance check
            if dSq <= m.enterDistSq then
                if not insideMarkers[id] then
                    fireEnter(id, m, playerCoords)
                end
            else
                if insideMarkers[id] then
                    fireExit(id, m, playerCoords)
                end
            end
        end

        -- Check floating texts
        for id, ft in pairs(floatingTexts) do
            local dSq = distSq(playerCoords, ft.coords)
            if dSq <= ft.drawDistSq then
                newNearbyTexts[id] = ft
            end
        end

        -- Check checkpoints for reach
        for id, cp in pairs(checkpoints) do
            if not cp.reached then
                local dSq = distSq(playerCoords, cp.coords)
                if dSq <= cp.radiusSq then
                    cp.reached = true

                    if cfg.checkpoint_flash then
                        -- Brief color flash on reach
                        SetCheckpointRgba(cp.handle, 255, 255, 255, 200)
                        SetTimeout(200, function()
                            if checkpoints[id] then
                                SetCheckpointRgba(cp.handle, cp.color.r, cp.color.g, cp.color.b, cp.color.a)
                            end
                        end)
                    end

                    if cp.onReach then
                        pcall(cp.onReach, id)
                    end

                    TriggerEvent('hydra:markers:checkpointReach', id, cp.coords)
                end
            end
        end

        -- Swap references atomically
        nearbyMarkers = newNearbyMarkers
        nearbyTexts = newNearbyTexts
    end
end)

-- =============================================
-- RENDER THREAD
-- =============================================

CreateThread(function()
    if not cfg.enabled then return end

    local tickRate = cfg.tick_rate

    while true do
        Wait(tickRate)

        -- Draw nearby markers
        for id, m in pairs(nearbyMarkers) do
            if m.visible then
                DrawMarker(
                    m.type,
                    m.coords.x, m.coords.y, m.coords.z,
                    m.direction.x, m.direction.y, m.direction.z,
                    m.rotation.x, m.rotation.y, m.rotation.z,
                    m.scale.x, m.scale.y, m.scale.z,
                    m.color.r, m.color.g, m.color.b, m.color.a,
                    m.bobUpDown, m.faceCamera, 2, m.rotate, nil, nil, false
                )

                -- Draw label if present
                if m.label then
                    local labelCoords = m.coords + m.labelOffset
                    drawFloatingText(
                        m.label,
                        labelCoords,
                        m.labelColor or cfg.float_text_color
                    )
                end

                -- Fire onNearby callback
                if m.onNearby then
                    pcall(m.onNearby, id, m._distance)
                end
            end
        end

        -- Draw nearby floating texts
        for id, ft in pairs(nearbyTexts) do
            drawFloatingText(ft.text, ft.coords, ft.color, ft.font, ft.scale)
        end
    end
end)

-- =============================================
-- SERVER-SYNCED MARKERS
-- =============================================

RegisterNetEvent('hydra:markers:create')
AddEventHandler('hydra:markers:create', function(options)
    Hydra.Markers.Add(options)
end)

RegisterNetEvent('hydra:markers:remove')
AddEventHandler('hydra:markers:remove', function(id)
    Hydra.Markers.Remove(id)
end)

RegisterNetEvent('hydra:markers:removeByTag')
AddEventHandler('hydra:markers:removeByTag', function(tag)
    Hydra.Markers.RemoveByTag(tag)
end)

-- =============================================
-- CLEANUP
-- =============================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Remove all markers
    for id in pairs(markers) do
        markers[id] = nil
    end
    nearbyMarkers = {}
    insideMarkers = {}

    -- Remove all floating texts
    for id in pairs(floatingTexts) do
        floatingTexts[id] = nil
    end
    nearbyTexts = {}

    -- Remove all checkpoints (native handles must be deleted)
    for id, cp in pairs(checkpoints) do
        DeleteCheckpoint(cp.handle)
    end
    checkpoints = {}
end)

-- =============================================
-- EXPORTS
-- =============================================

-- Markers
exports('Add', function(...) return Hydra.Markers.Add(...) end)
exports('Remove', function(...) Hydra.Markers.Remove(...) end)
exports('RemoveByOwner', function(...) return Hydra.Markers.RemoveByOwner(...) end)
exports('RemoveByTag', function(...) return Hydra.Markers.RemoveByTag(...) end)
exports('RemoveAll', function() return Hydra.Markers.RemoveAll() end)

-- Modify
exports('SetCoords', function(...) Hydra.Markers.SetCoords(...) end)
exports('SetColor', function(...) Hydra.Markers.SetColor(...) end)
exports('SetScale', function(...) Hydra.Markers.SetScale(...) end)
exports('SetVisible', function(...) Hydra.Markers.SetVisible(...) end)
exports('SetLabel', function(...) Hydra.Markers.SetLabel(...) end)
exports('SetMetadata', function(...) Hydra.Markers.SetMetadata(...) end)
exports('GetMetadata', function(...) return Hydra.Markers.GetMetadata(...) end)

-- Query
exports('Get', function(...) return Hydra.Markers.Get(...) end)
exports('Exists', function(...) return Hydra.Markers.Exists(...) end)
exports('GetAll', function() return Hydra.Markers.GetAll() end)
exports('GetByTag', function(...) return Hydra.Markers.GetByTag(...) end)
exports('GetNearby', function(...) return Hydra.Markers.GetNearby(...) end)
exports('IsInside', function(...) return Hydra.Markers.IsInside(...) end)
exports('GetInsideMarkers', function() return Hydra.Markers.GetInsideMarkers() end)
exports('GetCount', function() return Hydra.Markers.GetCount() end)

-- Floating text
exports('AddText', function(...) return Hydra.Markers.AddText(...) end)
exports('RemoveText', function(...) Hydra.Markers.RemoveText(...) end)
exports('SetText', function(...) Hydra.Markers.SetText(...) end)
exports('RemoveTextByTag', function(...) return Hydra.Markers.RemoveTextByTag(...) end)

-- Checkpoints
exports('AddCheckpoint', function(...) return Hydra.Markers.AddCheckpoint(...) end)
exports('RemoveCheckpoint', function(...) Hydra.Markers.RemoveCheckpoint(...) end)
exports('RemoveAllCheckpoints', function() return Hydra.Markers.RemoveAllCheckpoints() end)

-- Hooks
exports('OnEnter', function(...) return Hydra.Markers.OnEnter(...) end)
exports('OnExit', function(...) return Hydra.Markers.OnExit(...) end)
