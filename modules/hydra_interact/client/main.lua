--[[
    Hydra Interact - Client
    Unified interaction layer orchestrating target, zones, context, and input.
    Provides a single API for creating interactive points, entities, and zones.
]]

Hydra = Hydra or {}
Hydra.Interact = {}

local cfg = HydraConfig.Interact
local interactions = {}      -- { [id] = { type, options, targetId, zoneId, enabled, tag, ... } }
local interactCounter = 0
local lastInteract = 0
local hooksBefore = {}
local hooksAfter = {}

-- Module availability flags (set on ready)
local hasTarget = false
local hasZones = false
local hasContext = false
local hasBridge = false

local function nextId()
    interactCounter = interactCounter + 1
    return 'int_' .. interactCounter
end

-- ── Module Detection ──

local function detectModules()
    hasTarget = pcall(function() return exports['hydra_target'] end) and cfg.use_target
    hasZones = pcall(function() return exports['hydra_zones'] end) and cfg.use_zones
    hasContext = pcall(function() return exports['hydra_context'] end)
    hasBridge = pcall(function() return exports['hydra_bridge'] end)

    if cfg.debug then
        Hydra.Utils.Log('debug', '[Interact] Modules: target=%s zones=%s context=%s bridge=%s',
            tostring(hasTarget), tostring(hasZones), tostring(hasContext), tostring(hasBridge))
    end
end

-- ── Permission Checking ──

local function checkGroups(groups)
    if not groups then return true end
    if type(groups) == 'string' then groups = { groups } end
    if not hasBridge then return true end

    local ok, playerData = pcall(function()
        return exports['hydra_bridge']:GetPlayerData()
    end)
    if not ok or not playerData then return true end

    for _, group in ipairs(groups) do
        if playerData.job and playerData.job.name == group then
            return true
        end
    end
    return false
end

-- ── Cooldown ──

local function canInteract()
    local now = GetGameTimer()
    if now - lastInteract < cfg.cooldown then return false end
    return true
end

local function markInteracted()
    lastInteract = GetGameTimer()
end

-- ── Interaction Handler ──

local function handleInteraction(id, entity, coords)
    local data = interactions[id]
    if not data or not data.enabled then return end
    if not canInteract() then return end

    -- Run before hooks
    for _, hook in ipairs(hooksBefore) do
        if hook(id, data) == false then return end
    end

    -- Check groups
    if not checkGroups(data.options.groups) then return end

    -- Check canInteract callback
    if data.options.canInteract and not data.options.canInteract({
        id = id,
        entity = entity,
        coords = coords,
        metadata = data.options.metadata,
    }) then return end

    markInteracted()

    local passData = {
        id = id,
        entity = entity,
        coords = coords or data.options.coords,
        metadata = data.options.metadata,
    }

    -- Single action
    if data.options.onSelect and not data.options.options then
        data.options.onSelect(passData)
        for _, hook in ipairs(hooksAfter) do hook(id, passData) end
        return
    end

    -- Single event
    if data.options.event and not data.options.options then
        TriggerEvent(data.options.event, passData)
        for _, hook in ipairs(hooksAfter) do hook(id, passData) end
        return
    end

    if data.options.serverEvent and not data.options.options then
        TriggerServerEvent(data.options.serverEvent, passData)
        for _, hook in ipairs(hooksAfter) do hook(id, passData) end
        return
    end

    -- Multi-option: use context menu
    if data.options.options and #data.options.options > 0 then
        local items = {}
        for _, opt in ipairs(data.options.options) do
            local canDo = true
            if opt.canInteract then
                canDo = opt.canInteract(passData)
            end
            if canDo then
                items[#items + 1] = {
                    label = opt.label,
                    icon = opt.icon,
                    description = opt.description,
                    disabled = opt.disabled,
                    onSelect = function()
                        if opt.onSelect then
                            opt.onSelect(passData)
                        end
                        if opt.event then
                            TriggerEvent(opt.event, opt.args or passData)
                        end
                        if opt.serverEvent then
                            TriggerServerEvent(opt.serverEvent, opt.args or passData)
                        end
                        for _, hook in ipairs(hooksAfter) do hook(id, passData) end
                    end,
                }
            end
        end

        if #items == 0 then return end

        if hasContext then
            pcall(function()
                exports['hydra_context']:Show({
                    title = data.options.label or 'Interact',
                    items = items,
                })
            end)
        elseif #items == 1 then
            -- Fallback: just trigger the first item
            if items[1].onSelect then items[1].onSelect() end
        end
        return
    end

    -- Simple select with no options list
    if data.options.onSelect then
        data.options.onSelect(passData)
    end
    for _, hook in ipairs(hooksAfter) do hook(id, passData) end
end

-- ── Target Integration ──

local function buildTargetOptions(id, options)
    local targetOpts = {}
    if options.options and #options.options > 0 then
        for _, opt in ipairs(options.options) do
            targetOpts[#targetOpts + 1] = {
                label = opt.label or options.label or 'Interact',
                icon = opt.icon or options.icon,
                distance = options.distance or cfg.default_distance,
                canInteract = function(entity, dist, coords)
                    if not interactions[id] or not interactions[id].enabled then return false end
                    if not checkGroups(options.groups) then return false end
                    if opt.canInteract then
                        return opt.canInteract({ id = id, entity = entity, coords = coords, metadata = options.metadata })
                    end
                    return true
                end,
                onSelect = function(entity, coords)
                    local passData = { id = id, entity = entity, coords = coords, metadata = options.metadata }
                    if opt.onSelect then opt.onSelect(passData) end
                    if opt.event then TriggerEvent(opt.event, opt.args or passData) end
                    if opt.serverEvent then TriggerServerEvent(opt.serverEvent, opt.args or passData) end
                    for _, hook in ipairs(hooksAfter) do hook(id, passData) end
                end,
            }
        end
    else
        targetOpts[#targetOpts + 1] = {
            label = options.label or 'Interact',
            icon = options.icon,
            distance = options.distance or cfg.default_distance,
            canInteract = function(entity, dist, coords)
                if not interactions[id] or not interactions[id].enabled then return false end
                if not checkGroups(options.groups) then return false end
                if options.canInteract then
                    return options.canInteract({ id = id, entity = entity, coords = coords, metadata = options.metadata })
                end
                return true
            end,
            onSelect = function(entity, coords)
                handleInteraction(id, entity, coords)
            end,
        }
    end
    return targetOpts
end

-- ── Core API ──

function Hydra.Interact.AddPoint(options)
    if not cfg.enabled then return nil end
    if not options or not options.coords then return nil end

    local count = 0
    for _ in pairs(interactions) do count = count + 1 end
    if count >= cfg.max_active_points then
        Hydra.Utils.Log('warn', '[Interact] Max interaction points reached (%d)', cfg.max_active_points)
        return nil
    end

    local id = nextId()
    local distance = math.min(options.distance or cfg.default_distance, cfg.max_distance)
    options.distance = distance

    local data = {
        type = 'point',
        options = options,
        targetId = nil,
        zoneId = nil,
        enabled = true,
        tag = options.tag,
    }

    -- Register with target system
    if hasTarget then
        local ok, targetId = pcall(function()
            return exports['hydra_target']:AddCoord(options.coords, distance, buildTargetOptions(id, options))
        end)
        if ok and targetId then
            data.targetId = targetId
        end
    end

    -- Register zone for proximity detection
    if hasZones and (options.useZone ~= false) then
        local ok, zoneId = pcall(function()
            return exports['hydra_zones']:AddSphere(options.coords, distance, {
                name = 'interact_' .. id,
                metadata = { interactId = id },
                onEnter = function() end,
                onExit = function() end,
            })
        end)
        if ok and zoneId then
            data.zoneId = zoneId
        end
    end

    interactions[id] = data

    if cfg.debug then
        Hydra.Utils.Log('debug', '[Interact] AddPoint %s at %.1f, %.1f, %.1f',
            id, options.coords.x, options.coords.y, options.coords.z)
    end

    return id
end

function Hydra.Interact.AddEntity(entity, options)
    if not cfg.enabled then return nil end
    if not entity or not DoesEntityExist(entity) then return nil end

    options = options or {}
    local id = nextId()
    local distance = math.min(options.distance or cfg.default_distance, cfg.max_distance)
    options.distance = distance

    local data = {
        type = 'entity',
        entity = entity,
        options = options,
        targetId = nil,
        enabled = true,
        tag = options.tag,
    }

    if hasTarget then
        local ok, targetId = pcall(function()
            return exports['hydra_target']:AddEntity(entity, buildTargetOptions(id, options))
        end)
        if ok and targetId then
            data.targetId = targetId
        end
    end

    interactions[id] = data

    -- Entity validity watcher
    CreateThread(function()
        while interactions[id] do
            Wait(2000)
            if not DoesEntityExist(entity) then
                Hydra.Interact.Remove(id)
                break
            end
        end
    end)

    return id
end

function Hydra.Interact.AddModel(model, options)
    if not cfg.enabled then return nil end

    options = options or {}
    local id = nextId()
    local modelHash = type(model) == 'string' and GetHashKey(model) or model
    options.distance = math.min(options.distance or cfg.default_distance, cfg.max_distance)

    local data = {
        type = 'model',
        model = modelHash,
        options = options,
        targetId = nil,
        enabled = true,
        tag = options.tag,
    }

    if hasTarget then
        local ok, targetId = pcall(function()
            return exports['hydra_target']:AddModel(modelHash, buildTargetOptions(id, options))
        end)
        if ok and targetId then
            data.targetId = targetId
        end
    end

    interactions[id] = data
    return id
end

function Hydra.Interact.AddNetEntity(netId, options)
    if not cfg.enabled then return nil end
    if not netId then return nil end

    -- Wait for entity to exist
    local entity = nil
    local attempts = 0
    while not entity or not DoesEntityExist(entity) do
        entity = NetworkGetEntityFromNetworkId(netId)
        attempts = attempts + 1
        if attempts > 50 then return nil end
        Wait(100)
    end

    return Hydra.Interact.AddEntity(entity, options)
end

function Hydra.Interact.AddLocalEntity(entity, options)
    return Hydra.Interact.AddEntity(entity, options)
end

function Hydra.Interact.AddZone(zoneType, zoneData, options)
    if not cfg.enabled then return nil end
    if not zoneType or not zoneData then return nil end

    options = options or {}
    local id = nextId()

    local data = {
        type = 'zone',
        zoneType = zoneType,
        zoneData = zoneData,
        options = options,
        zoneId = nil,
        enabled = true,
        tag = options.tag,
    }

    if hasZones then
        local ok, zoneId
        if zoneType == 'sphere' then
            ok, zoneId = pcall(function()
                return exports['hydra_zones']:AddSphere(zoneData.center, zoneData.radius, {
                    name = 'interact_zone_' .. id,
                    metadata = { interactId = id },
                    onEnter = function()
                        handleInteraction(id, nil, zoneData.center)
                    end,
                    onExit = function() end,
                })
            end)
        elseif zoneType == 'box' then
            ok, zoneId = pcall(function()
                return exports['hydra_zones']:AddBox(zoneData.min, zoneData.max, {
                    name = 'interact_zone_' .. id,
                    metadata = { interactId = id },
                    onEnter = function()
                        handleInteraction(id, nil, (zoneData.min + zoneData.max) / 2)
                    end,
                    onExit = function() end,
                })
            end)
        elseif zoneType == 'poly' then
            ok, zoneId = pcall(function()
                return exports['hydra_zones']:AddPoly(zoneData.points, zoneData.minZ, zoneData.maxZ, {
                    name = 'interact_zone_' .. id,
                    metadata = { interactId = id },
                    onEnter = function()
                        handleInteraction(id, nil, nil)
                    end,
                    onExit = function() end,
                })
            end)
        end
        if ok and zoneId then
            data.zoneId = zoneId
        end
    end

    interactions[id] = data
    return id
end

-- ── Management API ──

function Hydra.Interact.Remove(id)
    local data = interactions[id]
    if not data then return end

    -- Clean up target registration
    if data.targetId and hasTarget then
        pcall(function()
            if data.type == 'entity' then
                exports['hydra_target']:RemoveEntity(data.targetId)
            elseif data.type == 'model' then
                exports['hydra_target']:RemoveModel(data.targetId)
            elseif data.type == 'point' then
                exports['hydra_target']:RemoveCoord(data.targetId)
            end
        end)
    end

    -- Clean up zone registration
    if data.zoneId and hasZones then
        pcall(function()
            exports['hydra_zones']:Remove(data.zoneId)
        end)
    end

    interactions[id] = nil

    if cfg.debug then
        Hydra.Utils.Log('debug', '[Interact] Removed %s', id)
    end
end

function Hydra.Interact.RemoveByTag(tag)
    if not tag then return end
    local toRemove = {}
    for id, data in pairs(interactions) do
        if data.tag == tag then
            toRemove[#toRemove + 1] = id
        end
    end
    for _, id in ipairs(toRemove) do
        Hydra.Interact.Remove(id)
    end
end

function Hydra.Interact.SetEnabled(id, enabled)
    local data = interactions[id]
    if data then
        data.enabled = enabled
    end
end

function Hydra.Interact.Exists(id)
    return interactions[id] ~= nil
end

function Hydra.Interact.GetAll()
    local ids = {}
    for id in pairs(interactions) do
        ids[#ids + 1] = id
    end
    return ids
end

function Hydra.Interact.GetNearby()
    local nearby = {}
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)

    for id, data in pairs(interactions) do
        if data.enabled then
            local dist = nil
            if data.options.coords then
                dist = #(playerCoords - data.options.coords)
            elseif data.entity and DoesEntityExist(data.entity) then
                dist = #(playerCoords - GetEntityCoords(data.entity))
            end

            if dist and dist <= (data.options.distance or cfg.default_distance) then
                nearby[#nearby + 1] = {
                    id = id,
                    distance = dist,
                    type = data.type,
                    label = data.options.label,
                }
            end
        end
    end

    table.sort(nearby, function(a, b) return a.distance < b.distance end)
    return nearby
end

function Hydra.Interact.Refresh()
    local existing = {}
    for id, data in pairs(interactions) do
        existing[#existing + 1] = { id = id, data = data }
    end

    -- Re-register all
    for _, entry in ipairs(existing) do
        Hydra.Interact.Remove(entry.id)
    end
    for _, entry in ipairs(existing) do
        local d = entry.data
        if d.type == 'point' then
            Hydra.Interact.AddPoint(d.options)
        elseif d.type == 'entity' and d.entity then
            Hydra.Interact.AddEntity(d.entity, d.options)
        elseif d.type == 'model' then
            Hydra.Interact.AddModel(d.model, d.options)
        elseif d.type == 'zone' then
            Hydra.Interact.AddZone(d.zoneType, d.zoneData, d.options)
        end
    end
end

-- ── Hooks ──

function Hydra.Interact.OnBefore(fn)
    if type(fn) == 'function' then
        hooksBefore[#hooksBefore + 1] = fn
    end
end

function Hydra.Interact.OnAfter(fn)
    if type(fn) == 'function' then
        hooksAfter[#hooksAfter + 1] = fn
    end
end

-- ── Proximity Prompt System (fallback when no target) ──

CreateThread(function()
    -- Wait for modules to be available
    Wait(2000)
    detectModules()

    if hasTarget then return end -- target system handles prompts

    -- Fallback proximity loop
    while true do
        Wait(cfg.tick_rate)
        if not cfg.enabled or not cfg.show_prompts then goto continue end

        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        local closest = nil
        local closestDist = cfg.max_distance

        for id, data in pairs(interactions) do
            if data.enabled and data.options.coords then
                local dist = #(playerCoords - data.options.coords)
                if dist < closestDist then
                    closestDist = dist
                    closest = data
                end
            end
        end

        if closest and closest.options.label then
            -- Draw prompt
            SetTextComponentFormat('STRING')
            AddTextComponentString(string.format(cfg.prompt_format, closest.options.label))
            DisplayHelpTextFromStringLabel(0, false, true, -1)
        end

        ::continue::
    end
end)

-- ── Proximity Interact Key (fallback) ──

CreateThread(function()
    Wait(2500)
    if hasTarget then return end

    while true do
        Wait(0)
        if IsControlJustPressed(0, 38) then -- E key
            local nearby = Hydra.Interact.GetNearby()
            if #nearby > 0 then
                handleInteraction(nearby[1].id, nil, nil)
            end
        end
    end
end)

-- ── Entity Outline ──

if cfg.outline_entities then
    CreateThread(function()
        Wait(2500)
        if not hasTarget then return end

        -- Entity outlining is handled by hydra_target
        -- We just ensure our entities are registered properly
    end)
end

-- ── Server Events ──

RegisterNetEvent('hydra:interact:trigger')
AddEventHandler('hydra:interact:trigger', function(id)
    if id and interactions[id] then
        handleInteraction(id, nil, nil)
    end
end)

RegisterNetEvent('hydra:interact:override')
AddEventHandler('hydra:interact:override', function(key, value)
    if key and cfg[key] ~= nil then
        cfg[key] = value
    end
end)

-- ── Exports ──

exports('AddPoint', function(opts) return Hydra.Interact.AddPoint(opts) end)
exports('AddEntity', function(e, opts) return Hydra.Interact.AddEntity(e, opts) end)
exports('AddModel', function(m, opts) return Hydra.Interact.AddModel(m, opts) end)
exports('AddNetEntity', function(n, opts) return Hydra.Interact.AddNetEntity(n, opts) end)
exports('AddLocalEntity', function(e, opts) return Hydra.Interact.AddLocalEntity(e, opts) end)
exports('AddZone', function(t, d, opts) return Hydra.Interact.AddZone(t, d, opts) end)
exports('Remove', function(id) return Hydra.Interact.Remove(id) end)
exports('RemoveByTag', function(tag) return Hydra.Interact.RemoveByTag(tag) end)
exports('SetEnabled', function(id, e) return Hydra.Interact.SetEnabled(id, e) end)
exports('Exists', function(id) return Hydra.Interact.Exists(id) end)
exports('GetAll', function() return Hydra.Interact.GetAll() end)
exports('GetNearby', function() return Hydra.Interact.GetNearby() end)
exports('Refresh', function() return Hydra.Interact.Refresh() end)
exports('OnBefore', function(fn) return Hydra.Interact.OnBefore(fn) end)
exports('OnAfter', function(fn) return Hydra.Interact.OnAfter(fn) end)

-- ── Resource Cleanup ──

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(interactions) do
        Hydra.Interact.Remove(id)
    end
end)
