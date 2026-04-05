--[[
    Hydra Physics - Advanced Vehicle Dynamics

    Vehicle rollover simulation, aquaplaning/hydroplaning,
    and mud/dirt bogging with progressive sinking.
]]

Hydra = Hydra or {}
Hydra.Physics = Hydra.Physics or {}

local rollCfg = HydraPhysicsConfig.rollover
local aquaCfg = HydraPhysicsConfig.aquaplaning
local bogCfg  = HydraPhysicsConfig.bogging

-- Shared surface map (same as handling.lua)
local SURFACE_MAP = {
    [1]  = 'asphalt', [2] = 'asphalt',
    [3]  = 'concrete', [4] = 'concrete',
    [6]  = 'gravel', [7] = 'gravel',
    [8]  = 'sand', [9] = 'sand',
    [11] = 'dirt', [12] = 'mud',
    [17] = 'grass', [18] = 'grass',
    [19] = 'forest', [20] = 'offroad',
    [23] = 'ice', [24] = 'snow',
    [30] = 'cobblestone', [31] = 'cobblestone',
}

--- Detect current surface under vehicle via raytrace
--- @param veh number vehicle entity
--- @return string surfaceName
local function detectSurface(veh)
    local pos = GetEntityCoords(veh)
    local rayHandle = StartShapeTestRay(pos.x, pos.y, pos.z + 0.5, pos.x, pos.y, pos.z - 1.0, 1, veh, 0)
    local _, hit, _, _, materialHash = GetShapeTestResult(rayHandle)
    if hit then
        return SURFACE_MAP[materialHash] or 'asphalt'
    end
    return 'asphalt'
end

--- Get current weather hash
--- @return number weatherHash
local function getWeatherHash()
    return GetPrevWeatherTypeHashName()
end

--- Check if weather matches a list of type names
--- @param types table array of weather type strings
--- @return boolean
local function isWeatherActive(types)
    local current = getWeatherHash()
    for _, name in ipairs(types) do
        if GetHashKey(name) == current then return true end
    end
    return false
end

-- =============================================
-- VEHICLE ROLLOVER SIMULATION
-- =============================================

if rollCfg and rollCfg.enabled then
    local baseARBValues = {} -- [vehicle] = original ARB force
    local rollState = 0.0    -- Current roll vulnerability (0 = stable, 1 = max)

    CreateThread(function()
        while true do
            Wait(rollCfg.tick_rate or 50)
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then
                rollState = 0.0
                goto continue
            end

            local speed = GetEntitySpeed(veh) * 3.6 -- km/h

            if speed < rollCfg.min_speed then
                -- Below threshold, restore ARB and relax
                if baseARBValues[veh] and rollState > 0.01 then
                    rollState = rollState * (1.0 - (rollCfg.recovery_rate or 0.06))
                    local restored = baseARBValues[veh] * (1.0 - rollState * (1.0 - rollCfg.min_arb_factor))
                    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fAntiRollBarForce', restored + 0.0)
                end
                goto continue
            end

            -- Store baseline ARB on first encounter
            if not baseARBValues[veh] then
                baseARBValues[veh] = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fAntiRollBarForce')
            end

            -- Calculate lateral G-force
            local vel = GetEntityVelocity(veh)
            local forwardVec = GetEntityForwardVector(veh)
            local rightVec = vector3(-forwardVec.y, forwardVec.x, 0.0)
            local lateralG = math.abs(vel.x * rightVec.x + vel.y * rightVec.y) / 9.81

            -- Vehicle roll angle
            local roll = GetEntityRoll(veh)
            local rollAngle = math.abs(roll)

            -- Class susceptibility
            local vehClass = GetVehicleClass(veh)
            local classMult = rollCfg.class_multipliers[vehClass] or 1.0

            -- Terrain amplification (check if vehicle is airborne or on uneven surface)
            local terrainMult = 1.0
            local heightAboveGround = GetEntityHeightAboveGround(veh)
            if heightAboveGround > 0.5 and heightAboveGround < 3.0 then
                -- Slightly airborne = hit a bump, amplify roll
                terrainMult = rollCfg.terrain_amplify or 1.3
            end

            -- Calculate target roll vulnerability
            local lateralFactor = 0.0
            if lateralG > rollCfg.lateral_g_threshold then
                lateralFactor = (lateralG - rollCfg.lateral_g_threshold) / (2.0 - rollCfg.lateral_g_threshold)
                lateralFactor = math.min(1.0, lateralFactor)
            end

            -- Speed factor: higher speed = more roll risk
            local speedFactor = math.min(1.0, speed / 150.0)

            -- Roll angle feedback: already tilted = amplify further
            local angleFactor = math.min(1.0, rollAngle / 35.0)

            -- Combined vulnerability
            local targetRoll = lateralFactor * speedFactor * classMult * terrainMult * rollCfg.intensity
            targetRoll = targetRoll + angleFactor * 0.3 -- Feedback loop

            -- Smooth transition
            local blendRate = targetRoll > rollState and 0.15 or (rollCfg.recovery_rate or 0.06)
            rollState = rollState + (targetRoll - rollState) * blendRate
            rollState = math.max(0.0, math.min(1.0, rollState))

            -- Apply: reduce anti-roll bar based on roll vulnerability
            local baseARB = baseARBValues[veh]
            local newARB = baseARB * (1.0 - rollState * (1.0 - rollCfg.min_arb_factor))
            SetVehicleHandlingFloat(veh, 'CHandlingData', 'fAntiRollBarForce', math.max(0.0, newARB) + 0.0)

            -- If roll angle is extreme, apply a small corrective or amplifying force
            if rollAngle > 40.0 and rollState > 0.5 then
                -- Past the tipping point - let gravity do its work
                local rollDir = roll > 0 and 1.0 or -1.0
                ApplyForceToEntity(veh, 1,
                    0.0, 0.0, -rollDir * rollState * 2.0,
                    rollDir * 1.5, 0.0, 0.5,
                    0, false, true, true, false, true)
            end

            ::continue::
        end
    end)

    -- Cleanup
    CreateThread(function()
        while true do
            Wait(5000)
            for veh in pairs(baseARBValues) do
                if not DoesEntityExist(veh) then baseARBValues[veh] = nil end
            end
        end
    end)
end

-- =============================================
-- AQUAPLANING / HYDROPLANING
-- =============================================

if aquaCfg and aquaCfg.enabled then
    local aquaplaneLevel = 0.0  -- 0 = no aquaplaning, 1.0 = full aquaplane
    local driftPullDir = 0.0
    local lastPullChange = 0
    local baseTractionAqua = nil
    local baseBrakeAqua = nil
    local baseSteerAqua = nil
    local warningShown = false

    CreateThread(function()
        while true do
            Wait(aquaCfg.tick_rate or 100)
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then
                aquaplaneLevel = 0.0
                baseTractionAqua = nil
                baseBrakeAqua = nil
                baseSteerAqua = nil
                warningShown = false
                goto continue
            end

            -- Check if raining
            if not isWeatherActive(aquaCfg.weather_types) then
                -- Not raining - restore if needed
                if aquaplaneLevel > 0.01 and baseTractionAqua then
                    aquaplaneLevel = aquaplaneLevel * 0.85 -- Fade out
                    if aquaplaneLevel < 0.01 then
                        SetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax', baseTractionAqua + 0.0)
                        SetVehicleHandlingFloat(veh, 'CHandlingData', 'fBrakeForce', baseBrakeAqua + 0.0)
                        SetVehicleHandlingFloat(veh, 'CHandlingData', 'fSteeringLock', baseSteerAqua + 0.0)
                        baseTractionAqua = nil
                        baseBrakeAqua = nil
                        baseSteerAqua = nil
                        warningShown = false
                    end
                end
                goto continue
            end

            -- Store baselines
            if not baseTractionAqua then
                baseTractionAqua = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax')
                baseBrakeAqua = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fBrakeForce')
                baseSteerAqua = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fSteeringLock')
            end

            local speed = GetEntitySpeed(veh) * 3.6
            local surface = detectSurface(veh)

            -- Aquaplaning only on paved surfaces
            if surface ~= 'asphalt' and surface ~= 'concrete' and surface ~= 'cobblestone' then
                aquaplaneLevel = math.max(0, aquaplaneLevel - 0.05)
                goto applyAqua
            end

            -- Calculate aquaplaning level based on speed
            if speed < aquaCfg.onset_speed then
                aquaplaneLevel = math.max(0, aquaplaneLevel - 0.03)
            else
                local speedFactor = math.min(1.0, (speed - aquaCfg.onset_speed) / (aquaCfg.full_speed - aquaCfg.onset_speed))

                -- Class resistance
                local vehClass = GetVehicleClass(veh)
                local resistance = aquaCfg.class_resistance[vehClass] or 1.0
                speedFactor = speedFactor / math.max(0.1, resistance)

                local targetLevel = math.min(1.0, speedFactor)
                aquaplaneLevel = aquaplaneLevel + (targetLevel - aquaplaneLevel) * 0.1
            end

            ::applyAqua::

            if aquaplaneLevel > 0.01 then
                -- Reduce traction
                local tractionLoss = aquaplaneLevel * aquaCfg.max_traction_loss
                local newTraction = baseTractionAqua * (1.0 - tractionLoss)
                SetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax', newTraction + 0.0)

                -- Reduce braking
                local brakeLoss = aquaplaneLevel * aquaCfg.brake_reduction
                local newBrake = baseBrakeAqua * (1.0 - brakeLoss)
                SetVehicleHandlingFloat(veh, 'CHandlingData', 'fBrakeForce', newBrake + 0.0)

                -- Reduce steering responsiveness
                local steerLoss = aquaplaneLevel * aquaCfg.steering_loss
                local newSteer = baseSteerAqua * (1.0 - steerLoss)
                SetVehicleHandlingFloat(veh, 'CHandlingData', 'fSteeringLock', newSteer + 0.0)

                -- Random drift pull
                if aquaCfg.drift_pull and aquaCfg.drift_pull.enabled and aquaplaneLevel > 0.3 then
                    local now = GetGameTimer()
                    if now - lastPullChange > aquaCfg.drift_pull.change_rate then
                        driftPullDir = (math.random() - 0.5) * 2.0
                        lastPullChange = now
                    end

                    local pullForce = driftPullDir * aquaplaneLevel * aquaCfg.drift_pull.intensity * (speed / 100.0)
                    local rightVec = vector3(-GetEntityForwardVector(veh).y, GetEntityForwardVector(veh).x, 0.0)
                    ApplyForceToEntityCenterOfMass(veh, 1,
                        rightVec.x * pullForce,
                        rightVec.y * pullForce,
                        0.0, false, false, true, false)
                end

                -- Warning notification
                if aquaCfg.show_warning and aquaplaneLevel >= aquaCfg.warning_threshold and not warningShown then
                    warningShown = true
                    TriggerEvent('hydra:notify:show', {
                        type = 'warning', title = 'Aquaplaning',
                        message = 'Reduce speed! Road surface is slippery.',
                        duration = 4000,
                    })
                elseif aquaplaneLevel < aquaCfg.warning_threshold * 0.5 then
                    warningShown = false
                end
            end

            ::continue::
        end
    end)

    --- Get current aquaplaning level (0.0-1.0)
    function Hydra.Physics.GetAquaplaneLevel()
        return aquaplaneLevel
    end
end

-- =============================================
-- MUD / DIRT BOGGING & SINKING
-- =============================================

if bogCfg and bogCfg.enabled then
    local sinkDepth = 0.0          -- Current sink depth (0 to max_sink)
    local currentBogSurface = nil  -- Active surface config or nil
    local isStuck = false
    local escapeProgress = 0.0     -- 0 to 1.0
    local lastDirection = 0        -- 1=forward, -1=reverse, 0=none
    local lastDirChangeTime = 0
    local rockCount = 0
    local bogBaseTraction = nil
    local bogBaseInertia = nil

    --- Get weather multiplier for bogging
    local function getWeatherBogMult()
        local current = getWeatherHash()
        for name, mult in pairs(bogCfg.weather_multipliers or {}) do
            if GetHashKey(name) == current then return mult end
        end
        return 1.0
    end

    CreateThread(function()
        while true do
            Wait(bogCfg.tick_rate or 100)
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then
                -- Reset when not in vehicle
                if sinkDepth > 0 then
                    sinkDepth = 0.0
                    currentBogSurface = nil
                    isStuck = false
                    escapeProgress = 0.0
                    rockCount = 0
                    bogBaseTraction = nil
                    bogBaseInertia = nil
                end
                goto continue
            end

            local speed = GetEntitySpeed(veh) * 3.6 -- km/h
            local surface = detectSurface(veh)
            local surfaceCfg = bogCfg.surfaces[surface]

            -- Not on a boggable surface
            if not surfaceCfg then
                if sinkDepth > 0 then
                    -- Driving off the soft surface - gradually recover
                    sinkDepth = math.max(0, sinkDepth - 0.02)

                    if sinkDepth < 0.01 then
                        sinkDepth = 0.0
                        currentBogSurface = nil
                        isStuck = false
                        escapeProgress = 0.0
                        rockCount = 0

                        -- Restore handling
                        if bogBaseTraction then
                            SetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax', bogBaseTraction + 0.0)
                            SetVehicleHandlingFloat(veh, 'CHandlingData', 'fDriveInertia', bogBaseInertia + 0.0)
                            bogBaseTraction = nil
                            bogBaseInertia = nil
                        end
                    end
                end
                goto continue
            end

            currentBogSurface = surfaceCfg

            -- Store baselines on first encounter
            if not bogBaseTraction then
                bogBaseTraction = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax')
                bogBaseInertia = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fDriveInertia')
            end

            -- Class resistance
            local vehClass = GetVehicleClass(veh)
            local resistance = bogCfg.class_resistance[vehClass] or 1.0

            -- Weather amplification
            local weatherMult = getWeatherBogMult()

            -- Weight factor: heavier vehicles sink faster
            local mass = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fMass')
            local massFactor = 1.0 + (math.min(mass, 5000) / 5000) * bogCfg.weight_factor
            local tickSec = (bogCfg.tick_rate or 100) / 1000.0

            -- ---- SINKING ----
            if speed < bogCfg.sink_speed_threshold then
                -- Vehicle is slow/stopped - it sinks
                local sinkRate = surfaceCfg.sink_rate * weatherMult * massFactor / math.max(0.3, resistance)

                -- Wheel spin digging
                if bogCfg.wheelspin_dig and bogCfg.wheelspin_dig.enabled then
                    local rpm = GetVehicleCurrentRpm(veh)
                    if rpm > bogCfg.wheelspin_dig.rpm_threshold and speed < 3.0 then
                        sinkRate = sinkRate + bogCfg.wheelspin_dig.dig_rate * (rpm - bogCfg.wheelspin_dig.rpm_threshold)
                    end
                end

                sinkDepth = math.min(surfaceCfg.max_sink, sinkDepth + sinkRate * tickSec)
            elseif speed > bogCfg.escape_speed then
                -- Moving fast enough to escape - reduce sinking
                sinkDepth = math.max(0, sinkDepth - 0.03 * tickSec * 10)
            end

            -- ---- STUCK STATE ----
            local sinkRatio = sinkDepth / math.max(0.01, surfaceCfg.max_sink)
            local wasStuck = isStuck
            isStuck = sinkRatio >= 0.95 and surfaceCfg.escape_difficulty > 0.3

            if isStuck and not wasStuck then
                if bogCfg.show_stuck_warning then
                    TriggerEvent('hydra:notify:show', {
                        type = 'error', title = 'Stuck!',
                        message = 'Your vehicle is stuck. Rock forward and reverse to escape.',
                        duration = 5000,
                    })
                end
                escapeProgress = 0.0
                rockCount = 0
            end

            -- ---- ESCAPE MECHANICS ----
            if isStuck then
                local throttle = GetVehicleThrottleOffset(veh)
                local now = GetGameTimer()

                if math.abs(throttle) > 0.5 then
                    -- Holding throttle: slow escape
                    local escapeRate = (1.0 / math.max(0.5, bogCfg.stuck.escape_time)) * tickSec
                    escapeRate = escapeRate * (1.0 - surfaceCfg.escape_difficulty * 0.5)
                    escapeProgress = math.min(1.0, escapeProgress + escapeRate)
                end

                -- Rocking detection
                if bogCfg.stuck.rocking and bogCfg.stuck.rocking.enabled then
                    local dir = 0
                    if throttle > 0.5 then dir = 1
                    elseif throttle < -0.5 then dir = -1 end

                    if dir ~= 0 and dir ~= lastDirection and lastDirection ~= 0 then
                        if now - lastDirChangeTime < bogCfg.stuck.rocking.rock_window then
                            rockCount = rockCount + 1
                            escapeProgress = math.min(1.0, escapeProgress + bogCfg.stuck.rocking.boost_per_rock)
                        end
                        lastDirChangeTime = now
                    end

                    if dir ~= 0 then lastDirection = dir end
                end

                -- Escape!
                if escapeProgress >= 1.0 then
                    isStuck = false
                    sinkDepth = surfaceCfg.max_sink * 0.3 -- Partial recovery
                    escapeProgress = 0.0
                    rockCount = 0

                    -- Temporary traction boost to help drive out
                    local boostTraction = bogBaseTraction * bogCfg.stuck.escape_traction_boost
                    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax', boostTraction + 0.0)

                    TriggerEvent('hydra:notify:show', {
                        type = 'success', title = 'Unstuck',
                        message = 'Vehicle freed! Drive to solid ground.',
                        duration = 3000,
                    })

                    -- Reset boost after delay
                    SetTimeout(3000, function()
                        if DoesEntityExist(veh) then
                            -- Will be re-calculated on next tick
                        end
                    end)
                end
            end

            -- ---- APPLY PHYSICS EFFECTS ----

            -- Traction reduction based on sink depth and surface
            local tractionMult = 1.0 - (sinkRatio * (1.0 - surfaceCfg.traction_mult))
            tractionMult = tractionMult * (1.0 + (resistance - 1.0) * 0.3) -- Resistance helps traction
            local newTraction = bogBaseTraction * math.max(0.05, tractionMult)
            SetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax', newTraction + 0.0)

            -- Resistance force (slows the vehicle down)
            if speed > 1.0 and surfaceCfg.resistance > 0 then
                local resistForce = surfaceCfg.resistance * sinkRatio * weatherMult / math.max(0.3, resistance)
                local forwardVec = GetEntityForwardVector(veh)
                local vel = GetEntityVelocity(veh)
                local dotForward = vel.x * forwardVec.x + vel.y * forwardVec.y
                local brakeDir = dotForward > 0 and -1.0 or 1.0

                ApplyForceToEntityCenterOfMass(veh, 1,
                    forwardVec.x * brakeDir * resistForce * speed * 0.01,
                    forwardVec.y * brakeDir * resistForce * speed * 0.01,
                    0.0, false, false, true, false)
            end

            -- Drive inertia increase (feels like wheels spinning in mud)
            local inertiaIncrease = sinkRatio * (1.0 - surfaceCfg.traction_mult) * 0.5
            local newInertia = bogBaseInertia * (1.0 + inertiaIncrease)
            SetVehicleHandlingFloat(veh, 'CHandlingData', 'fDriveInertia', newInertia + 0.0)

            -- Visual sinking effect: lower the vehicle suspension
            if sinkDepth > 0.01 then
                local sinkAmount = -sinkDepth * 0.8  -- Negative = lower
                SetVehicleHandlingFloat(veh, 'CHandlingData', 'fSuspensionRaise', sinkAmount + 0.0)
            end

            -- If fully stuck, severely limit movement
            if isStuck then
                if speed > 2.0 then
                    -- Apply strong brake to keep vehicle nearly stopped
                    local forwardVec = GetEntityForwardVector(veh)
                    local vel = GetEntityVelocity(veh)
                    local dotForward = vel.x * forwardVec.x + vel.y * forwardVec.y
                    local brakeDir = dotForward > 0 and -1.0 or 1.0
                    local stuckBrake = surfaceCfg.escape_difficulty * 0.8

                    ApplyForceToEntityCenterOfMass(veh, 1,
                        forwardVec.x * brakeDir * stuckBrake,
                        forwardVec.y * brakeDir * stuckBrake,
                        0.0, false, false, true, false)
                end
            end

            -- Fire bogging event for other modules
            TriggerEvent('hydra:physics:bogging', {
                vehicle = veh,
                surface = surface,
                sinkDepth = sinkDepth,
                sinkRatio = sinkRatio,
                isStuck = isStuck,
                escapeProgress = escapeProgress,
                speed = speed,
            })

            ::continue::
        end
    end)

    -- Cleanup on vehicle exit: restore handling
    CreateThread(function()
        local wasInVeh = false
        while true do
            Wait(500)
            local ped = PlayerPedId()
            local inVeh = GetVehiclePedIsIn(ped, false) ~= 0

            if wasInVeh and not inVeh then
                sinkDepth = 0.0
                currentBogSurface = nil
                isStuck = false
                escapeProgress = 0.0
                bogBaseTraction = nil
                bogBaseInertia = nil
            end

            wasInVeh = inVeh
        end
    end)

    -- ---- BOGGING API ----

    --- Get current sink depth (0.0 to max_sink)
    function Hydra.Physics.GetSinkDepth()
        return sinkDepth
    end

    --- Check if vehicle is stuck
    function Hydra.Physics.IsStuck()
        return isStuck
    end

    --- Get escape progress (0.0 to 1.0)
    function Hydra.Physics.GetEscapeProgress()
        return escapeProgress
    end

    --- Get current bog surface config (or nil)
    function Hydra.Physics.GetBogSurface()
        return currentBogSurface
    end

    --- Force unstick (admin/debug)
    function Hydra.Physics.ForceUnstick()
        isStuck = false
        sinkDepth = 0.0
        escapeProgress = 0.0
        rockCount = 0
    end
end
