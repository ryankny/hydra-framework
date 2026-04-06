--[[
    Hydra Inventory - Client Drops

    World drop rendering, prop management, and pickup interaction.
    Drops are created/removed by the server; this file handles the
    visual representation and player interaction only.
]]

Hydra = Hydra or {}
Hydra.Inventory = Hydra.Inventory or {}

local cfg = HydraConfig.Inventory

-- State: [dropId] = { id, coords, object, items }
local drops = {}

-- Cache frequently used natives
local GetEntityCoords = GetEntityCoords
local PlayerPedId = PlayerPedId
local DoesEntityExist = DoesEntityExist
local DeleteEntity = DeleteEntity
local CreateObject = CreateObject
local SetEntityAsMissionEntity = SetEntityAsMissionEntity
local PlaceObjectOnGroundProperly = PlaceObjectOnGroundProperly
local FreezeEntityPosition = FreezeEntityPosition
local RequestModel = RequestModel
local HasModelLoaded = HasModelLoaded
local SetModelAsNoLongerNeeded = SetModelAsNoLongerNeeded
local DrawMarker = DrawMarker
local IsControlJustPressed = IsControlJustPressed
local Wait = Citizen.Wait

-- Optional module detection
local hasTarget = false

CreateThread(function()
    Wait(1500)
    hasTarget = pcall(function() return exports['hydra_target'] end)
end)

-- =============================================
-- MODEL LOADING HELPER
-- =============================================

--- Request and wait for a model to load
--- @param model number hash
--- @return boolean loaded
local function loadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 5000 do
        Wait(10)
        t = t + 10
    end
    return HasModelLoaded(model)
end

-- =============================================
-- DROP PROP MANAGEMENT
-- =============================================

--- Determine which prop model to use based on total weight
--- @param items table
--- @return number modelHash
local function getDropModel(items)
    local totalWeight = 0
    if items then
        totalWeight = Hydra.Inventory.CalculateWeight(items)
    end
    local modelName = cfg.drops.bagModel
    if totalWeight < cfg.drops.smallDropWeight then
        modelName = cfg.drops.smallDropModel
    end
    return GetHashKey(modelName)
end

--- Spawn a drop prop at the given coordinates
--- @param coords vector3
--- @param items table
--- @return number|nil entity
local function spawnDropProp(coords, items)
    local model = getDropModel(items)
    if not loadModel(model) then return nil end

    local obj = CreateObject(model, coords.x, coords.y, coords.z - 1.0, false, true, false)
    if not obj or obj == 0 then
        SetModelAsNoLongerNeeded(model)
        return nil
    end

    SetEntityAsMissionEntity(obj, true, true)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(model)

    return obj
end

--- Delete a drop prop
--- @param entity number
local function deleteDropProp(entity)
    if entity and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, false, true)
        DeleteEntity(entity)
    end
end

-- =============================================
-- TARGET INTERACTION REGISTRATION
-- =============================================

--- Register pickup interaction on a drop prop via hydra_target
--- @param dropId number|string
--- @param entity number
local function registerTargetInteraction(dropId, entity)
    if not hasTarget or not entity or entity == 0 then return end

    pcall(function()
        exports['hydra_target']:AddEntity(entity, {
            {
                label = 'Pick Up',
                icon = 'hand-grab',
                distance = cfg.drops.pickupDistance,
                onSelect = function()
                    TriggerServerEvent('hydra:inventory:drop:pickup', dropId)
                end,
            },
        })
    end)
end

-- =============================================
-- SERVER EVENT HANDLERS
-- =============================================

--- Create a new world drop
RegisterNetEvent('hydra:inventory:client:drops:create')
AddEventHandler('hydra:inventory:client:drops:create', function(data)
    if not data or not data.id or not data.coords then return end

    local coords = vector3(data.coords.x, data.coords.y, data.coords.z)
    local obj = spawnDropProp(coords, data.items)

    drops[data.id] = {
        id = data.id,
        coords = coords,
        object = obj,
        items = data.items or {},
    }

    if obj then
        registerTargetInteraction(data.id, obj)
    end
end)

--- Remove an existing world drop
RegisterNetEvent('hydra:inventory:client:drops:remove')
AddEventHandler('hydra:inventory:client:drops:remove', function(dropId)
    local drop = drops[dropId]
    if not drop then return end

    deleteDropProp(drop.object)
    drops[dropId] = nil
end)

--- Sync all existing drops on player join
RegisterNetEvent('hydra:inventory:client:drops:sync')
AddEventHandler('hydra:inventory:client:drops:sync', function(allDrops)
    if not allDrops then return end

    -- Clear any stale local drops first
    for id, drop in pairs(drops) do
        deleteDropProp(drop.object)
        drops[id] = nil
    end

    -- Recreate all active drops
    for _, data in pairs(allDrops) do
        if data and data.id and data.coords then
            local coords = vector3(data.coords.x, data.coords.y, data.coords.z)
            local obj = spawnDropProp(coords, data.items)

            drops[data.id] = {
                id = data.id,
                coords = coords,
                object = obj,
                items = data.items or {},
            }

            if obj then
                registerTargetInteraction(data.id, obj)
            end
        end
    end
end)

-- =============================================
-- RENDER THREAD - Markers and text above drops
-- =============================================

CreateThread(function()
    Wait(2000) -- staggered start

    while true do
        local ped = PlayerPedId()
        local playerPos = GetEntityCoords(ped)
        local hasDrop = false

        for id, drop in pairs(drops) do
            local dist = #(playerPos - drop.coords)

            if dist < 50.0 then
                hasDrop = true

                if dist < 10.0 then
                    -- Draw marker above drop
                    DrawMarker(
                        2,                                      -- type: chevron
                        drop.coords.x, drop.coords.y, drop.coords.z + 0.5,
                        0.0, 0.0, 0.0,                         -- dir
                        0.0, 180.0, 0.0,                        -- rot
                        0.15, 0.15, 0.15,                       -- scale
                        108, 92, 231, 180,                      -- RGBA (hydra purple)
                        true, true, 2, false, nil, nil, false
                    )

                    -- Draw floating text
                    local textCoords = drop.coords + vector3(0.0, 0.0, 0.8)
                    SetTextFont(4)
                    SetTextScale(0.0, 0.28)
                    SetTextColour(255, 255, 255, 200)
                    SetTextDropshadow(1, 0, 0, 0, 200)
                    SetTextOutline()
                    SetTextCentre(true)
                    SetTextEntry('STRING')
                    AddTextComponentString('Drop')
                    SetDrawOrigin(textCoords.x, textCoords.y, textCoords.z, 0)
                    DrawText(0.0, 0.0)
                    ClearDrawOrigin()

                    -- Pickup prompt within range (fallback for no hydra_target)
                    if dist <= cfg.drops.pickupDistance and not hasTarget then
                        SetTextFont(4)
                        SetTextScale(0.0, 0.32)
                        SetTextColour(255, 255, 255, 240)
                        SetTextDropshadow(1, 0, 0, 0, 200)
                        SetTextOutline()
                        SetTextCentre(true)
                        SetTextEntry('STRING')
                        AddTextComponentString('[E] Pick Up')
                        SetDrawOrigin(drop.coords.x, drop.coords.y, drop.coords.z + 0.35, 0)
                        DrawText(0.0, 0.0)
                        ClearDrawOrigin()

                        if IsControlJustPressed(0, 38) then -- E key
                            TriggerServerEvent('hydra:inventory:drop:pickup', id)
                        end
                    end
                end
            end
        end

        if hasDrop then
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- =============================================
-- CLEANUP ON RESOURCE STOP
-- =============================================

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for id, drop in pairs(drops) do
        deleteDropProp(drop.object)
    end
    drops = {}
end)
