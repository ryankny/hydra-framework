--[[
    Hydra Physics - Vehicle Handling

    Applies realistic handling overrides per vehicle class/model.
    Includes weight transfer simulation and surface traction.
    Uses SetVehicleHandlingFloat to modify live handling data.
]]

Hydra = Hydra or {}
Hydra.Physics = Hydra.Physics or {}

local cfg = HydraPhysicsConfig.handling
local wtCfg = HydraPhysicsConfig.weight_transfer
local surfCfg = HydraPhysicsConfig.surface_traction

if not cfg or not cfg.enabled then return end

-- Track which vehicles we've already modified
local modifiedVehicles = {}  -- [entity] = vehicleClass
local playerVehicle = 0

-- Cache handling field names mapped to config keys
local HANDLING_MAP = {
    traction_curve_max      = 'CHandlingData', 'fTractionCurveMax',
    traction_curve_min      = 'CHandlingData', 'fTractionCurveMin',
    traction_spring_delta_max = 'CHandlingData', 'fTractionSpringDeltaMax',
    traction_bias_front     = 'CHandlingData', 'fTractionBiasFront',
    low_speed_traction_loss = 'CHandlingData', 'fLowSpeedTractionLossMult',
    suspension_force        = 'CHandlingData', 'fSuspensionForce',
    suspension_comp_damp    = 'CHandlingData', 'fSuspensionCompDamp',
    suspension_rebound_damp = 'CHandlingData', 'fSuspensionRebDamp',
    suspension_raise        = 'CHandlingData', 'fSuspensionRaise',
    suspension_bias_front   = 'CHandlingData', 'fSuspensionBiasFront',
    brake_force             = 'CHandlingData', 'fBrakeForce',
    brake_bias_front        = 'CHandlingData', 'fBrakeBiasFront',
    handbrake_force         = 'CHandlingData', 'fHandBrakeForce',
    steering_lock           = 'CHandlingData', 'fSteeringLock',
    drive_inertia           = 'CHandlingData', 'fDriveInertia',
    anti_rollbar_force      = 'CHandlingData', 'fAntiRollBarForce',
    anti_rollbar_bias_front = 'CHandlingData', 'fAntiRollBarBiasFront',
    downforce_modifier      = 'CHandlingData', 'fDownforceModifier',
}

-- Handling field pairs: { configKey, className, fieldName }
local HANDLING_FIELDS = {
    { key = 'traction_curve_max',      class = 'CHandlingData', field = 'fTractionCurveMax' },
    { key = 'traction_curve_min',      class = 'CHandlingData', field = 'fTractionCurveMin' },
    { key = 'traction_spring_delta_max', class = 'CHandlingData', field = 'fTractionSpringDeltaMax' },
    { key = 'traction_bias_front',     class = 'CHandlingData', field = 'fTractionBiasFront' },
    { key = 'low_speed_traction_loss', class = 'CHandlingData', field = 'fLowSpeedTractionLossMult' },
    { key = 'suspension_force',        class = 'CHandlingData', field = 'fSuspensionForce' },
    { key = 'suspension_comp_damp',    class = 'CHandlingData', field = 'fSuspensionCompDamp' },
    { key = 'suspension_rebound_damp', class = 'CHandlingData', field = 'fSuspensionRebDamp' },
    { key = 'suspension_raise',        class = 'CHandlingData', field = 'fSuspensionRaise' },
    { key = 'suspension_bias_front',   class = 'CHandlingData', field = 'fSuspensionBiasFront' },
    { key = 'brake_force',             class = 'CHandlingData', field = 'fBrakeForce' },
    { key = 'brake_bias_front',        class = 'CHandlingData', field = 'fBrakeBiasFront' },
    { key = 'handbrake_force',         class = 'CHandlingData', field = 'fHandBrakeForce' },
    { key = 'steering_lock',           class = 'CHandlingData', field = 'fSteeringLock' },
    { key = 'drive_inertia',           class = 'CHandlingData', field = 'fDriveInertia' },
    { key = 'anti_rollbar_force',      class = 'CHandlingData', field = 'fAntiRollBarForce' },
    { key = 'anti_rollbar_bias_front', class = 'CHandlingData', field = 'fAntiRollBarBiasFront' },
    { key = 'downforce_modifier',      class = 'CHandlingData', field = 'fDownforceModifier' },
}

-- =============================================
-- PROFILE RESOLUTION
-- =============================================

--- Resolve the handling profile for a vehicle
--- Merges: global -> class -> model (highest priority wins)
--- @param vehicle number entity
--- @return table profile
local function resolveProfile(vehicle)
    local profile = {}
    local vehClass = GetVehicleClass(vehicle)
    local model = GetEntityModel(vehicle)

    -- Start with global
    for k, v in pairs(cfg.global) do
        if v ~= nil then profile[k] = v end
    end

    -- Layer class overrides
    local classProfile = cfg.classes[vehClass]
    if classProfile then
        for k, v in pairs(classProfile) do
            if v ~= nil then profile[k] = v end
        end
    end

    -- Layer model overrides (check by model name)
    for modelName, overrides in pairs(cfg.models) do
        local hash = type(modelName) == 'number' and modelName or GetHashKey(modelName)
        if model == hash then
            for k, v in pairs(overrides) do
                if v ~= nil then profile[k] = v end
            end
            break
        end
    end

    return profile
end

-- =============================================
-- HANDLING APPLICATION
-- =============================================

--- Apply handling profile to a vehicle
--- @param vehicle number entity
--- @param profile table resolved profile
local function applyHandling(vehicle, profile)
    if not DoesEntityExist(vehicle) then return end

    for _, def in ipairs(HANDLING_FIELDS) do
        local value = profile[def.key]
        if value ~= nil then
            SetVehicleHandlingFloat(vehicle, def.class, def.field, value + 0.0)
        end
    end
end

-- =============================================
-- VEHICLE SCAN LOOP
-- =============================================

CreateThread(function()
    while true do
        Wait(cfg.scan_rate or 500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 then
            -- Check if we're the driver (or driver_only is off)
            local isDriver = GetPedInVehicleSeat(veh, -1) == ped
            if not cfg.driver_only or isDriver then
                if veh ~= playerVehicle then
                    playerVehicle = veh
                    local profile = resolveProfile(veh)
                    applyHandling(veh, profile)
                    modifiedVehicles[veh] = GetVehicleClass(veh)
                end
            end
        else
            playerVehicle = 0
        end

        -- Cleanup stale entries
        for entity in pairs(modifiedVehicles) do
            if not DoesEntityExist(entity) then
                modifiedVehicles[entity] = nil
            end
        end
    end
end)

-- =============================================
-- WEIGHT TRANSFER SIMULATION
-- =============================================

if wtCfg and wtCfg.enabled then
    local prevVelocity = vector3(0, 0, 0)
    local transferFront = 0.0
    local transferRear = 0.0

    CreateThread(function()
        while true do
            Wait(wtCfg.tick_rate or 50)
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                local vel = GetEntityVelocity(veh)
                local speed = #vel
                if speed < 2.0 then
                    -- Reset transfer at low speed
                    transferFront = transferFront * (1.0 - wtCfg.recovery_rate)
                    transferRear = transferRear * (1.0 - wtCfg.recovery_rate)
                    prevVelocity = vel
                    goto continue
                end

                local forwardVec = GetEntityForwardVector(veh)
                local rightVec = vector3(-forwardVec.y, forwardVec.x, 0.0)

                -- Longitudinal acceleration (dot product with forward)
                local accelVec = vel - prevVelocity
                local longAccel = accelVec.x * forwardVec.x + accelVec.y * forwardVec.y
                local latAccel = accelVec.x * rightVec.x + accelVec.y * rightVec.y

                -- Braking: positive longAccel when decelerating (moving forward, accel backward)
                local brakeShift = 0.0
                local accelShift = 0.0

                if longAccel < -0.5 then
                    -- Braking: weight moves to front
                    brakeShift = math.abs(longAccel) * wtCfg.brake_transfer * wtCfg.intensity
                elseif longAccel > 0.5 then
                    -- Accelerating: weight moves to rear
                    accelShift = longAccel * wtCfg.accel_transfer * wtCfg.intensity
                end

                -- Lateral load transfer
                local lateralShift = math.abs(latAccel) * wtCfg.lateral_transfer * wtCfg.intensity

                -- Apply transfer to traction bias
                local baseBias = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionBiasFront')
                local biasShift = (brakeShift - accelShift) * 0.05
                local newBias = math.max(0.01, math.min(0.99, baseBias + biasShift))

                SetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionBiasFront', newBias + 0.0)

                -- Lateral transfer affects anti-rollbar
                local baseARB = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fAntiRollBarForce')
                local arbMod = 1.0 - (lateralShift * 0.3)
                SetVehicleHandlingFloat(veh, 'CHandlingData', 'fAntiRollBarForce', (baseARB * math.max(0.3, arbMod)) + 0.0)

                prevVelocity = vel
            else
                prevVelocity = vector3(0, 0, 0)
            end

            ::continue::
        end
    end)
end

-- =============================================
-- SURFACE TRACTION
-- =============================================

if surfCfg and surfCfg.enabled then
    local currentSurfaceMult = 1.0
    local currentWeatherMult = 1.0
    local baseTraction = nil

    -- Material hash to name mapping (common GTA surface types)
    local SURFACE_MAP = {
        [1]  = 'asphalt',     -- Default road
        [2]  = 'asphalt',     -- Road painted
        [3]  = 'concrete',
        [4]  = 'concrete',
        [6]  = 'gravel',
        [7]  = 'gravel',
        [8]  = 'sand',
        [9]  = 'sand',
        [11] = 'dirt',
        [12] = 'mud',
        [17] = 'grass',
        [18] = 'grass',
        [19] = 'forest',
        [20] = 'offroad',
        [23] = 'ice',
        [24] = 'snow',
        [30] = 'cobblestone',
        [31] = 'cobblestone',
    }

    CreateThread(function()
        while true do
            Wait(surfCfg.tick_rate or 200)
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                -- Get surface material
                local pos = GetEntityCoords(veh)
                local retval, groundZ, surfaceNormal = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 2.0, false)

                if retval then
                    -- Use raytrace to detect surface material
                    local rayHandle = StartShapeTestRay(pos.x, pos.y, pos.z + 0.5, pos.x, pos.y, pos.z - 1.0, 1, veh, 0)
                    local _, hit, hitCoords, _, materialHash = GetShapeTestResult(rayHandle)

                    if hit then
                        local surfaceName = SURFACE_MAP[materialHash] or 'asphalt'
                        local mult = surfCfg.materials[surfaceName] or 1.0

                        -- Weather modifier
                        local weatherMult = 1.0
                        if surfCfg.weather_modifiers then
                            local weather = GetPrevWeatherTypeHashName()
                            for weatherType, mod in pairs(surfCfg.weather_modifiers) do
                                if GetHashKey(weatherType) == weather then
                                    weatherMult = mod
                                    break
                                end
                            end
                        end

                        -- Apply combined surface grip
                        local combined = mult * weatherMult
                        if math.abs(combined - (currentSurfaceMult * currentWeatherMult)) > 0.02 then
                            currentSurfaceMult = mult
                            currentWeatherMult = weatherMult

                            -- Scale base traction by surface grip
                            local curTraction = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax')
                            if not baseTraction then baseTraction = curTraction end

                            local newTraction = baseTraction * combined
                            SetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax', newTraction + 0.0)

                            local curMin = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMin')
                            SetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMin', (curMin * combined) + 0.0)
                        end
                    end
                end
            else
                baseTraction = nil
                currentSurfaceMult = 1.0
                currentWeatherMult = 1.0
            end
        end
    end)
end

-- =============================================
-- API
-- =============================================

--- Force re-apply handling to current vehicle
function Hydra.Physics.RefreshHandling()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        local profile = resolveProfile(veh)
        applyHandling(veh, profile)
    end
end

--- Get the resolved handling profile for a vehicle
--- @param vehicle number entity
--- @return table
function Hydra.Physics.GetHandlingProfile(vehicle)
    return resolveProfile(vehicle)
end

--- Override a single handling value on a vehicle
--- @param vehicle number entity
--- @param key string config key name
--- @param value number
function Hydra.Physics.SetHandlingValue(vehicle, key, value)
    for _, def in ipairs(HANDLING_FIELDS) do
        if def.key == key then
            SetVehicleHandlingFloat(vehicle, def.class, def.field, value + 0.0)
            return true
        end
    end
    return false
end
