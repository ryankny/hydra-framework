--[[
    Hydra AntiCheat - Server Detections

    Server-authoritative detection modules:
    - Movement / teleport / noclip / vehicle fly / bounds / underground
    - God mode (player + vehicle) with regen tracking
    - Weapon validation (blacklist, rapid fire)
    - Entity spawn protection with rate limiting
    - Explosion filtering with distance checks
    - Resource integrity
    - Ped flag anomalies with expanded checks
    - Teleport whitelist integration
]]

local cfg = HydraConfig.AntiCheat
local Flag = Hydra.AntiCheat.Flag
local GetPlayer = Hydra.AntiCheat.GetPlayer
local GetPlayerState = Hydra.AntiCheat.GetPlayerState
local SetPlayerState = Hydra.AntiCheat.SetPlayerState
local IsModuleEnabled = Hydra.AntiCheat.IsModuleEnabled

local os_clock = os.clock
local os_time = os.time
local math_sqrt = math.sqrt
local string_format = string.format
local GetEntityCoords = GetEntityCoords
local GetPlayerPed = GetPlayerPed
local GetEntityHealth = GetEntityHealth
local GetPedArmour = GetPedArmour
local IsPlayerAceAllowed = IsPlayerAceAllowed
local GetPlayerName = GetPlayerName

-- =========================================================================
-- TELEPORT WHITELIST HELPERS
-- =========================================================================

-- Check if a player's teleport is whitelisted (set by main.lua)
local function isTeleportWhitelisted(state)
    if not state or not state.teleportWhitelisted then return false end
    local grace = (cfg.teleport_whitelist and cfg.teleport_whitelist.grace_period or 5000) / 1000
    return (os_clock() - state.teleportWhitelisted) < grace
end

-- =========================================================================
-- MOVEMENT / TELEPORT / NOCLIP / VEHICLE FLY / BOUNDS DETECTION
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:position', function(pos, isInVehicle, isOnGround, vehicleSpeed, extra)
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

    -- Skip if teleport is whitelisted
    if isTeleportWhitelisted(state) then
        state.lastPos = pos
        state.lastPosTime = now
        state.speedViolations = 0
        state.noclipFrames = 0
        return
    end

    if state.lastPos and state.lastPosTime > 0 then
        local dx = pos.x - state.lastPos.x
        local dy = pos.y - state.lastPos.y
        local dz = pos.z - state.lastPos.z
        local dist = math_sqrt(dx * dx + dy * dy + dz * dz)
        local dt = now - state.lastPosTime

        if dt > 0.1 then
            local speed = dist / dt

            -- Teleport detection
            if dist > mcfg.teleport_threshold then
                state.teleportViolations = (state.teleportViolations or 0) + 1
                if state.teleportViolations >= (mcfg.teleport_consecutive or 1) then
                    Flag(src, 'movement', string_format('Teleport: %.1fm in %.1fs', dist, dt),
                        mcfg.teleport_severity or 4, mcfg.teleport_action, {
                            from = state.lastPos, to = pos, distance = dist, delta = dt
                        })
                    state.teleportViolations = 0
                end
                state.lastPos = pos
                state.lastPosTime = now
                return
            else
                state.teleportViolations = 0
            end

            -- Speed hack detection
            local maxSpeed = mcfg.max_foot_speed
            if isInVehicle then
                maxSpeed = mcfg.max_vehicle_speed
            elseif extra and extra.swimming then
                maxSpeed = mcfg.max_swim_speed or 5.0
            end

            if speed > maxSpeed then
                state.speedViolations = (state.speedViolations or 0) + 1
                if state.speedViolations >= (mcfg.speed_consecutive or 3) then
                    Flag(src, 'movement', string_format('Speed hack: %.1f m/s (max %.1f)%s', speed, maxSpeed,
                        isInVehicle and ' [vehicle]' or (extra and extra.swimming and ' [swimming]' or '')),
                        mcfg.speed_severity or 3, mcfg.speed_action, {
                            speed = speed, maxSpeed = maxSpeed, inVehicle = isInVehicle
                        })
                    state.speedViolations = 0
                end
            else
                state.speedViolations = 0
            end

            -- Noclip detection: airborne + moving + not in vehicle
            if not isOnGround and not isInVehicle and speed > 2.0 then
                state.noclipFrames = (state.noclipFrames or 0) + 1
                if state.noclipFrames >= (mcfg.noclip_consecutive or mcfg.noclip_threshold) then
                    Flag(src, 'movement', string_format('Noclip: %d airborne frames, speed %.1f', state.noclipFrames, speed),
                        mcfg.noclip_severity or 5, mcfg.noclip_action, {
                            frames = state.noclipFrames, speed = speed
                        })
                    state.noclipFrames = 0
                end
            else
                state.noclipFrames = 0
            end

            -- Vehicle fly detection (in vehicle, airborne, moving horizontally)
            if mcfg.vehicle_fly and isInVehicle and not isOnGround and speed > 5.0 then
                state.vehicleFlyFrames = (state.vehicleFlyFrames or 0) + 1
                if state.vehicleFlyFrames >= (mcfg.vehicle_fly_threshold or 10) then
                    Flag(src, 'movement', string_format('Vehicle fly: %d airborne frames, speed %.1f', state.vehicleFlyFrames, speed),
                        mcfg.vehicle_fly_severity or 4, mcfg.vehicle_fly_action, {
                            frames = state.vehicleFlyFrames, speed = speed
                        })
                    state.vehicleFlyFrames = 0
                end
            else
                state.vehicleFlyFrames = 0
            end
        end
    end

    state.lastPos = pos
    state.lastPosTime = now
end)

-- Bounds violation (outside GTA map)
RegisterNetEvent('hydra:anticheat:report:bounds', function(pos)
    local src = source
    if not IsModuleEnabled('movement') then return end
    Flag(src, 'movement', string_format('Out of bounds: %.0f, %.0f, %.0f', pos.x, pos.y, pos.z),
        cfg.movement.bounds_severity or 5, cfg.movement.bounds_action or 'ban', { position = pos })
end)

-- Underground detection
RegisterNetEvent('hydra:anticheat:report:underground', function(pos, groundZ)
    local src = source
    if not IsModuleEnabled('movement') then return end
    local state = GetPlayerState(src)
    if state then
        state.undergroundViolations = (state.undergroundViolations or 0) + 1
        if state.undergroundViolations >= 3 then
            Flag(src, 'movement', string_format('Underground: z=%.1f, ground=%.1f', pos.z, groundZ),
                3, 'kick', { position = pos, groundZ = groundZ })
            state.undergroundViolations = 0
        end
    end
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
        state.vehicleFlyFrames = 0
        state.teleportViolations = 0
        state.undergroundViolations = 0
    end
end)

-- Teleport whitelist handler
RegisterNetEvent('hydra:anticheat:report:teleport_whitelist', function()
    local src = source
    local state = GetPlayerState(src)
    if state then
        state.teleportWhitelisted = os_clock()
        state.lastPos = nil
        state.lastPosTime = 0
        state.speedViolations = 0
    end
end)

-- =========================================================================
-- GOD MODE DETECTION (expanded)
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

                -- Health above maximum
                if health > cfg.godmode.max_health then
                    Flag(src, 'godmode', string_format('Health exceeds max: %d/%d', health, cfg.godmode.max_health),
                        cfg.godmode.severity or 4, cfg.godmode.action, { health = health })
                end

                -- Armour above maximum
                if armour > cfg.godmode.max_armour then
                    Flag(src, 'godmode', string_format('Armour exceeds max: %d/%d', armour, cfg.godmode.max_armour),
                        cfg.godmode.severity or 4, cfg.godmode.action, { armour = armour })
                end

                -- Damage absorption tracking
                if state.damageTaken > 0 and health >= (state.health or 0) then
                    state.damageIgnored = (state.damageIgnored or 0) + 1
                    if state.damageIgnored >= cfg.godmode.tolerance then
                        Flag(src, 'godmode', string_format('God mode: %d damage events ignored', state.damageIgnored),
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

-- Client reports damage taken
RegisterNetEvent('hydra:anticheat:report:damage', function(amount)
    local src = source
    local state = GetPlayerState(src)
    if state then
        state.damageTaken = (state.damageTaken or 0) + (amount or 1)
    end
end)

-- Health regeneration anomaly
RegisterNetEvent('hydra:anticheat:report:regen', function(data)
    local src = source
    if not IsModuleEnabled('godmode') then return end
    if type(data) ~= 'table' then return end

    local state = GetPlayerState(src)
    if not state then return end

    state.regenViolations = (state.regenViolations or 0) + 1
    if state.regenViolations >= 3 then
        Flag(src, 'godmode', string_format('Impossible health regen: %.1f HP/s', data.rate or 0),
            3, 'kick', data)
        state.regenViolations = 0
    end
end)

-- =========================================================================
-- WEAPON VALIDATION
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:weapon', function(weaponHash, ammo)
    local src = source
    if not IsModuleEnabled('weapons') then return end

    local wcfg = cfg.weapons

    for _, hash in ipairs(wcfg.blacklist) do
        if weaponHash == hash then
            Flag(src, 'weapons', string_format('Blacklisted weapon: 0x%X', weaponHash),
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
            if wf.count >= 10 then
                local avgInterval = (timestamp - wf.startTime) / wf.count
                if avgInterval < 30 then
                    Flag(src, 'weapons', string_format('Rapid fire: %.0fms interval, weapon 0x%X', avgInterval, weaponHash),
                        cfg.weapons.rapid_fire_severity or 3, cfg.weapons.rapid_fire_action, {
                            weapon = weaponHash, interval = avgInterval, count = wf.count
                        })
                end
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
-- ENTITY / OBJECT SPAWN PROTECTION (expanded)
-- =========================================================================

local entityOwnership = {}
local entitySpawnRates = {}     -- [src] = { timestamps }

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
        Flag(src, 'entities', string_format('Excessive entities: %d total (max %d)', total, ecfg.max_per_player),
            ecfg.excess_severity or 3, ecfg.excess_action, counts)
    end

    if peds > ecfg.max_peds then
        Flag(src, 'entities', string_format('Excessive peds: %d (max %d)', peds, ecfg.max_peds),
            ecfg.excess_severity or 3, ecfg.excess_action, counts)
    end

    if vehicles > ecfg.max_vehicles then
        Flag(src, 'entities', string_format('Excessive vehicles: %d (max %d)', vehicles, ecfg.max_vehicles),
            ecfg.excess_severity or 3, ecfg.excess_action, counts)
    end

    if ecfg.max_objects and objects > ecfg.max_objects then
        Flag(src, 'entities', string_format('Excessive objects: %d (max %d)', objects, ecfg.max_objects),
            ecfg.excess_severity or 3, ecfg.excess_action, counts)
    end
end)

-- Blacklisted model check
RegisterNetEvent('hydra:anticheat:report:model_spawn', function(model)
    local src = source
    if not IsModuleEnabled('entities') then return end

    local ecfg = cfg.entities

    -- Check general blacklist
    for _, blocked in ipairs(ecfg.blacklisted_models or {}) do
        if model == blocked or GetHashKey(tostring(blocked)) == model then
            Flag(src, 'entities', string_format('Blacklisted model: %s', model),
                ecfg.blacklist_severity or 5, ecfg.blacklist_action, { model = model })
            return
        end
    end

    -- Check vehicle blacklist
    for _, blocked in ipairs(ecfg.blacklisted_vehicles or {}) do
        if model == blocked or GetHashKey(tostring(blocked)) == model then
            Flag(src, 'entities', string_format('Blacklisted vehicle: %s', model),
                ecfg.blacklist_severity or 5, ecfg.blacklist_action, { model = model })
            return
        end
    end

    -- Check ped blacklist
    for _, blocked in ipairs(ecfg.blacklisted_peds or {}) do
        if model == blocked or GetHashKey(tostring(blocked)) == model then
            Flag(src, 'entities', string_format('Blacklisted ped: %s', model),
                ecfg.blacklist_severity or 5, ecfg.blacklist_action, { model = model })
            return
        end
    end

    -- Entity spawn rate limiting
    if ecfg.max_spawn_rate then
        local now = os_time()
        entitySpawnRates[src] = entitySpawnRates[src] or {}
        local rates = entitySpawnRates[src]

        -- Prune old entries (older than 60s)
        local fresh = {}
        for _, t in ipairs(rates) do
            if (now - t) < 60 then fresh[#fresh + 1] = t end
        end
        fresh[#fresh + 1] = now
        entitySpawnRates[src] = fresh

        if #fresh > ecfg.max_spawn_rate then
            Flag(src, 'entities', string_format('Entity spawn rate: %d/min (max %d)', #fresh, ecfg.max_spawn_rate),
                ecfg.rate_severity or 3, ecfg.rate_action or 'kick', { rate = #fresh })
        end
    end
end)

-- Attached objects detection
RegisterNetEvent('hydra:anticheat:report:attached', function(data)
    local src = source
    if not IsModuleEnabled('entities') then return end
    if type(data) ~= 'table' then return end

    Flag(src, 'entities', string_format('Excessive attached objects: %d', data.count or 0),
        cfg.entities.attached_severity or 4, cfg.entities.attached_action or 'kick', data)
end)

-- Cleanup on drop
AddEventHandler('playerDropped', function()
    local src = source
    entityOwnership[src] = nil
    entitySpawnRates[src] = nil
end)

-- =========================================================================
-- EXPLOSION FILTERING (expanded)
-- =========================================================================

if cfg.explosions and cfg.explosions.enabled then
    local explosionCounts = {}

    AddEventHandler('explosionEvent', function(src, ev)
        if not IsModuleEnabled('explosions') then return end
        if src <= 0 then return end

        local ecfg = cfg.explosions

        -- Blocked explosion types
        for _, blocked in ipairs(ecfg.blocked_types) do
            if ev.explosionType == blocked then
                Flag(src, 'explosions', string_format('Blocked explosion type: %d', ev.explosionType),
                    ecfg.blocked_severity or 5, ecfg.blocked_action, { type = ev.explosionType })
                CancelEvent()
                return
            end
        end

        -- Distance check: is the explosion impossibly far from the player?
        if ecfg.max_distance then
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local playerPos = GetEntityCoords(ped)
                local expPos = vector3(ev.posX, ev.posY, ev.posZ)
                local dx = playerPos.x - expPos.x
                local dy = playerPos.y - expPos.y
                local dz = playerPos.z - expPos.z
                local dist = math_sqrt(dx*dx + dy*dy + dz*dz)

                if dist > ecfg.max_distance then
                    Flag(src, 'explosions', string_format('Remote explosion: %.0fm away (max %.0f)', dist, ecfg.max_distance),
                        ecfg.distance_severity or 4, ecfg.distance_action or 'kick', {
                            type = ev.explosionType, distance = dist
                        })
                    CancelEvent()
                    return
                end
            end
        end

        -- Rate limit
        local now = os_time()
        if not explosionCounts[src] or now > explosionCounts[src].resetTime then
            explosionCounts[src] = { count = 0, resetTime = now + 60 }
        end
        explosionCounts[src].count = explosionCounts[src].count + 1

        if explosionCounts[src].count > ecfg.max_per_minute then
            Flag(src, 'explosions', string_format('Explosion flood: %d/min (max %d)', explosionCounts[src].count, ecfg.max_per_minute),
                ecfg.flood_severity or 4, ecfg.flood_action, { count = explosionCounts[src].count })
            CancelEvent()
        end
    end)

    -- Cleanup
    AddEventHandler('playerDropped', function()
        explosionCounts[source] = nil
    end)
end

-- =========================================================================
-- RESOURCE INTEGRITY
-- =========================================================================

CreateThread(function()
    if not cfg.resources or not cfg.resources.enabled then return end

    local expectedResources = {}
    local numResources = GetNumResources()
    for i = 0, numResources - 1 do
        local name = GetResourceByFindIndex(i)
        if name then expectedResources[name] = true end
    end

    if cfg.resources.detect_injection then
        AddEventHandler('onResourceStart', function(resource)
            if not expectedResources[resource] then
                Hydra.AntiCheat.Flag(0, 'resources',
                    string_format('Unexpected resource started: %s', resource),
                    cfg.resources.injection_severity or 5, 'log', { resource = resource })
                expectedResources[resource] = true
            end
        end)
    end

    -- Detect resource stops
    if cfg.resources.detect_stop then
        AddEventHandler('onResourceStop', function(resource)
            if resource == 'hydra_anticheat' then return end
            for _, required in ipairs(cfg.resources.required) do
                if resource == required then
                    Hydra.AntiCheat.Flag(0, 'resources',
                        string_format('Required resource stopped: %s', resource),
                        cfg.resources.stop_severity or 3, cfg.resources.stop_action or 'log', { resource = resource })
                end
            end
        end)
    end

    -- Periodic required resource check
    while true do
        Wait(cfg.resources.check_interval)
        if not IsModuleEnabled('resources') then goto continue end

        for _, required in ipairs(cfg.resources.required) do
            if GetResourceState(required) ~= 'started' then
                Hydra.AntiCheat.Flag(0, 'resources',
                    string_format('Required resource not running: %s', required),
                    4, 'log', { resource = required })
            end
        end

        ::continue::
    end
end)

-- Client-reported resource stop
RegisterNetEvent('hydra:anticheat:report:resource_stop', function(resource)
    local src = source
    if not IsModuleEnabled('resources') then return end
    if type(resource) ~= 'string' then return end

    -- Only flag if it's a required resource
    for _, required in ipairs(cfg.resources.required or {}) do
        if resource == required then
            Flag(src, 'resources', string_format('Client reports resource stopped: %s', resource),
                3, 'log', { resource = resource })
            return
        end
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

    if dist > (cfg.spectate.max_camera_distance or 200.0) then
        Flag(src, 'spectate', string_format('Camera %.0fm from ped (max %.0f)', dist, cfg.spectate.max_camera_distance),
            cfg.spectate.severity or 3, cfg.spectate.action, {
                cameraPos = camPos, pedPos = pedPos, distance = dist
            })
    end
end)

-- =========================================================================
-- PED FLAG ANOMALIES (expanded)
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
        Flag(src, 'ped_flags', 'Super jump detected', pfcfg.severity or 3, pfcfg.action, flags)
    end

    if pfcfg.infinite_stamina and flags.infiniteStamina then
        Flag(src, 'ped_flags', 'Infinite stamina detected', pfcfg.severity or 3, pfcfg.action, flags)
    end

    if pfcfg.detect_invisible and flags.invisible then
        Flag(src, 'ped_flags', 'Player ped invisible', pfcfg.severity or 3, pfcfg.action, flags)
    end

    if pfcfg.detect_no_ragdoll and flags.noRagdoll then
        Flag(src, 'ped_flags', 'Ragdoll disabled', 2, 'log', flags)
    end

    -- Invincibility detection
    if flags.invincible then
        Flag(src, 'ped_flags', 'Player set invincible', 4, pfcfg.action or 'kick', flags)
    end

    -- Can't be dragged from vehicle
    if flags.cantBeDragged then
        Flag(src, 'ped_flags', 'Cannot be dragged from vehicle (mod flag)', 3, pfcfg.action or 'kick', flags)
    end

    -- Impossible wanted level
    if flags.wantedLevel and flags.wantedLevel > 5 then
        Flag(src, 'ped_flags', string_format('Impossible wanted level: %d', flags.wantedLevel),
            3, 'kick', flags)
    end

    -- Anomaly string (generic client-detected anomaly)
    if flags.anomaly then
        Flag(src, 'ped_flags', string_format('Ped anomaly: %s', flags.anomaly),
            3, 'log', flags)
    end
end)

-- Menu detection reports (from client/menu_detection.lua)
RegisterNetEvent('hydra:anticheat:report:menu', function(data)
    local src = source
    if not IsModuleEnabled('menu_detection') then return end
    if type(data) ~= 'table' then return end

    local mcfg = cfg.menu_detection
    local dtype = data.type or 'unknown'
    local name = data.name or 'unknown'

    Flag(src, 'menu_detection', string_format('Menu detected [%s]: %s', dtype, name),
        mcfg.severity or 5, mcfg.action or 'ban', data)
end)
