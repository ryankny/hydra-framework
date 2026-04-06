--[[
    Hydra AntiCheat - Client Monitors

    Lightweight client-side monitoring threads that report state to the server.
    Designed for minimal frame impact: staggered intervals, fast-path exits,
    no heavy computation in render loops.
]]

local cfg = HydraConfig.AntiCheat

-- ---------------------------------------------------------------------------
-- Localise for performance
-- ---------------------------------------------------------------------------
local GetGameTimer = GetGameTimer
local PlayerPedId = PlayerPedId
local PlayerId = PlayerId
local GetEntityCoords = GetEntityCoords
local DoesEntityExist = DoesEntityExist
local IsPedInAnyVehicle = IsPedInAnyVehicle
local IsPedShooting = IsPedShooting
local GetSelectedPedWeapon = GetSelectedPedWeapon
local GetEntityHealth = GetEntityHealth
local IsEntityInAir = IsEntityInAir
local IsPedFalling = IsPedFalling
local GetEntitySpeed = GetEntitySpeed
local GetFinalRenderedCamCoord = GetFinalRenderedCamCoord
local NetworkIsPlayerActive = NetworkIsPlayerActive
local GetVehiclePedIsIn = GetVehiclePedIsIn
local GetPedConfigFlag = GetPedConfigFlag
local IsEntityVisible = IsEntityVisible
local TriggerServerEvent = TriggerServerEvent
local Wait = Wait

-- =========================================================================
-- POSITION REPORTING THREAD
-- =========================================================================

if cfg.movement and cfg.movement.enabled then
    CreateThread(function()
        -- Wait for client to be ready
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(cfg.movement.spawn_grace_period or 10000)

        local interval = cfg.movement.report_interval or 2000

        while true do
            Wait(interval)

            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                local pos = GetEntityCoords(ped)
                local inVehicle = IsPedInAnyVehicle(ped, false)
                local onGround = not IsEntityInAir(ped) and not IsPedFalling(ped)
                local vehSpeed = 0.0

                if inVehicle then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if veh and veh ~= 0 then
                        vehSpeed = GetEntitySpeed(veh)
                    end
                end

                TriggerServerEvent('hydra:anticheat:report:position', pos, inVehicle, onGround, vehSpeed)
            end
        end
    end)
end

-- =========================================================================
-- WEAPON MONITORING THREAD
-- =========================================================================

if cfg.weapons and cfg.weapons.enabled then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(5000)

        local lastWeapon = 0
        local reportInterval = 5000     -- Report current weapon every 5s

        while true do
            Wait(reportInterval)

            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                local weapon = GetSelectedPedWeapon(ped)
                if weapon ~= `WEAPON_UNARMED` and weapon ~= lastWeapon then
                    TriggerServerEvent('hydra:anticheat:report:weapon', weapon, 0)
                    lastWeapon = weapon
                end
            end
        end
    end)

    -- Rapid-fire detection: runs at a faster interval but only when weapon is out
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(5000)

        while true do
            local ped = PlayerPedId()
            local weapon = GetSelectedPedWeapon(ped)

            if weapon ~= `WEAPON_UNARMED` and DoesEntityExist(ped) then
                -- Active weapon — check at 100ms intervals
                Wait(100)
                if IsPedShooting(ped) then
                    TriggerServerEvent('hydra:anticheat:report:fire', weapon, GetGameTimer())
                end
            else
                -- No weapon — sleep longer
                Wait(1000)
            end
        end
    end)
end

-- =========================================================================
-- DAMAGE TRACKING THREAD
-- =========================================================================

if cfg.godmode and cfg.godmode.enabled then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(3000)

        local lastHealth = 200
        local interval = 500    -- Check health every 500ms

        while true do
            Wait(interval)

            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                local health = GetEntityHealth(ped)
                if health < lastHealth and lastHealth > 0 then
                    local damage = lastHealth - health
                    if damage > 0 then
                        TriggerServerEvent('hydra:anticheat:report:damage', damage)
                    end
                end
                lastHealth = health

                -- Reset on respawn
                if health >= 200 and lastHealth < 200 then
                    lastHealth = health
                end
            end
        end
    end)
end

-- =========================================================================
-- ENTITY COUNT REPORTING THREAD
-- =========================================================================

if cfg.entities and cfg.entities.enabled then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(10000)

        local interval = 15000      -- Every 15 seconds
        local playerId = PlayerId()

        while true do
            Wait(interval)

            local ped = PlayerPedId()
            local peds = 0
            local vehicles = 0
            local objects = 0

            local allPeds = GetGamePool('CPed')
            for i = 1, #allPeds do
                if allPeds[i] ~= ped and NetworkGetEntityOwner(allPeds[i]) == playerId then
                    peds = peds + 1
                end
            end

            local allVehs = GetGamePool('CVehicle')
            for i = 1, #allVehs do
                if NetworkGetEntityOwner(allVehs[i]) == playerId then
                    vehicles = vehicles + 1
                end
            end

            local allObjs = GetGamePool('CObject')
            for i = 1, #allObjs do
                if NetworkGetEntityOwner(allObjs[i]) == playerId then
                    objects = objects + 1
                end
            end

            TriggerServerEvent('hydra:anticheat:report:entities', {
                peds = peds,
                vehicles = vehicles,
                objects = objects,
            })
        end
    end)
end

-- =========================================================================
-- SPECTATE / FREECAM DETECTION THREAD
-- =========================================================================

if cfg.spectate and cfg.spectate.enabled then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(5000)

        local interval = 10000      -- Every 10 seconds

        while true do
            Wait(interval)

            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                local camPos = GetFinalRenderedCamCoord()
                local pedPos = GetEntityCoords(ped)
                TriggerServerEvent('hydra:anticheat:report:camera', camPos, pedPos)
            end
        end
    end)
end

-- =========================================================================
-- PED FLAG MONITORING THREAD
-- =========================================================================

if cfg.ped_flags and cfg.ped_flags.enabled then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(8000)

        local interval = cfg.ped_flags.check_interval or 5000

        while true do
            Wait(interval)

            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                local flags = {
                    superJump = GetPedConfigFlag(ped, 14, true),
                    invisible = not IsEntityVisible(ped),
                    noRagdoll = GetPedConfigFlag(ped, 166, true),
                    infiniteStamina = GetPedConfigFlag(ped, 7, true),
                }

                -- Only report if something anomalous is detected
                if flags.superJump or flags.invisible or flags.noRagdoll or flags.infiniteStamina then
                    TriggerServerEvent('hydra:anticheat:report:ped_flags', flags)
                end
            end
        end
    end)
end

-- =========================================================================
-- RESOURCE INJECTION DETECTION (client-side)
-- =========================================================================

if cfg.resources and cfg.resources.enabled and cfg.resources.detect_injection then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(15000)     -- Wait for all resources to load

        -- Snapshot known resources at startup
        local knownResources = {}
        local numResources = GetNumResources()
        for i = 0, numResources - 1 do
            local name = GetResourceByFindIndex(i)
            if name then knownResources[name] = true end
        end

        local interval = cfg.resources.check_interval or 30000

        while true do
            Wait(interval)

            local currentNum = GetNumResources()
            for i = 0, currentNum - 1 do
                local name = GetResourceByFindIndex(i)
                if name and not knownResources[name] then
                    -- New resource appeared that wasn't there at startup
                    -- Report to server (server decides action)
                    TriggerServerEvent('hydra:anticheat:report:model_spawn', 'injected_resource:' .. name)
                    knownResources[name] = true     -- Don't re-report
                end
            end
        end
    end)
end

-- =========================================================================
-- ANTI-TAMPER: Detect common menu modifications
-- =========================================================================

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(20000)

    while true do
        Wait(10000)

        local ped = PlayerPedId()
        if not DoesEntityExist(ped) then goto continue end

        -- Check for impossible states that indicate memory modification

        -- 1. Player ped should not have certain flags set by menus
        -- CPlayerInfo modifications (extremely high wanted level, etc.)
        local wantedLevel = GetPlayerWantedLevel(PlayerId())
        if wantedLevel > 5 then
            TriggerServerEvent('hydra:anticheat:report:ped_flags', {
                wantedLevel = wantedLevel,
                anomaly = 'impossible_wanted_level'
            })
        end

        -- 2. Check for ped model changes to non-player models (common troll hack)
        local model = GetEntityModel(ped)
        -- Players should typically be mp_m_freemode_01 or mp_f_freemode_01
        -- We don't enforce this strictly but flag unusual models
        local isFreemode = model == `mp_m_freemode_01` or model == `mp_f_freemode_01`
        if not isFreemode then
            -- Could be legitimate (admin morphing, identity system, etc.)
            -- Just log it, don't flag
            if cfg.debug then
                print('[AC] Non-freemode model detected: ' .. model)
            end
        end

        -- 3. Check for frozen position while moving (potential desync exploit)
        -- This is a subtle check: if the player's velocity is non-zero but
        -- position doesn't change, it could indicate a desync exploit
        -- (handled more accurately by the server via position reports)

        ::continue::
    end
end)

-- =========================================================================
-- PARTICLE EFFECT MONITORING
-- =========================================================================

if cfg.particles and cfg.particles.enabled then
    -- Override StartParticleFxLoopedAtCoord etc. is not possible in FiveM,
    -- but we can monitor for excessive network particle events
    -- The server tracks this via events — client just needs to report
    -- when it creates particles that it owns

    -- This is handled by hooking into hydra_object / other modules
    -- that create particle effects, via the server event system
end

-- =========================================================================
-- SCREEN CAPTURE ON REQUEST
-- =========================================================================

RegisterNetEvent('hydra:anticheat:screenshot', function()
    -- If screenshot-basic or similar is available
    pcall(function()
        exports['screenshot-basic']:requestScreenshot(function(data)
            TriggerServerEvent('hydra:anticheat:screenshot:result', data)
        end)
    end)
end)
