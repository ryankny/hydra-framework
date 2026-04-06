--[[
    Hydra HUD - Vehicle HUD Data Collector

    Collects vehicle data and determines vehicle type for
    appropriate HUD display (car, plane, boat, bike).
    Only active when player is in a vehicle.
]]

Hydra = Hydra or {}
Hydra.HUD = Hydra.HUD or {}

local lastVehicleData = {}
local wasInVehicle = false
local seatbeltOn = false

-- Vehicle class IDs
local VEHICLE_TYPES = {
    -- Cars / land vehicles
    [0] = 'car', [1] = 'car', [2] = 'car', [3] = 'car', [4] = 'car',
    [5] = 'car', [6] = 'car', [7] = 'car', [9] = 'car', [10] = 'car',
    [11] = 'car', [12] = 'car', [17] = 'car', [18] = 'car', [19] = 'car',
    [20] = 'car', [22] = 'car',
    -- Motorcycles / bikes
    [8] = 'bike',
    [13] = 'bike',  -- Cycles
    -- Boats
    [14] = 'boat',
    -- Helicopters
    [15] = 'helicopter',
    -- Planes
    [16] = 'plane',
    -- Emergency
    -- (already covered by class 18/19)
    -- Trains
    [21] = 'train',
}

--- Get the type of vehicle
--- @param vehicle number vehicle entity
--- @return string 'car'|'bike'|'boat'|'plane'|'helicopter'|'train'
local function getVehicleType(vehicle)
    local class = GetVehicleClass(vehicle)
    return VEHICLE_TYPES[class] or 'car'
end

--- Get speed in configured unit
--- @param vehicle number
--- @return number speed
--- @return string unit
local function getSpeed(vehicle)
    local speed = GetEntitySpeed(vehicle)
    local unit = HydraHUDConfig.vehicle.speed_unit or 'mph'

    if unit == 'kmh' then
        return math.floor(speed * 3.6), 'KM/H'
    else
        return math.floor(speed * 2.236936), 'MPH'
    end
end

--- Get RPM as percentage (0-100)
--- @param vehicle number
--- @return number
local function getRPM(vehicle)
    return math.floor(GetVehicleCurrentRpm(vehicle) * 100)
end

--- Collect vehicle data
--- @param vehicle number
--- @param vehicleType string
--- @return table
local function collectVehicleData(vehicle, vehicleType)
    local speed, speedUnit = getSpeed(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)  -- -4000 to 1000
    local bodyHealth = GetVehicleBodyHealth(vehicle)       -- 0 to 1000
    local fuelLevel = GetVehicleFuelLevel(vehicle)         -- 0 to 100 (if fuel script present)

    local data = {
        type = vehicleType,
        speed = speed,
        speedUnit = speedUnit,
        rpm = getRPM(vehicle),
        gear = GetVehicleCurrentGear(vehicle),
        engineHealth = math.max(math.floor(engineHealth / 10), 0),  -- 0-100
        bodyHealth = math.max(math.floor(bodyHealth / 10), 0),      -- 0-100
        fuel = math.floor(fuelLevel),
        seatbelt = seatbeltOn,
        locked = GetVehicleDoorLockStatus(vehicle) == 2,
        lightsOn = GetVehicleLightsState(vehicle) ~= 0,
        engineOn = GetIsVehicleEngineRunning(vehicle),
    }

    -- Aircraft-specific data
    if vehicleType == 'plane' or vehicleType == 'helicopter' then
        local pos = GetEntityCoords(vehicle)
        data.altitude = math.floor(pos.z)
        data.heading = math.floor(GetEntityHeading(vehicle))

        -- Landing gear (planes only)
        if vehicleType == 'plane' then
            data.landingGear = IsVehicleTyreBurst(vehicle, 0, false) == false
            data.gear = nil -- No gear display for planes
        end

        -- Vertical speed
        local vel = GetEntityVelocity(vehicle)
        data.verticalSpeed = math.floor(vel.z * 3.6)  -- m/s to km/h
    end

    -- Boat-specific data
    if vehicleType == 'boat' then
        data.gear = nil
        data.seatbelt = nil
        data.rpm = nil

        -- Anchor state (simplified)
        data.anchor = GetBoatAnchor(vehicle)
    end

    -- Bike - no seatbelt
    if vehicleType == 'bike' then
        data.seatbelt = nil
    end

    return data
end

--- Check if vehicle data changed
local function hasChanged(newData, oldData)
    if not oldData or not oldData.type then return true end
    for k, v in pairs(newData) do
        if oldData[k] ~= v then return true end
    end
    return false
end

--- Toggle seatbelt
local function toggleSeatbelt()
    if GetVehiclePedIsIn(PlayerPedId(), false) == 0 then return end
    seatbeltOn = not seatbeltOn

    -- Use hydra_audio if available, fallback to native
    local audioOk = pcall(function()
        exports['hydra_audio']:PlayFrontend('NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 'ui')
    end)
    if not audioOk then
        PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    end

    TriggerEvent('hydra:notify:show', {
        type = 'info', title = 'Seatbelt',
        message = seatbeltOn and 'Seatbelt fastened.' or 'Seatbelt unfastened.',
        duration = 2000,
    })
end

-- Register via hydra_keybinds if available
CreateThread(function()
    Wait(500)
    local ok = pcall(function()
        exports['hydra_keybinds']:Register('seatbelt', {
            key = 'B',
            description = 'Toggle Seatbelt',
            category = 'vehicle',
            module = 'hydra_hud',
            onPress = toggleSeatbelt,
        })
    end)
    if not ok then
        RegisterCommand('seatbelt', function() toggleSeatbelt() end, false)
        RegisterKeyMapping('seatbelt', 'Toggle Seatbelt', 'keyboard', 'B')
    end
end)

--- Expose seatbelt state for other modules (e.g. hydra_world ejection)
--- @return boolean
function Hydra.HUD.GetSeatbelt()
    return seatbeltOn
end

exports('GetSeatbelt', function() return seatbeltOn end)

--- Vehicle HUD update loop
CreateThread(function()
    while not Hydra.IsReady() do Wait(200) end

    local vehConfig = HydraHUDConfig.vehicle or {}
    if not vehConfig.enabled then return end

    local updateRate = HydraHUDConfig.update_rate or 100

    while true do
        local ped = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(ped, false)

        if inVehicle then
            local vehicle = GetVehiclePedIsIn(ped, false)
            local vehicleType = getVehicleType(vehicle)

            if not wasInVehicle then
                -- Just entered vehicle
                wasInVehicle = true
                seatbeltOn = false
                Hydra.HUD.Send('vehicleEnter', { type = vehicleType })
            end

            local data = collectVehicleData(vehicle, vehicleType)

            if hasChanged(data, lastVehicleData) then
                Hydra.HUD.Send('vehicleUpdate', data)
                lastVehicleData = data
            end

            Wait(updateRate)
        else
            if wasInVehicle then
                -- Just exited vehicle
                wasInVehicle = false
                seatbeltOn = false
                lastVehicleData = {}
                Hydra.HUD.Send('vehicleExit', {})
            end
            Wait(500) -- Slower polling when not in vehicle
        end
    end
end)
