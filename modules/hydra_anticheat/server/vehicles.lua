--[[
    Hydra AntiCheat - Vehicle Abuse Detection

    Server-authoritative detection modules for vehicle exploits:
    - Handling modification detection
    - Vehicle fly detection
    - Vehicle torpedo detection (sustained extreme speed)
    - Vehicle spawn rate limiting
    - Horn boost detection
    - Speed modifier detection
    - Vehicle god mode detection
]]

local cfg = HydraConfig.AntiCheat
local Flag = Hydra.AntiCheat.Flag
local GetPlayer = Hydra.AntiCheat.GetPlayer
local GetPlayerState = Hydra.AntiCheat.GetPlayerState
local GetAllPlayers = Hydra.AntiCheat.GetAllPlayers
local IsModuleEnabled = Hydra.AntiCheat.IsModuleEnabled

local os_clock = os.clock
local os_time = os.time
local math_abs = math.abs
local math_sqrt = math.sqrt
local string_format = string.format

-- ---------------------------------------------------------------------------
-- Per-player vehicle tracking state
-- ---------------------------------------------------------------------------

local vehicleState = {}     -- [src] = { fly, torpedo, spawns, godmode, ... }

local function getVehicleState(src)
    if not vehicleState[src] then
        vehicleState[src] = {
            -- Fly detection
            airborneFrames = 0,
            -- Torpedo detection
            torpedoFrames = 0,
            -- Speed modifier detection
            speedViolations = 0,
            -- Vehicle spawn tracking
            spawnTimes = {},        -- list of timestamps
            -- Vehicle god mode tracking
            damageIgnored = 0,
            lastVehicleHealth = nil,
            -- Handling baseline (first report used as reference)
            handlingBaseline = nil,
        }
    end
    return vehicleState[src]
end

-- ---------------------------------------------------------------------------
-- Cleanup on player drop
-- ---------------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    vehicleState[source] = nil
end)

-- ---------------------------------------------------------------------------
-- Aircraft class whitelist for fly detection
-- Vehicle classes 15 (Helicopter) and 16 (Plane) are legitimate flyers
-- ---------------------------------------------------------------------------

local AIRCRAFT_CLASSES = {
    [15] = true,    -- Helicopter
    [16] = true,    -- Plane
}

-- ---------------------------------------------------------------------------
-- Expected max speeds per vehicle class (m/s) for speed modifier detection
-- These are approximate stock maximums for each GTA vehicle class
-- ---------------------------------------------------------------------------

local CLASS_MAX_SPEEDS = {
    [0]  = 48.0,    -- Compacts
    [1]  = 48.0,    -- Sedans
    [2]  = 55.0,    -- SUVs
    [3]  = 45.0,    -- Coupes
    [4]  = 50.0,    -- Muscle
    [5]  = 60.0,    -- Sports Classics
    [6]  = 70.0,    -- Sports
    [7]  = 85.0,    -- Super
    [8]  = 45.0,    -- Motorcycles
    [9]  = 45.0,    -- Off-Road
    [10] = 35.0,    -- Industrial
    [11] = 30.0,    -- Utility
    [12] = 30.0,    -- Vans
    [13] = 15.0,    -- Cycles (bicycles)
    [14] = 35.0,    -- Boats
    [15] = 65.0,    -- Helicopters
    [16] = 80.0,    -- Planes
    [17] = 35.0,    -- Service
    [18] = 55.0,    -- Emergency
    [19] = 50.0,    -- Military
    [20] = 40.0,    -- Commercial
    [21] = 50.0,    -- Trains
    [22] = 70.0,    -- Open Wheel
}

local DEFAULT_CLASS_MAX_SPEED = 70.0

-- =========================================================================
-- 1. HANDLING MODIFICATION DETECTION
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:handling', function(data)
    local src = source
    if not IsModuleEnabled('vehicles') then return end

    local vcfg = cfg.vehicles
    if not vcfg.handling_check then return end

    local p = GetPlayer(src)
    if not p then return end

    -- Validate payload
    if type(data) ~= 'table' then
        Flag(src, 'vehicles', 'Invalid handling report payload', 3, 'kick')
        return
    end

    local vs = getVehicleState(src)
    local tolerance = vcfg.handling_tolerance or 0.3

    -- Key handling fields to check
    local handlingFields = {
        'fMass', 'fInitialDriveForce', 'fBrakeForce', 'fTractionCurveMax',
        'fTractionCurveMin', 'fSuspensionForce', 'fSteeringLock',
        'fDriveInertia', 'fInitialDragCoeff', 'fBrakeBiasFront',
    }

    -- Use the first valid report as the baseline for this vehicle
    -- If the player changes vehicle, client should send a fresh report
    local vehicleModel = data.model
    if not vs.handlingBaseline or vs.handlingBaseline.model ~= vehicleModel then
        -- Store first report as baseline reference
        vs.handlingBaseline = {}
        vs.handlingBaseline.model = vehicleModel
        for _, field in ipairs(handlingFields) do
            if data[field] and type(data[field]) == 'number' then
                vs.handlingBaseline[field] = data[field]
            end
        end
        return  -- First report establishes baseline, no check
    end

    -- Compare current values against baseline using normalized deviation
    local violations = {}
    for _, field in ipairs(handlingFields) do
        local current = data[field]
        local baseline = vs.handlingBaseline[field]

        if current and baseline and type(current) == 'number' and type(baseline) == 'number' then
            if baseline ~= 0 then
                local deviation = math_abs(current - baseline) / math_abs(baseline)
                if deviation > tolerance then
                    violations[#violations + 1] = string_format(
                        '%s: %.2f -> %.2f (%.0f%% deviation)',
                        field, baseline, current, deviation * 100
                    )
                end
            elseif math_abs(current) > 0.01 then
                -- Baseline was zero but now it is not
                violations[#violations + 1] = string_format(
                    '%s: 0 -> %.2f (non-zero from zero baseline)',
                    field, current
                )
            end
        end
    end

    -- Also check for extreme outlier values regardless of baseline
    if data.fInitialDriveForce and data.fInitialDriveForce > 10.0 then
        violations[#violations + 1] = string_format(
            'fInitialDriveForce extreme outlier: %.2f', data.fInitialDriveForce
        )
    end
    if data.fMass and data.fMass < 1.0 then
        violations[#violations + 1] = string_format(
            'fMass extreme outlier (near-zero): %.2f', data.fMass
        )
    end
    if data.fTractionCurveMax and data.fTractionCurveMax > 10.0 then
        violations[#violations + 1] = string_format(
            'fTractionCurveMax extreme outlier: %.2f', data.fTractionCurveMax
        )
    end
    if data.fBrakeForce and data.fBrakeForce > 20.0 then
        violations[#violations + 1] = string_format(
            'fBrakeForce extreme outlier: %.2f', data.fBrakeForce
        )
    end

    if #violations > 0 then
        Flag(src, 'vehicles',
            string_format('Handling modification detected (%d field%s): %s',
                #violations, #violations > 1 and 's' or '', violations[1]),
            vcfg.handling_severity or 3, vcfg.handling_action or 'kick', {
                model = vehicleModel,
                violations = violations,
            })
    end
end)

-- =========================================================================
-- 2. VEHICLE FLY DETECTION  &  3. TORPEDO DETECTION  &  6. SPEED MODIFIER
-- =========================================================================
-- All three share the same client report event for efficiency.

RegisterNetEvent('hydra:anticheat:report:vehicle_state', function(data)
    local src = source
    if not IsModuleEnabled('vehicles') then return end

    local p = GetPlayer(src)
    if not p then return end

    -- Validate payload
    if type(data) ~= 'table' then
        Flag(src, 'vehicles', 'Invalid vehicle state payload', 3, 'kick')
        return
    end

    local vcfg = cfg.vehicles
    local vs = getVehicleState(src)

    local inAir = data.inAir
    local speed = tonumber(data.speed) or 0
    local altitude = tonumber(data.altitude) or 0
    local verticalVelocity = tonumber(data.verticalVelocity) or 0
    local vehicleClass = tonumber(data.vehicleClass)
    local isOnGround = data.isOnGround
    local vehicleModel = data.model

    -- ------------------------------------------------------------------
    -- 2. Vehicle Fly Detection
    -- ------------------------------------------------------------------
    if vcfg.fly_detection then
        local isAircraft = vehicleClass and AIRCRAFT_CLASSES[vehicleClass]

        if inAir and not isAircraft and speed > 5.0 then
            -- Vehicle is airborne, moving horizontally, and not an aircraft
            vs.airborneFrames = vs.airborneFrames + 1

            if vs.airborneFrames >= (vcfg.fly_threshold or 8) then
                Flag(src, 'vehicles',
                    string_format('Vehicle fly detected: %d consecutive airborne frames, speed %.1f m/s, alt %.1f',
                        vs.airborneFrames, speed, altitude),
                    vcfg.fly_severity or 4, vcfg.fly_action or 'kick', {
                        frames = vs.airborneFrames,
                        speed = speed,
                        altitude = altitude,
                        verticalVelocity = verticalVelocity,
                        vehicleClass = vehicleClass,
                        model = vehicleModel,
                    })
                vs.airborneFrames = 0
            end
        else
            vs.airborneFrames = 0
        end
    end

    -- ------------------------------------------------------------------
    -- 3. Vehicle Torpedo Detection
    -- ------------------------------------------------------------------
    if vcfg.torpedo_detection then
        local torpedoSpeed = vcfg.torpedo_speed or 80.0

        -- Sustained extreme speed while on ground (or near ground)
        if not inAir and speed > torpedoSpeed then
            vs.torpedoFrames = vs.torpedoFrames + 1

            if vs.torpedoFrames >= 3 then
                Flag(src, 'vehicles',
                    string_format('Vehicle torpedo detected: %.1f m/s for %d consecutive reports (threshold %.1f)',
                        speed, vs.torpedoFrames, torpedoSpeed),
                    vcfg.torpedo_severity or 4, vcfg.torpedo_action or 'kick', {
                        speed = speed,
                        frames = vs.torpedoFrames,
                        threshold = torpedoSpeed,
                        model = vehicleModel,
                    })
                vs.torpedoFrames = 0
            end
        else
            vs.torpedoFrames = 0
        end
    end

    -- ------------------------------------------------------------------
    -- 6. Speed Modifier Detection
    -- ------------------------------------------------------------------
    if vcfg.speed_modifier then
        local maxMultiplier = vcfg.max_speed_multiplier or 1.5
        local classMax = CLASS_MAX_SPEEDS[vehicleClass] or DEFAULT_CLASS_MAX_SPEED
        local allowedMax = classMax * maxMultiplier

        if speed > allowedMax then
            vs.speedViolations = vs.speedViolations + 1

            -- Require 3 consecutive violations to reduce false positives
            if vs.speedViolations >= 3 then
                Flag(src, 'vehicles',
                    string_format('Speed modifier detected: %.1f m/s exceeds %.1f (class %s max %.1f * %.1fx)',
                        speed, allowedMax, tostring(vehicleClass), classMax, maxMultiplier),
                    vcfg.torpedo_severity or 4, vcfg.torpedo_action or 'kick', {
                        speed = speed,
                        vehicleClass = vehicleClass,
                        classMax = classMax,
                        allowedMax = allowedMax,
                        consecutiveViolations = vs.speedViolations,
                        model = vehicleModel,
                    })
                vs.speedViolations = 0
            end
        else
            vs.speedViolations = 0
        end
    end
end)

-- =========================================================================
-- 4. VEHICLE SPAWN RATE LIMITING
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:vehicle_spawn', function(data)
    local src = source
    if not IsModuleEnabled('vehicles') then return end

    local vcfg = cfg.vehicles
    if not vcfg.spawn_validation then return end

    local p = GetPlayer(src)
    if not p then return end

    local vs = getVehicleState(src)
    local now = os_time()

    -- Validate payload
    if type(data) ~= 'table' then
        data = {}
    end

    local spawnedModel = data.model

    -- ------------------------------------------------------------------
    -- Check against blacklisted vehicle models (from entities config)
    -- ------------------------------------------------------------------
    local ecfg = cfg.entities
    if ecfg and ecfg.blacklisted_vehicles then
        for _, blocked in ipairs(ecfg.blacklisted_vehicles) do
            if spawnedModel and (spawnedModel == blocked or GetHashKey(tostring(blocked)) == spawnedModel) then
                Flag(src, 'vehicles',
                    string_format('Blacklisted vehicle model spawned: %s', tostring(spawnedModel)),
                    ecfg.blacklist_severity or 5, ecfg.blacklist_action or 'ban', {
                        model = spawnedModel,
                    })
                return
            end
        end
    end

    -- ------------------------------------------------------------------
    -- Rate limit: track spawns per minute
    -- ------------------------------------------------------------------
    local maxPerMinute = vcfg.max_vehicle_spawns_per_minute or 5

    -- Prune entries older than 60 seconds
    local fresh = {}
    for _, t in ipairs(vs.spawnTimes) do
        if (now - t) < 60 then
            fresh[#fresh + 1] = t
        end
    end
    vs.spawnTimes = fresh

    -- Record this spawn
    vs.spawnTimes[#vs.spawnTimes + 1] = now

    if #vs.spawnTimes > maxPerMinute then
        Flag(src, 'vehicles',
            string_format('Vehicle spawn rate exceeded: %d spawns/min (max %d)',
                #vs.spawnTimes, maxPerMinute),
            vcfg.spawn_severity or 3, vcfg.spawn_action or 'kick', {
                count = #vs.spawnTimes,
                maxPerMinute = maxPerMinute,
                model = spawnedModel,
            })
    end
end)

-- =========================================================================
-- 5. HORN BOOST DETECTION
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:horn', function(data)
    local src = source
    if not IsModuleEnabled('vehicles') then return end

    local vcfg = cfg.vehicles
    if not vcfg.horn_boost then return end

    local p = GetPlayer(src)
    if not p then return end

    -- Validate payload
    if type(data) ~= 'table' then
        Flag(src, 'vehicles', 'Invalid horn report payload', 3, 'kick')
        return
    end

    local speedBefore = tonumber(data.speedBefore) or 0
    local speedAfter = tonumber(data.speedAfter) or 0
    local tolerance = vcfg.horn_boost_tolerance or 2.0

    local speedIncrease = speedAfter - speedBefore

    if speedIncrease > tolerance then
        Flag(src, 'vehicles',
            string_format('Horn boost detected: speed %.1f -> %.1f (+%.1f m/s, tolerance %.1f)',
                speedBefore, speedAfter, speedIncrease, tolerance),
            vcfg.handling_severity or 3, vcfg.handling_action or 'kick', {
                speedBefore = speedBefore,
                speedAfter = speedAfter,
                increase = speedIncrease,
                tolerance = tolerance,
            })
    end
end)

-- =========================================================================
-- 7. VEHICLE GOD MODE DETECTION
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:vehicle_damage', function(data)
    local src = source
    if not IsModuleEnabled('vehicles') then return end

    local gcfg = cfg.godmode
    if not gcfg or not gcfg.vehicle_godmode then return end

    local p = GetPlayer(src)
    if not p then return end

    -- Validate payload
    if type(data) ~= 'table' then
        Flag(src, 'vehicles', 'Invalid vehicle damage report payload', 3, 'kick')
        return
    end

    local vs = getVehicleState(src)

    local damageApplied = tonumber(data.damageApplied) or 0
    local healthBefore = tonumber(data.healthBefore)
    local healthAfter = tonumber(data.healthAfter)

    -- Ensure we have valid health values
    if not healthBefore or not healthAfter then return end

    local healthDelta = healthBefore - healthAfter

    -- If damage was reported but the vehicle health did not decrease
    if damageApplied > 0 and healthDelta <= 0 then
        vs.damageIgnored = vs.damageIgnored + 1

        local vehicleTolerance = gcfg.vehicle_tolerance or 3

        if vs.damageIgnored >= vehicleTolerance then
            Flag(src, 'vehicles',
                string_format('Vehicle god mode suspected: %d damage events ignored, health unchanged (%d -> %d)',
                    vs.damageIgnored, healthBefore, healthAfter),
                gcfg.severity or 4, gcfg.action or 'kick', {
                    damageIgnored = vs.damageIgnored,
                    healthBefore = healthBefore,
                    healthAfter = healthAfter,
                    lastDamageApplied = damageApplied,
                    model = data.model,
                })
            vs.damageIgnored = 0
        end
    else
        -- Health did decrease — reset counter
        vs.damageIgnored = 0
    end

    vs.lastVehicleHealth = healthAfter
end)

-- =========================================================================
-- Periodic state cleanup for stale entries
-- =========================================================================

CreateThread(function()
    while true do
        Wait(60000)
        local activePlayers = GetAllPlayers()
        for src, _ in pairs(vehicleState) do
            if not activePlayers[src] then
                vehicleState[src] = nil
            end
        end
    end
end)
