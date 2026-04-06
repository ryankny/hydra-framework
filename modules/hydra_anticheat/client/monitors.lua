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
local NetworkGetEntityOwner = NetworkGetEntityOwner
local Wait = Wait

-- =========================================================================
-- POSITION REPORTING THREAD
-- =========================================================================

if cfg.movement and cfg.movement.enabled then
    CreateThread(function()
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

                -- Extended data for server validation
                local isSwimming = IsPedSwimming(ped)
                local isSwimmingUnderWater = IsPedSwimmingUnderWater(ped)
                local speed = GetEntitySpeed(ped)

                TriggerServerEvent('hydra:anticheat:report:position', pos, inVehicle, onGround, vehSpeed, {
                    swimming = isSwimming,
                    underwater = isSwimmingUnderWater,
                    pedSpeed = speed,
                })
            end
        end
    end)

    -- Bounds / underground check (less frequent)
    if cfg.movement.bounds_check or cfg.movement.underground_check then
        CreateThread(function()
            while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
            Wait(15000)

            while true do
                Wait(5000)

                local ped = PlayerPedId()
                if not DoesEntityExist(ped) then goto continue end

                local pos = GetEntityCoords(ped)

                -- Bounds check
                if cfg.movement.bounds_check then
                    local min = cfg.movement.map_min
                    local max = cfg.movement.map_max
                    if pos.x < min.x or pos.y < min.y or pos.z < min.z or
                       pos.x > max.x or pos.y > max.y or pos.z > max.z then
                        TriggerServerEvent('hydra:anticheat:report:bounds', pos)
                    end
                end

                -- Underground check
                if cfg.movement.underground_check then
                    local retval, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)
                    if retval and pos.z < (groundZ + cfg.movement.underground_tolerance) then
                        -- Could be in an interior/underground area — additional check
                        local interior = GetInteriorFromEntity(ped)
                        if interior == 0 then   -- Not in an interior
                            TriggerServerEvent('hydra:anticheat:report:underground', pos, groundZ)
                        end
                    end
                end

                ::continue::
            end
        end)
    end
end

-- =========================================================================
-- WEAPON MONITORING THREAD
-- =========================================================================

if cfg.weapons and cfg.weapons.enabled then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(5000)

        local lastWeapon = 0

        while true do
            Wait(5000)

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

    -- Rapid-fire detection
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(5000)

        while true do
            local ped = PlayerPedId()
            local weapon = GetSelectedPedWeapon(ped)

            if weapon ~= `WEAPON_UNARMED` and DoesEntityExist(ped) then
                Wait(100)
                if IsPedShooting(ped) then
                    TriggerServerEvent('hydra:anticheat:report:fire', weapon, GetGameTimer())
                end
            else
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
        local lastArmour = 0
        local lastRegenCheck = GetGameTimer()

        while true do
            Wait(500)

            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                local health = GetEntityHealth(ped)
                local armour = GetPedArmour(ped)
                local now = GetGameTimer()

                -- Damage taken
                if health < lastHealth and lastHealth > 0 then
                    local damage = lastHealth - health
                    if damage > 0 then
                        TriggerServerEvent('hydra:anticheat:report:damage', damage)
                    end
                end

                -- Health regeneration tracking (detect impossibly fast regen)
                if health > lastHealth and lastHealth > 0 and cfg.godmode.max_regen_per_second then
                    local dt = (now - lastRegenCheck) / 1000
                    if dt > 0 then
                        local regenRate = (health - lastHealth) / dt
                        if regenRate > cfg.godmode.max_regen_per_second then
                            TriggerServerEvent('hydra:anticheat:report:regen', {
                                rate = regenRate,
                                from = lastHealth,
                                to = health,
                                dt = dt,
                            })
                        end
                    end
                end

                -- Invincibility check
                if cfg.godmode.invincible_check then
                    if GetPlayerInvincible(PlayerId()) then
                        TriggerServerEvent('hydra:anticheat:report:ped_flags', {
                            invincible = true,
                            anomaly = 'player_invincible'
                        })
                    end
                end

                lastHealth = health
                lastArmour = armour
                lastRegenCheck = now

                -- Reset on respawn
                if health >= 200 and lastHealth < 100 then
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

        local interval = 15000
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

    -- Attached object detection
    if cfg.entities.detect_attached_objects then
        CreateThread(function()
            while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
            Wait(20000)

            while true do
                Wait(10000)

                local ped = PlayerPedId()
                if not DoesEntityExist(ped) then goto continue end

                -- Check for suspicious objects attached to our ped
                local allObjs = GetGamePool('CObject')
                local attachedCount = 0
                for i = 1, #allObjs do
                    local obj = allObjs[i]
                    if IsEntityAttachedToEntity(obj, ped) then
                        attachedCount = attachedCount + 1
                    end
                end

                -- If excessive attached objects, someone may be griefing us
                if attachedCount > 5 then
                    TriggerServerEvent('hydra:anticheat:report:attached', {
                        count = attachedCount,
                    })
                end

                ::continue::
            end
        end)
    end
end

-- =========================================================================
-- SPECTATE / FREECAM DETECTION THREAD
-- =========================================================================

if cfg.spectate and cfg.spectate.enabled then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(5000)

        local interval = cfg.spectate.check_interval or 5000
        local consecutiveFlags = 0

        while true do
            Wait(interval)

            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                local camPos = GetFinalRenderedCamCoord()
                local pedPos = GetEntityCoords(ped)

                -- Only report if camera is suspiciously far
                local dx = camPos.x - pedPos.x
                local dy = camPos.y - pedPos.y
                local dz = camPos.z - pedPos.z
                local distSq = dx*dx + dy*dy + dz*dz
                local maxDist = cfg.spectate.max_camera_distance or 200.0

                if distSq > maxDist * maxDist then
                    consecutiveFlags = consecutiveFlags + 1
                    if consecutiveFlags >= (cfg.spectate.consecutive or 3) then
                        TriggerServerEvent('hydra:anticheat:report:camera', camPos, pedPos)
                        consecutiveFlags = 0
                    end
                else
                    consecutiveFlags = 0
                end
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
        Wait(15000)

        local knownResources = {}
        local numResources = GetNumResources()
        for i = 0, numResources - 1 do
            local name = GetResourceByFindIndex(i)
            if name then knownResources[name] = true end
        end

        local interval = cfg.resources.check_interval or 30000

        -- Also detect resource stops mid-session
        if cfg.resources.detect_stop then
            AddEventHandler('onResourceStop', function(resource)
                -- Don't flag hydra_anticheat itself stopping (during restart)
                if resource == 'hydra_anticheat' then return end
                -- Report to server
                TriggerServerEvent('hydra:anticheat:report:resource_stop', resource)
            end)
        end

        while true do
            Wait(interval)

            local currentNum = GetNumResources()
            for i = 0, currentNum - 1 do
                local name = GetResourceByFindIndex(i)
                if name and not knownResources[name] then
                    TriggerServerEvent('hydra:anticheat:report:menu', {
                        type = 'injected_resource',
                        name = name,
                    })
                    knownResources[name] = true
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

        -- Impossible wanted level
        local wantedLevel = GetPlayerWantedLevel(PlayerId())
        if wantedLevel > 5 then
            TriggerServerEvent('hydra:anticheat:report:ped_flags', {
                wantedLevel = wantedLevel,
                anomaly = 'impossible_wanted_level'
            })
        end

        -- Non-freemode model check
        local model = GetEntityModel(ped)
        local isFreemode = model == `mp_m_freemode_01` or model == `mp_f_freemode_01`
        if not isFreemode and cfg.debug then
            print('[AC] Non-freemode model: ' .. model)
        end

        ::continue::
    end
end)
