--[[
    Hydra AntiCheat - Menu Detection

    Client-side heuristics to detect cheat menus, executors, and suspicious
    modifications. All findings are reported to the server — enforcement
    decisions (kick, ban, log) happen server-side only.

    Detection modules:
      1. Global variable scanning
      2. Blacklisted resource detection
      3. Suspicious native usage detection
      4. Vision abuse detection (thermal / night vision)
      5. Expanded ped flag monitoring
      6. Task manipulation detection
      7. Model change detection
      8. Pickup distance validation
]]

local cfg = HydraConfig.AntiCheat

-- ---------------------------------------------------------------------------
-- Localise natives for performance
-- ---------------------------------------------------------------------------
local GetGameTimer          = GetGameTimer
local PlayerPedId           = PlayerPedId
local PlayerId              = PlayerId
local GetEntityCoords       = GetEntityCoords
local DoesEntityExist       = DoesEntityExist
local GetPedConfigFlag      = GetPedConfigFlag
local IsEntityVisible       = IsEntityVisible
-- IsEntityInvincible is not a valid FiveM native; use GetPlayerInvincible instead
local GetPlayerInvincible   = GetPlayerInvincible
local GetEntityModel        = GetEntityModel
local GetNumResources       = GetNumResources
local GetResourceByFindIndex = GetResourceByFindIndex
local NetworkIsPlayerActive = NetworkIsPlayerActive
local TriggerServerEvent    = TriggerServerEvent
local Wait                  = Wait
local GetSeethrough         = GetSeethrough
local GetUsingseethrough    = GetUsingseethrough
local IsNightvisionActive   = IsNightvisionActive
local SetEntityCoords       = SetEntityCoords
local SetEntityVisible      = SetEntityVisible
local SetPlayerInvincible   = SetPlayerInvincible
-- GetPedScriptTaskCommand is not a valid FiveM native; use GetIsTaskActive instead
local IsPedShooting         = IsPedShooting
local type                  = type
local pairs                 = pairs
local pcall                 = pcall
local rawget                = rawget
local getmetatable          = getmetatable
local tostring              = tostring
local string_lower          = string.lower
local string_find           = string.find
local string_byte           = string.byte
local math_abs              = math.abs

-- =========================================================================
-- 1. GLOBAL VARIABLE SCANNING
-- =========================================================================

if cfg.menu_detection and cfg.menu_detection.enabled and cfg.menu_detection.check_globals then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(12000) -- staggered start

        local interval = cfg.menu_detection.check_interval or 15000
        local blacklisted = {}

        -- Build fast lookup table from config list
        for _, name in ipairs(cfg.menu_detection.blacklisted_globals or {}) do
            blacklisted[name] = true
        end

        while true do
            Wait(interval)

            -- Scan _G for blacklisted names
            for key, val in pairs(_G) do
                if type(key) == 'string' then
                    -- Direct blacklist match
                    if blacklisted[key] then
                        TriggerServerEvent('hydra:anticheat:report:menu', {
                            type = 'global',
                            name = key,
                        })
                    end

                    -- Check for obfuscated hex-escape keys (e.g. '\x65\x78\x65\x63')
                    -- These keys contain non-printable or escaped characters
                    local hasEscaped = false
                    for i = 1, #key do
                        local b = string_byte(key, i)
                        if b < 32 or b > 126 then
                            hasEscaped = true
                            break
                        end
                    end
                    if hasEscaped then
                        TriggerServerEvent('hydra:anticheat:report:menu', {
                            type = 'global',
                            name = '<obfuscated_key>',
                        })
                    end

                    -- Check for suspicious metatables on global tables
                    -- Injected code often sets __index to intercept reads
                    if type(val) == 'table' then
                        local ok, mt = pcall(getmetatable, val)
                        if ok and mt and type(mt) == 'table' then
                            local idx = rawget(mt, '__index')
                            if idx and type(idx) == 'function' then
                                -- Legitimate tables rarely use __index as a
                                -- function at the top-level _G scope; flag it
                                TriggerServerEvent('hydra:anticheat:report:menu', {
                                    type = 'global',
                                    name = key .. ':suspicious_metatable',
                                })
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- =========================================================================
-- 2. BLACKLISTED RESOURCE DETECTION
-- =========================================================================

if cfg.menu_detection and cfg.menu_detection.enabled and cfg.menu_detection.blacklisted_resources then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(14000) -- staggered start

        local interval = cfg.menu_detection.check_interval or 15000

        -- Build fast lowercase lookup
        local blacklisted = {}
        for _, name in ipairs(cfg.menu_detection.blacklisted_resources) do
            blacklisted[string_lower(name)] = true
        end

        while true do
            Wait(interval)

            local numResources = GetNumResources()
            for i = 0, numResources - 1 do
                local resName = GetResourceByFindIndex(i)
                if resName then
                    local lower = string_lower(resName)
                    if blacklisted[lower] then
                        TriggerServerEvent('hydra:anticheat:report:menu', {
                            type = 'resource',
                            name = resName,
                        })
                    end
                end
            end
        end
    end)
end

-- =========================================================================
-- 3. SUSPICIOUS NATIVE USAGE DETECTION
-- =========================================================================

if cfg.menu_detection and cfg.menu_detection.enabled and cfg.menu_detection.check_natives then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(16000) -- staggered start

        -- Track rapid SetEntityCoords calls (teleport hack indicator)
        local coordsCallCount = 0
        local coordsLastReset = GetGameTimer()
        local COORDS_THRESHOLD = 10          -- calls per second
        local COORDS_WINDOW = 1000           -- 1 second window

        -- Track SetPedComponentVariation spam
        local compVarCount = 0
        local compVarLastReset = GetGameTimer()
        local COMPVAR_THRESHOLD = 30         -- calls per second
        local COMPVAR_WINDOW = 1000

        -- Monitor by wrapping global references if they exist
        -- We detect abuse by tracking the player ped's state changes

        local lastPos = nil
        local rapidTeleportCount = 0

        while true do
            Wait(500)

            local ped = PlayerPedId()
            if not DoesEntityExist(ped) then goto continue end

            local now = GetGameTimer()
            local pos = GetEntityCoords(ped)

            -- Detect rapid position changes (teleport hack)
            if lastPos then
                local dist = #(pos - lastPos)
                -- 500ms interval: even at max sprint (~7.2 m/s) player moves ~3.6m
                -- Threshold set higher to avoid false positives from vehicles
                if dist > 50.0 then
                    rapidTeleportCount = rapidTeleportCount + 1
                    if rapidTeleportCount >= 3 then
                        TriggerServerEvent('hydra:anticheat:report:menu', {
                            type = 'native_abuse',
                            name = 'rapid_teleport',
                            distance = dist,
                            count = rapidTeleportCount,
                        })
                        rapidTeleportCount = 0
                    end
                else
                    -- Decay counter slowly
                    if rapidTeleportCount > 0 then
                        rapidTeleportCount = rapidTeleportCount - 1
                    end
                end
            end
            lastPos = pos

            -- Check for SetPlayerInvincible being active when it should not be
            if GetPlayerInvincible(PlayerId()) then
                TriggerServerEvent('hydra:anticheat:report:menu', {
                    type = 'native_abuse',
                    name = 'SetPlayerInvincible',
                })
            end

            -- Check for entity invisibility to network
            -- NetworkSetEntityInvisibleToNetwork makes player invisible to others
            if not IsEntityVisible(ped) then
                TriggerServerEvent('hydra:anticheat:report:menu', {
                    type = 'native_abuse',
                    name = 'invisible_to_network',
                })
            end

            ::continue::
        end
    end)
end

-- =========================================================================
-- 4. VISION ABUSE DETECTION (Thermal / Night Vision)
-- =========================================================================

if cfg.vision and cfg.vision.enabled then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(18000) -- staggered start

        local interval = cfg.vision.check_interval or 5000
        local allowedJobs = {}
        for _, job in ipairs(cfg.vision.allowed_jobs or {}) do
            allowedJobs[job] = true
        end

        while true do
            Wait(interval)

            local thermalActive = false
            local nightVisionActive = false

            -- Check thermal vision (seethrough)
            if cfg.vision.block_thermal then
                local ok1, result1 = pcall(GetSeethrough)
                local ok2, result2 = pcall(GetUsingseethrough)
                if (ok1 and result1) or (ok2 and result2) then
                    thermalActive = true
                end
            end

            -- Check night vision
            if cfg.vision.block_night_vision then
                local ok, result = pcall(IsNightvisionActive)
                if ok and result then
                    nightVisionActive = true
                end
            end

            if thermalActive or nightVisionActive then
                -- Check if the player's job allows vision usage
                local jobAllowed = false
                local ok, playerData = pcall(function()
                    return exports['hydra_bridge']:GetPlayer()
                end)
                if ok and playerData and playerData.job and playerData.job.name then
                    if allowedJobs[playerData.job.name] then
                        jobAllowed = true
                    end
                end

                if not jobAllowed then
                    if thermalActive then
                        TriggerServerEvent('hydra:anticheat:report:vision', {
                            type = 'thermal',
                            active = true,
                        })
                    end
                    if nightVisionActive then
                        TriggerServerEvent('hydra:anticheat:report:vision', {
                            type = 'nightvision',
                            active = true,
                        })
                    end
                end
            end
        end
    end)
end

-- =========================================================================
-- 5. EXPANDED PED FLAG MONITORING
-- =========================================================================

if cfg.ped_flags and cfg.ped_flags.enabled then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(9000) -- staggered start (offset from monitors.lua ped flags at 8000)

        local interval = cfg.ped_flags.check_interval or 5000
        local lastPos = nil

        while true do
            Wait(interval)

            local ped = PlayerPedId()
            if not DoesEntityExist(ped) then goto continue end

            local flags = {}
            local detected = false

            -- Flag 32: can't be dragged out of vehicle
            flags.cantBeDragged = GetPedConfigFlag(ped, 32, true)
            if flags.cantBeDragged then detected = true end

            -- Flag 292: disable melee (some menus set this)
            flags.disableMelee = GetPedConfigFlag(ped, 292, true)
            if flags.disableMelee then detected = true end

            -- Flag 62: is invincible
            flags.invincibleFlag = GetPedConfigFlag(ped, 62, true)
            if flags.invincibleFlag then detected = true end

            -- Direct invincibility check
            flags.playerInvincible = GetPlayerInvincible(PlayerId())
            if flags.playerInvincible then detected = true end

            -- Teleport detection: position change > 100m in one check interval
            local pos = GetEntityCoords(ped)
            if lastPos then
                local dist = #(pos - lastPos)
                if dist > 100.0 then
                    flags.teleportDistance = dist
                    detected = true
                end
            end
            lastPos = pos

            if detected then
                TriggerServerEvent('hydra:anticheat:report:ped_flags', flags)
            end

            ::continue::
        end
    end)
end

-- =========================================================================
-- 6. TASK MANIPULATION DETECTION
-- =========================================================================

if cfg.ped_flags and cfg.ped_flags.enabled and cfg.ped_flags.detect_task_clear then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(11000) -- staggered start

        local maxRate = cfg.ped_flags.task_clear_rate or 5
        local clearCount = 0
        local windowStart = GetGameTimer()
        local WINDOW = 10000  -- 10 seconds
        local wasTaskNothing = false

        while true do
            Wait(200) -- check roughly 5 times per second

            local ped = PlayerPedId()
            if not DoesEntityExist(ped) then goto continue end

            -- Check if ped has no active task (idle) using common task hashes
            local isTaskNothing = not IsPedWalking(ped) and not IsPedRunning(ped)
                and not IsPedSprinting(ped) and not IsPedInAnyVehicle(ped, false)
                and not IsPedRagdoll(ped) and not IsPedFalling(ped)
                and not GetIsTaskActive(ped, 0) -- CTaskHandsUp

            -- Count transitions into TASK_NOTHING
            if isTaskNothing and not wasTaskNothing then
                clearCount = clearCount + 1
            end
            wasTaskNothing = isTaskNothing

            local now = GetGameTimer()
            if (now - windowStart) >= WINDOW then
                if clearCount > maxRate then
                    TriggerServerEvent('hydra:anticheat:report:ped_flags', {
                        taskClearAbuse = true,
                        clearCount = clearCount,
                        window = WINDOW,
                    })
                end
                clearCount = 0
                windowStart = now
            end

            ::continue::
        end
    end)
end

-- =========================================================================
-- 7. MODEL CHANGE DETECTION
-- =========================================================================

if cfg.ped_flags and cfg.ped_flags.enabled and cfg.ped_flags.detect_model_change then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(13000) -- staggered start

        local FREEMODE_MALE   = `mp_m_freemode_01`
        local FREEMODE_FEMALE = `mp_f_freemode_01`

        -- Build allowed models lookup
        local allowedModels = {
            [FREEMODE_MALE]   = true,
            [FREEMODE_FEMALE] = true,
        }
        for _, model in ipairs(cfg.ped_flags.allowed_models or {}) do
            -- Support both hash numbers and string names
            if type(model) == 'number' then
                allowedModels[model] = true
            elseif type(model) == 'string' then
                allowedModels[GetHashKey(model)] = true
            end
        end

        local lastModel = nil
        local interval = cfg.ped_flags.check_interval or 5000

        while true do
            Wait(interval)

            local ped = PlayerPedId()
            if not DoesEntityExist(ped) then goto continue end

            local model = GetEntityModel(ped)

            if lastModel and model ~= lastModel then
                if not allowedModels[model] then
                    TriggerServerEvent('hydra:anticheat:report:ped_flags', {
                        modelChange = true,
                        oldModel = lastModel,
                        newModel = model,
                    })
                end
            end

            lastModel = model

            ::continue::
        end
    end)
end

-- =========================================================================
-- 8. PICKUP DISTANCE VALIDATION
-- =========================================================================

if cfg.pickups and cfg.pickups.enabled then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(6000) -- staggered start

        -- Track nearby pickups and report distance when collected
        -- We poll for pickups near the player and detect when they vanish
        local trackedPickups = {}
        local interval = 500

        while true do
            Wait(interval)

            local ped = PlayerPedId()
            if not DoesEntityExist(ped) then goto continue end

            local playerPos = GetEntityCoords(ped)

            -- Scan pickup pool
            local pickups = GetGamePool('CPickup')
            local currentPickups = {}

            for i = 1, #pickups do
                local pickup = pickups[i]
                if DoesEntityExist(pickup) then
                    currentPickups[pickup] = true
                    if not trackedPickups[pickup] then
                        trackedPickups[pickup] = GetEntityCoords(pickup)
                    end
                end
            end

            -- Check for pickups that disappeared (collected)
            for pickup, pickupPos in pairs(trackedPickups) do
                if not currentPickups[pickup] then
                    -- Pickup was removed — likely collected
                    local distance = #(playerPos - pickupPos)
                    TriggerServerEvent('hydra:anticheat:report:pickup', {
                        distance = distance,
                        pickupType = GetPickupHash(pickup) or 0,
                    })
                    trackedPickups[pickup] = nil
                end
            end

            -- Clean up stale entries
            for pickup, _ in pairs(trackedPickups) do
                if not currentPickups[pickup] then
                    trackedPickups[pickup] = nil
                end
            end

            ::continue::
        end
    end)
end
