--[[
    Hydra Inventory - Client Vehicles

    Vehicle trunk and glovebox access. Handles distance checks,
    animations, and interaction registration via hydra_target
    with keypress fallback.
]]

Hydra = Hydra or {}
Hydra.Inventory = Hydra.Inventory or {}

local cfg = HydraConfig.Inventory

-- Cache frequently used natives
local GetEntityCoords = GetEntityCoords
local PlayerPedId = PlayerPedId
local DoesEntityExist = DoesEntityExist
local GetVehicleNumberPlateText = GetVehicleNumberPlateText
local GetClosestVehicle = GetClosestVehicle
local IsControlJustPressed = IsControlJustPressed
local GetEntityBoneIndexByName = GetEntityBoneIndexByName
local GetWorldPositionOfEntityBone = GetWorldPositionOfEntityBone
local SetVehicleDoorOpen = SetVehicleDoorOpen
local SetVehicleDoorShut = SetVehicleDoorShut
local GetVehicleDoorAngleRatio = GetVehicleDoorAngleRatio
local TaskPlayAnim = TaskPlayAnim
local RequestAnimDict = RequestAnimDict
local HasAnimDictLoaded = HasAnimDictLoaded
local Wait = Citizen.Wait

-- State
local trunkOpen = false
local activeVehicle = nil
local activePlate = nil

-- Optional module detection
local hasTarget = false

CreateThread(function()
    Wait(1500)
    hasTarget = pcall(function() return exports['hydra_target'] end)
end)

-- =============================================
-- UTILITY
-- =============================================

--- Get the trimmed plate string from a vehicle
--- @param vehicle number entity
--- @return string plate
local function getPlate(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return '' end
    return string.gsub(GetVehicleNumberPlateText(vehicle), '%s+', '')
end

--- Get trunk bone position for a vehicle
--- @param vehicle number entity
--- @return vector3
local function getTrunkPosition(vehicle)
    local boneIndex = GetEntityBoneIndexByName(vehicle, 'boot')
    if boneIndex == -1 then
        boneIndex = GetEntityBoneIndexByName(vehicle, 'trunk')
    end
    if boneIndex == -1 then
        -- Fallback: use rear of vehicle
        local coords = GetEntityCoords(vehicle)
        local offset = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -2.5, 0.0)
        return offset
    end
    return GetWorldPositionOfEntityBone(vehicle, boneIndex)
end

--- Load an animation dictionary
--- @param dict string
--- @return boolean loaded
local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 3000 do
        Wait(10)
        t = t + 10
    end
    return HasAnimDictLoaded(dict)
end

--- Check if vehicle is locked
--- @param vehicle number entity
--- @return boolean
local function isVehicleLocked(vehicle)
    if not cfg.vehicle.lockWithVehicle then return false end
    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    return lockStatus == 2 or lockStatus == 3 or lockStatus == 7 or lockStatus == 8
end

-- =============================================
-- TRUNK ACCESS
-- =============================================

--- Open trunk inventory for a vehicle
--- @param vehicle number entity
function Hydra.Inventory.OpenTrunk(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    if trunkOpen then return end

    local ped = PlayerPedId()
    local playerPos = GetEntityCoords(ped)
    local trunkPos = getTrunkPosition(vehicle)
    local dist = #(playerPos - trunkPos)

    if dist > cfg.vehicle.accessDistance then
        TriggerEvent('hydra:notify:show', {
            type = 'error',
            message = 'You are too far from the trunk.',
            duration = 3000,
        })
        return
    end

    if isVehicleLocked(vehicle) then
        TriggerEvent('hydra:notify:show', {
            type = 'error',
            message = 'Vehicle is locked.',
            duration = 3000,
        })
        return
    end

    local plate = getPlate(vehicle)

    -- Play open trunk animation
    if loadAnimDict('anim@heists@fleeca_bank@scope_out@return_case') then
        TaskPlayAnim(ped, 'anim@heists@fleeca_bank@scope_out@return_case', 'try_place_down',
            2.0, -2.0, 1500, 0, 0, false, false, false)
    end

    -- Open boot door (door index 5 = boot/trunk)
    SetVehicleDoorOpen(vehicle, 5, false, false)

    trunkOpen = true
    activeVehicle = vehicle
    activePlate = plate

    TriggerServerEvent('hydra:inventory:vehicle:open', {
        plate = plate,
        type = 'trunk',
        netId = NetworkGetNetworkIdFromEntity(vehicle),
    })

    -- Monitor distance - close trunk if player moves away
    CreateThread(function()
        while trunkOpen and activeVehicle == vehicle do
            Wait(500)

            local pedPos = GetEntityCoords(PlayerPedId())
            local vehTrunkPos = getTrunkPosition(vehicle)

            if not DoesEntityExist(vehicle) or #(pedPos - vehTrunkPos) > cfg.vehicle.accessDistance + 2.0 then
                Hydra.Inventory.CloseTrunk()
                break
            end
        end
    end)
end

--- Close the active trunk
function Hydra.Inventory.CloseTrunk()
    if not trunkOpen then return end

    if activeVehicle and DoesEntityExist(activeVehicle) then
        SetVehicleDoorShut(activeVehicle, 5, false)
    end

    trunkOpen = false

    if activePlate then
        TriggerServerEvent('hydra:inventory:vehicle:close', {
            plate = activePlate,
            type = 'trunk',
        })
    end

    activeVehicle = nil
    activePlate = nil
end

-- =============================================
-- GLOVEBOX ACCESS
-- =============================================

--- Open glovebox inventory for a vehicle
--- @param vehicle number entity
function Hydra.Inventory.OpenGlovebox(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    local ped = PlayerPedId()
    local playerPos = GetEntityCoords(ped)
    local vehPos = GetEntityCoords(vehicle)
    local dist = #(playerPos - vehPos)

    if dist > cfg.vehicle.accessDistance then
        TriggerEvent('hydra:notify:show', {
            type = 'error',
            message = 'You are too far from the vehicle.',
            duration = 3000,
        })
        return
    end

    -- Glovebox can be accessed even when locked (you must be inside)
    local plate = getPlate(vehicle)

    TriggerServerEvent('hydra:inventory:vehicle:open', {
        plate = plate,
        type = 'glovebox',
        netId = NetworkGetNetworkIdFromEntity(vehicle),
    })
end

-- =============================================
-- CLOSE EVENTS (from UI or server)
-- =============================================

RegisterNetEvent('hydra:inventory:client:vehicle:close')
AddEventHandler('hydra:inventory:client:vehicle:close', function()
    Hydra.Inventory.CloseTrunk()
end)

-- =============================================
-- TARGET INTERACTION REGISTRATION
-- =============================================

CreateThread(function()
    Wait(2500) -- staggered start

    if not hasTarget then return end

    pcall(function()
        exports['hydra_target']:AddGlobalVehicle({
            {
                label = 'Open Trunk',
                icon = 'box-open',
                distance = cfg.vehicle.accessDistance,
                canInteract = function(entity)
                    if not entity or not DoesEntityExist(entity) then return false end
                    if trunkOpen then return false end

                    -- Only show when near the rear
                    local playerPos = GetEntityCoords(PlayerPedId())
                    local trunkPos = getTrunkPosition(entity)
                    return #(playerPos - trunkPos) <= cfg.vehicle.accessDistance
                end,
                onSelect = function(entity)
                    Hydra.Inventory.OpenTrunk(entity)
                end,
            },
            {
                label = 'Open Glovebox',
                icon = 'briefcase',
                distance = cfg.vehicle.accessDistance,
                canInteract = function(entity)
                    if not entity or not DoesEntityExist(entity) then return false end
                    -- Glovebox: player should be inside or near driver/passenger door
                    local ped = PlayerPedId()
                    local currentVeh = GetVehiclePedIsIn(ped, false)
                    return currentVeh == entity
                end,
                onSelect = function(entity)
                    Hydra.Inventory.OpenGlovebox(entity)
                end,
            },
        })
    end)
end)

-- =============================================
-- FALLBACK KEYPRESS INTERACTION
-- =============================================

CreateThread(function()
    Wait(3000) -- staggered start

    while true do
        if not hasTarget then
            local ped = PlayerPedId()
            local playerPos = GetEntityCoords(ped)
            local currentVeh = GetVehiclePedIsIn(ped, false)

            if currentVeh ~= 0 then
                -- Inside vehicle: glovebox prompt
                Wait(0)

                SetTextFont(4)
                SetTextScale(0.0, 0.32)
                SetTextColour(255, 255, 255, 220)
                SetTextDropshadow(1, 0, 0, 0, 200)
                SetTextOutline()
                SetTextCentre(true)
                SetTextEntry('STRING')
                AddTextComponentString('[E] Open Glovebox')
                DrawText(0.5, 0.9)

                if IsControlJustPressed(0, 38) then -- E key
                    Hydra.Inventory.OpenGlovebox(currentVeh)
                end
            else
                -- On foot: check for nearby vehicle trunk
                local closestVeh = GetClosestVehicle(playerPos.x, playerPos.y, playerPos.z,
                    cfg.vehicle.accessDistance + 1.0, 0, 70)

                if closestVeh ~= 0 and DoesEntityExist(closestVeh) then
                    local trunkPos = getTrunkPosition(closestVeh)
                    local trunkDist = #(playerPos - trunkPos)

                    if trunkDist <= cfg.vehicle.accessDistance and not trunkOpen then
                        Wait(0)

                        SetTextFont(4)
                        SetTextScale(0.0, 0.32)
                        SetTextColour(255, 255, 255, 220)
                        SetTextDropshadow(1, 0, 0, 0, 200)
                        SetTextOutline()
                        SetTextCentre(true)
                        SetTextEntry('STRING')
                        AddTextComponentString('[E] Open Trunk')
                        DrawText(0.5, 0.9)

                        if IsControlJustPressed(0, 38) then -- E key
                            Hydra.Inventory.OpenTrunk(closestVeh)
                        end
                    else
                        Wait(500)
                    end
                else
                    Wait(500)
                end
            end
        else
            Wait(2000)
        end
    end
end)

-- =============================================
-- EXPORTS
-- =============================================

exports('OpenTrunk', function(vehicle) Hydra.Inventory.OpenTrunk(vehicle) end)
exports('OpenGlovebox', function(vehicle) Hydra.Inventory.OpenGlovebox(vehicle) end)
exports('CloseTrunk', function() Hydra.Inventory.CloseTrunk() end)
exports('IsTrunkOpen', function() return trunkOpen end)
