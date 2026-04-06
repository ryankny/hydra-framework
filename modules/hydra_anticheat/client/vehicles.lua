--[[
    Hydra AntiCheat - Vehicle Monitors

    Client-side vehicle state monitoring threads that report to the server.
    All enforcement decisions are made server-side — the client only reports.

    Monitors:
        1. Vehicle state reporting (speed, altitude, airborne, class)
        2. Handling modification detection
        3. Vehicle spawn detection
        4. Horn boost detection
        5. Vehicle damage tracking (vehicle god mode)
]]

local cfg = HydraConfig.AntiCheat

-- ---------------------------------------------------------------------------
-- Early exit if vehicles module is disabled
-- ---------------------------------------------------------------------------
if not cfg.vehicles or not cfg.vehicles.enabled then return end

-- ---------------------------------------------------------------------------
-- Localise natives for performance
-- ---------------------------------------------------------------------------
local GetGameTimer            = GetGameTimer
local PlayerPedId             = PlayerPedId
local PlayerId                = PlayerId
local DoesEntityExist         = DoesEntityExist
local IsPedInAnyVehicle       = IsPedInAnyVehicle
local GetVehiclePedIsIn       = GetVehiclePedIsIn
local GetEntityCoords         = GetEntityCoords
local GetEntitySpeed          = GetEntitySpeed
local GetEntityModel          = GetEntityModel
local GetEntityHeightAboveGround = GetEntityHeightAboveGround
local IsEntityInAir           = IsEntityInAir
local IsVehicleOnAllWheels    = IsVehicleOnAllWheels
local GetVehicleClass         = GetVehicleClass
local GetVehicleHandlingFloat = GetVehicleHandlingFloat
local GetVehicleBodyHealth    = GetVehicleBodyHealth
local GetVehicleEngineHealth  = GetVehicleEngineHealth
local HasEntityBeenDamagedByAnyVehicle = HasEntityBeenDamagedByAnyVehicle
local HasEntityBeenDamagedByAnyObject  = HasEntityBeenDamagedByAnyObject
local HasEntityBeenDamagedByAnyPed     = HasEntityBeenDamagedByAnyPed
local ClearEntityLastDamageEntity      = ClearEntityLastDamageEntity
local GetEntityVelocity       = GetEntityVelocity
local NetworkIsPlayerActive   = NetworkIsPlayerActive
local NetworkGetEntityOwner   = NetworkGetEntityOwner
local IsControlPressed        = IsControlPressed
local GetGamePool             = GetGamePool
local TriggerServerEvent      = TriggerServerEvent
local Wait                    = Wait

local math_abs  = math.abs
local math_sqrt = math.sqrt

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------

--- Returns the player's current vehicle handle or nil when on foot.
local function getCurrentVehicle()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return nil end
    if not IsPedInAnyVehicle(ped, false) then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return nil end
    return veh
end

-- =========================================================================
-- 1.  VEHICLE STATE REPORTING THREAD
-- =========================================================================

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(3000) -- staggered start

    local IN_VEHICLE_INTERVAL  = 2000
    local ON_FOOT_INTERVAL     = 5000

    -- Previous state for change detection
    local prevSpeed    = 0.0
    local prevAltitude = 0.0
    local prevInAir    = false
    local prevModel    = 0
    local lastReport   = 0
    local PERIODIC_FORCE_INTERVAL = 10000 -- force report every 10s even if unchanged

    while true do
        local veh = getCurrentVehicle()

        if veh then
            Wait(IN_VEHICLE_INTERVAL)

            local speed    = GetEntitySpeed(veh)
            local pos      = GetEntityCoords(veh)
            local altitude = pos.z
            local vel      = GetEntityVelocity(veh)
            local vertVel  = vel.z
            local inAir    = IsEntityInAir(veh)
            local grounded = IsVehicleOnAllWheels(veh)
            local vClass   = GetVehicleClass(veh)
            local model    = GetEntityModel(veh)

            -- Determine if state changed significantly
            local now = GetGameTimer()
            local speedDelta    = math_abs(speed - prevSpeed)
            local altDelta      = math_abs(altitude - prevAltitude)
            local airChanged    = inAir ~= prevInAir
            local modelChanged  = model ~= prevModel
            local periodic      = (now - lastReport) >= PERIODIC_FORCE_INTERVAL

            if speedDelta > 2.0 or altDelta > 3.0 or airChanged or modelChanged or periodic then
                TriggerServerEvent('hydra:anticheat:report:vehicle_state', {
                    speed    = speed,
                    altitude = altitude,
                    vertVel  = vertVel,
                    inAir    = inAir,
                    grounded = grounded,
                    class    = vClass,
                    model    = model,
                })

                prevSpeed    = speed
                prevAltitude = altitude
                prevInAir    = inAir
                prevModel    = model
                lastReport   = now
            end
        else
            -- Not in vehicle — sleep longer
            Wait(ON_FOOT_INTERVAL)

            -- Reset previous state so the first frame in a new vehicle always reports
            prevSpeed    = 0.0
            prevAltitude = 0.0
            prevInAir    = false
            prevModel    = 0
        end
    end
end)

-- =========================================================================
-- 2.  HANDLING REPORTING THREAD
-- =========================================================================

if cfg.vehicles.handling_check then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(6000) -- staggered start

        local interval = cfg.vehicles.handling_check_interval or 30000

        while true do
            local veh = getCurrentVehicle()

            if veh then
                local model = GetEntityModel(veh)

                local handlingData = {
                    fMass              = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fMass'),
                    fInitialDriveForce = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce'),
                    fBrakeForce        = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fBrakeForce'),
                    fTractionCurveMax  = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax'),
                    fInitialDragCoeff  = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDragCoeff'),
                    fDriveInertia      = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fDriveInertia'),
                }

                TriggerServerEvent('hydra:anticheat:report:handling', {
                    model  = model,
                    values = handlingData,
                })

                Wait(interval)
            else
                -- Not in vehicle — check less frequently
                Wait(5000)
            end
        end
    end)
end

-- =========================================================================
-- 3.  VEHICLE SPAWN DETECTION
-- =========================================================================

if cfg.vehicles.spawn_validation then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(12000) -- staggered start — let world populate first

        local playerId = PlayerId()

        -- Snapshot existing vehicles so we only flag new ones
        local knownVehicles = {}
        local pool = GetGamePool('CVehicle')
        for i = 1, #pool do
            knownVehicles[pool[i]] = true
        end

        -- Track spawns per minute for rate limiting reports
        local spawnTimes   = {}
        local SPAWN_WINDOW = 60000 -- 1 minute

        local CHECK_INTERVAL = 2000

        while true do
            Wait(CHECK_INTERVAL)

            local now      = GetGameTimer()
            local newPool  = GetGamePool('CVehicle')

            for i = 1, #newPool do
                local veh = newPool[i]
                if not knownVehicles[veh] then
                    knownVehicles[veh] = true

                    -- Only report vehicles owned by this player (they likely created it)
                    if NetworkGetEntityOwner(veh) == playerId then
                        -- Prune old timestamps from the window
                        local j = 1
                        while j <= #spawnTimes do
                            if (now - spawnTimes[j]) > SPAWN_WINDOW then
                                table.remove(spawnTimes, j)
                            else
                                j = j + 1
                            end
                        end

                        spawnTimes[#spawnTimes + 1] = now

                        local model = GetEntityModel(veh)
                        TriggerServerEvent('hydra:anticheat:report:vehicle_spawn', model)
                    end
                end
            end

            -- Prune handles that are no longer valid to avoid memory growth
            -- Do this infrequently (piggyback on main loop, every ~30s)
            if now % 30000 < CHECK_INTERVAL then
                local valid = {}
                for handle in pairs(knownVehicles) do
                    if DoesEntityExist(handle) then
                        valid[handle] = true
                    end
                end
                knownVehicles = valid
            end
        end
    end)

    -- Also catch the player entering a newly-created vehicle via event
    AddEventHandler('gameEventTriggered', function(name, args)
        if name ~= 'CEventNetworkPlayerEnteredVehicle' then return end

        -- args[1] = player ped, args[2] = vehicle
        local ped = args[1]
        if ped ~= PlayerPedId() then return end

        local veh = args[2]
        if not veh or veh == 0 or not DoesEntityExist(veh) then return end

        local model = GetEntityModel(veh)
        TriggerServerEvent('hydra:anticheat:report:vehicle_spawn', model)
    end)
end

-- =========================================================================
-- 4.  HORN BOOST DETECTION
-- =========================================================================

if cfg.vehicles.horn_boost then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(9000) -- staggered start

        local HORN_CONTROL   = 86  -- INPUT_VEH_HORN
        local MEASURE_DELAY  = 500 -- ms after horn press to measure speed
        local tolerance      = cfg.vehicles.horn_boost_tolerance or 2.0
        local hornCooldown   = 0

        while true do
            local veh = getCurrentVehicle()

            if veh then
                Wait(0) -- tick-rate while in vehicle for responsive horn detection

                if IsControlPressed(0, HORN_CONTROL) then
                    local now = GetGameTimer()

                    -- Cooldown: only check once per horn press cycle (1.5s)
                    if (now - hornCooldown) > 1500 then
                        hornCooldown = now
                        local speedBefore = GetEntitySpeed(veh)

                        -- Wait the measurement window
                        Wait(MEASURE_DELAY)

                        -- Re-check we are still in the same vehicle
                        local veh2 = getCurrentVehicle()
                        if veh2 and veh2 == veh then
                            local speedAfter = GetEntitySpeed(veh2)
                            local increase   = speedAfter - speedBefore

                            if increase > tolerance then
                                TriggerServerEvent('hydra:anticheat:report:horn', {
                                    speedBefore = speedBefore,
                                    speedAfter  = speedAfter,
                                })
                            end
                        end
                    end
                end
            else
                -- Not in vehicle — sleep longer
                Wait(1000)
            end
        end
    end)
end

-- =========================================================================
-- 5.  VEHICLE DAMAGE TRACKING (vehicle god mode detection)
-- =========================================================================

if cfg.godmode and cfg.godmode.vehicle_godmode then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(7000) -- staggered start

        local interval = cfg.godmode.vehicle_check_interval or 15000
        local CHECK_TICK = 500

        local prevBodyHealth   = nil
        local prevEngineHealth = nil
        local lastVehicle      = nil

        while true do
            local veh = getCurrentVehicle()

            if veh then
                local bodyHealth   = GetVehicleBodyHealth(veh)
                local engineHealth = GetVehicleEngineHealth(veh)

                -- Reset tracking when switching vehicles
                if veh ~= lastVehicle then
                    prevBodyHealth   = bodyHealth
                    prevEngineHealth = engineHealth
                    lastVehicle      = veh
                    ClearEntityLastDamageEntity(veh)
                    Wait(CHECK_TICK)
                    goto continue
                end

                -- Check if vehicle was damaged since last tick
                local wasDamaged = HasEntityBeenDamagedByAnyVehicle(veh)
                    or HasEntityBeenDamagedByAnyObject(veh)
                    or HasEntityBeenDamagedByAnyPed(veh)

                if wasDamaged then
                    -- Vehicle received a damage event — health should have decreased
                    local bodyDelta   = prevBodyHealth - bodyHealth
                    local engineDelta = prevEngineHealth - engineHealth

                    -- If neither body nor engine health decreased despite damage event
                    if bodyDelta <= 0.0 and engineDelta <= 0.0 then
                        TriggerServerEvent('hydra:anticheat:report:vehicle_damage', {
                            expected = {
                                bodyBefore   = prevBodyHealth,
                                engineBefore = prevEngineHealth,
                            },
                            actual = {
                                bodyAfter   = bodyHealth,
                                engineAfter = engineHealth,
                            },
                        })
                    end

                    ClearEntityLastDamageEntity(veh)
                end

                prevBodyHealth   = bodyHealth
                prevEngineHealth = engineHealth

                Wait(CHECK_TICK)
            else
                -- Not in vehicle — reset and sleep
                prevBodyHealth   = nil
                prevEngineHealth = nil
                lastVehicle      = nil
                Wait(2000)
            end

            ::continue::
        end
    end)
end
