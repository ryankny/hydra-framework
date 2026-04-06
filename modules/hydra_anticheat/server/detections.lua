--[[
    Hydra AntiCheat - Server Detections

    Server-authoritative detection modules:
    - Movement / teleport / noclip validation
    - God mode detection
    - Weapon validation
    - Entity spawn protection
    - Explosion filtering
    - Resource integrity
    - Ped flag anomalies
]]

local cfg = HydraConfig.AntiCheat
local Flag = Hydra.AntiCheat.Flag
local GetPlayer = Hydra.AntiCheat.GetPlayer
local GetPlayerState = Hydra.AntiCheat.GetPlayerState
local SetPlayerState = Hydra.AntiCheat.SetPlayerState
local IsModuleEnabled = Hydra.AntiCheat.IsModuleEnabled

local os_clock = os.clock
local math_sqrt = math.sqrt
local GetEntityCoords = GetEntityCoords
local GetPlayerPed = GetPlayerPed
local GetEntityHealth = GetEntityHealth
local GetPedArmour = GetPedArmour
local IsPlayerAceAllowed = IsPlayerAceAllowed
local GetPlayerName = GetPlayerName

-- =========================================================================
-- MOVEMENT / TELEPORT / NOCLIP DETECTION
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:position', function(pos, isInVehicle, isOnGround, vehicleSpeed)
    local src = source
    if not IsModuleEnabled('movement') then return end

    local p = GetPlayer(src)
    if not p then return end
    local state = p.state

    local now = os_clock()
    local mcfg = cfg.movement

    -- Grace period after spawn/respawn
    if (now - (state.spawnTime or 0)) < (mcfg.spawn_grace_period / 1000) then
        state.lastPos = pos
        state.lastPosTime = now
        return
    end

    if state.lastPos and state.lastPosTime > 0 then
        local dx = pos.x - state.lastPos.x
        local dy = pos.y - state.lastPos.y
        local dz = pos.z - state.lastPos.z
        local dist = math_sqrt(dx * dx + dy * dy + dz * dz)
        local dt = now - state.lastPosTime

        if dt > 0.1 then   -- Avoid division by near-zero
            local speed = dist / dt

            -- Teleport detection (distance-based)
            if dist > mcfg.teleport_threshold then
                Flag(src, 'movement', string.format('Teleport detected: %.1fm in %.1fs', dist, dt),
                    mcfg.teleport_severity or 4, mcfg.teleport_action, {
                        from = state.lastPos, to = pos, distance = dist, delta = dt
                    })
                state.lastPos = pos
                state.lastPosTime = now
                return
            end

            -- Speed hack detection
            local maxSpeed = isInVehicle and mcfg.max_vehicle_speed or mcfg.max_foot_speed
            if speed > maxSpeed then
                -- Allow some tolerance for lag spikes — require 2 consecutive flags
                state.speedViolations = (state.speedViolations or 0) + 1
                if state.speedViolations >= 3 then
                    Flag(src, 'movement', string.format('Speed hack: %.1f m/s (max %.1f)', speed, maxSpeed),
                        mcfg.speed_severity or 3, mcfg.speed_action, {
                            speed = speed, maxSpeed = maxSpeed, inVehicle = isInVehicle
                        })
                    state.speedViolations = 0
                end
            else
                state.speedViolations = 0
            end

            -- Noclip detection: moving through air without falling
            if not isOnGround and not isInVehicle and speed > 2.0 then
                state.noclipFrames = (state.noclipFrames or 0) + 1
                if state.noclipFrames >= mcfg.noclip_threshold then
                    Flag(src, 'movement', string.format('Noclip detected: %d airborne frames, speed %.1f', state.noclipFrames, speed),
                        mcfg.noclip_severity or 5, mcfg.noclip_action, {
                            frames = state.noclipFrames, speed = speed
                        })
                    state.noclipFrames = 0
                end
            else
                state.noclipFrames = 0
            end
        end
    end

    state.lastPos = pos
    state.lastPosTime = now
end)

-- Spawn/respawn grace period reset
RegisterNetEvent('hydra:anticheat:report:spawn', function()
    local src = source
    local state = GetPlayerState(src)
    if state then
        state.spawnTime = os_clock()
        state.lastPos = nil
        state.lastPosTime = 0
        state.speedViolations = 0
        state.noclipFrames = 0
    end
end)

-- =========================================================================
-- GOD MODE DETECTION
-- =========================================================================

CreateThread(function()
    if not cfg.godmode or not cfg.godmode.enabled then return end

    while true do
        Wait(cfg.godmode.check_interval)
        if not IsModuleEnabled('godmode') then goto continue end

        for src, p in pairs(Hydra.AntiCheat.GetAllPlayers()) do
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local health = GetEntityHealth(ped)
                local armour = GetPedArmour(ped)
                local state = p.state

                -- Check for health above maximum
                if health > cfg.godmode.max_health then
                    Flag(src, 'godmode', string.format('Health exceeds max: %d/%d', health, cfg.godmode.max_health),
                        cfg.godmode.severity or 4, cfg.godmode.action, { health = health })
                end

                -- Check for armour above maximum
                if armour > cfg.godmode.max_armour then
                    Flag(src, 'godmode', string.format('Armour exceeds max: %d/%d', armour, cfg.godmode.max_armour),
                        cfg.godmode.severity or 4, cfg.godmode.action, { armour = armour })
                end

                -- Track damage taken vs health changes
                -- If player reported taking damage but health stayed the same
                if state.damageTaken > 0 and health >= (state.health or 0) then
                    state.damageIgnored = (state.damageIgnored or 0) + 1
                    if state.damageIgnored >= cfg.godmode.tolerance then
                        Flag(src, 'godmode', string.format('God mode suspected: %d damage events ignored', state.damageIgnored),
                            cfg.godmode.severity or 4, cfg.godmode.action, {
                                damageIgnored = state.damageIgnored, health = health
                            })
                        state.damageIgnored = 0
                    end
                else
                    state.damageIgnored = 0
                end

                state.health = health
                state.armour = armour
                state.damageTaken = 0
            end
        end

        ::continue::
    end
end)

-- Client reports damage taken (we track it server-side)
RegisterNetEvent('hydra:anticheat:report:damage', function(amount)
    local src = source
    local state = GetPlayerState(src)
    if state then
        state.damageTaken = (state.damageTaken or 0) + (amount or 1)
    end
end)

-- =========================================================================
-- WEAPON VALIDATION
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:weapon', function(weaponHash, ammo)
    local src = source
    if not IsModuleEnabled('weapons') then return end

    local wcfg = cfg.weapons

    -- Blacklisted weapons
    for _, hash in ipairs(wcfg.blacklist) do
        if weaponHash == hash then
            Flag(src, 'weapons', string.format('Blacklisted weapon: 0x%X', weaponHash),
                wcfg.blacklist_severity or 5, wcfg.blacklist_action, { weapon = weaponHash })
            return
        end
    end
end)

-- Weapon fire rate tracking
RegisterNetEvent('hydra:anticheat:report:fire', function(weaponHash, timestamp)
    local src = source
    if not IsModuleEnabled('weapons') then return end

    local state = GetPlayerState(src)
    if not state then return end

    state.weaponFired = state.weaponFired or {}
    local wf = state.weaponFired[weaponHash]

    if wf then
        local dt = timestamp - wf.lastTime
        if dt > 0 then
            wf.count = wf.count + 1
            -- Check after accumulating enough samples
            if wf.count >= 10 then
                local avgInterval = (timestamp - wf.startTime) / wf.count
                -- Very rapid fire detection (interval < expected / tolerance)
                if avgInterval < 30 then    -- Unrealistically fast for any weapon (~33 shots/sec)
                    Flag(src, 'weapons', string.format('Rapid fire: %.0fms avg interval, weapon 0x%X', avgInterval, weaponHash),
                        cfg.weapons.rapid_fire_severity or 3, cfg.weapons.rapid_fire_action, {
                            weapon = weaponHash, interval = avgInterval, count = wf.count
                        })
                end
                -- Reset window
                wf.count = 0
                wf.startTime = timestamp
            end
        end
        wf.lastTime = timestamp
    else
        state.weaponFired[weaponHash] = {
            lastTime = timestamp,
            startTime = timestamp,
            count = 0,
        }
    end
end)

-- =========================================================================
-- ENTITY / OBJECT SPAWN PROTECTION
-- =========================================================================

local entityOwnership = {}  -- [src] = { peds = n, vehicles = n, objects = n }

RegisterNetEvent('hydra:anticheat:report:entities', function(counts)
    local src = source
    if not IsModuleEnabled('entities') then return end

    local ecfg = cfg.entities
    if type(counts) ~= 'table' then
        Flag(src, 'entities', 'Invalid entity report payload', 3, 'kick')
        return
    end

    local peds = counts.peds or 0
    local vehicles = counts.vehicles or 0
    local objects = counts.objects or 0
    local total = peds + vehicles + objects

    entityOwnership[src] = counts

    if total > ecfg.max_per_player then
        Flag(src, 'entities', string.format('Excessive entities: %d total (max %d)', total, ecfg.max_per_player),
            ecfg.excess_severity or 3, ecfg.excess_action, counts)
    end

    if peds > ecfg.max_peds then
        Flag(src, 'entities', string.format('Excessive peds: %d (max %d)', peds, ecfg.max_peds),
            ecfg.excess_severity or 3, ecfg.excess_action, counts)
    end

    if vehicles > ecfg.max_vehicles then
        Flag(src, 'entities', string.format('Excessive vehicles: %d (max %d)', vehicles, ecfg.max_vehicles),
            ecfg.excess_severity or 3, ecfg.excess_action, counts)
    end
end)

-- Blacklisted model check
RegisterNetEvent('hydra:anticheat:report:model_spawn', function(model)
    local src = source
    if not IsModuleEnabled('entities') then return end

    for _, blocked in ipairs(cfg.entities.blacklisted_models) do
        if model == blocked or GetHashKey(blocked) == model then
            Flag(src, 'entities', string.format('Blacklisted model spawned: %s', model),
                cfg.entities.blacklist_severity or 5, cfg.entities.blacklist_action, { model = model })
            return
        end
    end
end)

-- Cleanup on drop
AddEventHandler('playerDropped', function()
    entityOwnership[source] = nil
end)

-- =========================================================================
-- EXPLOSION FILTERING
-- =========================================================================

if cfg.explosions and cfg.explosions.enabled then
    local explosionCounts = {}   -- [src] = { count, resetTime }

    AddEventHandler('explosionEvent', function(src, ev)
        if not IsModuleEnabled('explosions') then return end
        if src <= 0 then return end     -- Server-caused explosions

        local ecfg = cfg.explosions

        -- Blocked explosion types
        for _, blocked in ipairs(ecfg.blocked_types) do
            if ev.explosionType == blocked then
                Flag(src, 'explosions', string.format('Blocked explosion type: %d', ev.explosionType),
                    ecfg.blocked_severity or 5, ecfg.blocked_action, { type = ev.explosionType })
                CancelEvent()
                return
            end
        end

        -- Rate limit
        local now = os.time()
        if not explosionCounts[src] or now > explosionCounts[src].resetTime then
            explosionCounts[src] = { count = 0, resetTime = now + 60 }
        end
        explosionCounts[src].count = explosionCounts[src].count + 1

        if explosionCounts[src].count > ecfg.max_per_minute then
            Flag(src, 'explosions', string.format('Explosion flood: %d/min (max %d)', explosionCounts[src].count, ecfg.max_per_minute),
                ecfg.flood_severity or 4, ecfg.flood_action, { count = explosionCounts[src].count })
            CancelEvent()
        end
    end)
end

-- =========================================================================
-- RESOURCE INTEGRITY
-- =========================================================================

CreateThread(function()
    if not cfg.resources or not cfg.resources.enabled then return end

    -- Build list of expected resources at startup
    local expectedResources = {}
    local numResources = GetNumResources()
    for i = 0, numResources - 1 do
        local name = GetResourceByFindIndex(i)
        if name then expectedResources[name] = true end
    end

    -- Monitor for new resources being started that weren't in the original list
    if cfg.resources.detect_injection then
        AddEventHandler('onResourceStart', function(resource)
            if not expectedResources[resource] then
                -- New resource injected at runtime
                local src = source
                -- This is a server event, log it as system-level
                Hydra.AntiCheat.Flag(0, 'resources',
                    string.format('Unexpected resource started: %s', resource),
                    cfg.resources.injection_severity or 5, 'log', { resource = resource })
                -- Add to expected so we don't keep flagging on restart
                expectedResources[resource] = true
            end
        end)
    end

    -- Periodic check that required resources are still running
    while true do
        Wait(cfg.resources.check_interval)
        if not IsModuleEnabled('resources') then goto continue end

        for _, required in ipairs(cfg.resources.required) do
            if GetResourceState(required) ~= 'started' then
                Hydra.AntiCheat.Flag(0, 'resources',
                    string.format('Required resource not running: %s', required),
                    4, 'log', { resource = required })
            end
        end

        ::continue::
    end
end)

-- =========================================================================
-- SPECTATE / FREECAM DETECTION
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:camera', function(camPos, pedPos)
    local src = source
    if not IsModuleEnabled('spectate') then return end

    if type(camPos) ~= 'vector3' and type(camPos) ~= 'table' then return end
    if type(pedPos) ~= 'vector3' and type(pedPos) ~= 'table' then return end

    local dx = (camPos.x or 0) - (pedPos.x or 0)
    local dy = (camPos.y or 0) - (pedPos.y or 0)
    local dz = (camPos.z or 0) - (pedPos.z or 0)
    local dist = math_sqrt(dx * dx + dy * dy + dz * dz)

    if dist > cfg.spectate.max_camera_distance then
        Flag(src, 'spectate', string.format('Camera %.0fm from ped (max %.0f)', dist, cfg.spectate.max_camera_distance),
            cfg.spectate.severity or 3, cfg.spectate.action, {
                cameraPos = camPos, pedPos = pedPos, distance = dist
            })
    end
end)

-- =========================================================================
-- PED FLAG ANOMALIES (server requests client to report)
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:ped_flags', function(flags)
    local src = source
    if not IsModuleEnabled('ped_flags') then return end

    if type(flags) ~= 'table' then
        Flag(src, 'ped_flags', 'Invalid ped flag report', 3, 'kick')
        return
    end

    local pfcfg = cfg.ped_flags

    if pfcfg.super_jump and flags.superJump then
        Flag(src, 'ped_flags', 'Super jump detected',
            pfcfg.severity or 3, pfcfg.action, flags)
    end

    if pfcfg.infinite_stamina and flags.infiniteStamina then
        Flag(src, 'ped_flags', 'Infinite stamina detected',
            pfcfg.severity or 3, pfcfg.action, flags)
    end

    if flags.invisible then
        Flag(src, 'ped_flags', 'Player ped invisible',
            pfcfg.severity or 3, pfcfg.action, flags)
    end

    if flags.noRagdoll then
        Flag(src, 'ped_flags', 'Ragdoll disabled (potential mod)',
            2, 'log', flags)
    end
end)
