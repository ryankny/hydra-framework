--[[
    Hydra Physics - Ragdoll System

    Force-based ragdoll for vehicle impacts, bullets, explosions,
    melee, falls, and object hits. Applies to both players and NPCs.
    Uses natural motion blending for realistic ragdoll poses.
]]

Hydra = Hydra or {}
Hydra.Physics = Hydra.Physics or {}

local cfg = HydraPhysicsConfig.ragdoll
if not cfg or not cfg.enabled then return end

-- Per-ped ragdoll cooldown: [entity] = next_allowed_time
local ragdollCooldowns = {}

-- Currently ragdolled NPCs (for performance cap)
local ragdolledNPCs = {}
local ragdolledCount = 0

-- Hook registry
local hooks = {
    preRagdoll = {},
    postRagdoll = {},
}

-- =============================================
-- CORE RAGDOLL APPLICATION
-- =============================================

--- Calculate ragdoll duration from a force value using the duration curve
--- @param force number impact force magnitude
--- @param curve table duration curve config
--- @return number duration in ms
local function calcDuration(force, curve)
    for _, band in ipairs(curve) do
        if force >= band[1] and force < band[2] then
            local t = (force - band[1]) / math.max(1, band[2] - band[1])
            return math.floor(band[3] + t * (band[4] - band[3]))
        end
    end
    -- Fallback to last band max
    return curve[#curve][4]
end

--- Apply ragdoll to a ped with directional force
--- @param ped number entity
--- @param force vector3 force direction and magnitude
--- @param duration number ms
--- @param source string impact type identifier
--- @param data table|nil extra data for hooks
--- @return boolean applied
function Hydra.Physics.ApplyRagdoll(ped, force, duration, source, data)
    if not DoesEntityExist(ped) then return false end
    if IsPedInAnyVehicle(ped, true) then return false end
    if IsPedRagdoll(ped) then return false end

    -- Cooldown check
    local now = GetGameTimer()
    if ragdollCooldowns[ped] and now < ragdollCooldowns[ped] then
        return false
    end

    -- NPC cap check
    local isPlayer = IsPedAPlayer(ped)
    if not isPlayer then
        if ragdolledCount >= (cfg.max_ragdolled_npcs or 12) then
            return false
        end
    end

    -- Player toggle check
    if isPlayer and not cfg.player then return false end
    if not isPlayer and not cfg.npc then return false end

    -- Pre-ragdoll hooks
    local hookData = {
        ped = ped,
        force = force,
        duration = duration,
        source = source,
        data = data or {},
        cancelled = false,
    }

    for _, hook in ipairs(hooks.preRagdoll) do
        local ok, result = pcall(hook, hookData)
        if ok and result == false then
            return false
        end
        if hookData.cancelled then
            return false
        end
    end

    -- Apply modified values from hooks
    force = hookData.force
    duration = hookData.duration

    -- Clamp duration
    duration = math.max(500, math.min(12000, duration))

    -- Set ragdoll
    SetPedToRagdoll(ped, duration, duration, 0, true, true, false)

    -- Apply directional force
    local forceMag = #force
    if forceMag > 0.1 then
        local normForce = force / forceMag
        -- Scale force to reasonable GTA units
        local scaledForce = math.min(forceMag, 200.0)

        Wait(0) -- Let ragdoll init before applying force

        if DoesEntityExist(ped) and IsPedRagdoll(ped) then
            ApplyForceToEntityCenterOfMass(ped, 1,
                normForce.x * scaledForce,
                normForce.y * scaledForce,
                normForce.z * scaledForce,
                false, false, true, false)

            -- Natural motion: arm flailing
            if cfg.arm_flail and cfg.use_natural_motion then
                SetPedRagdollForceFall(ped)
            end
        end
    end

    -- Set cooldown
    ragdollCooldowns[ped] = now + (cfg.cooldown or 2000)

    -- Track NPC ragdoll count
    if not isPlayer then
        ragdolledNPCs[ped] = now + duration
        ragdolledCount = ragdolledCount + 1
    end

    -- Post-ragdoll hooks
    hookData.applied = true
    for _, hook in ipairs(hooks.postRagdoll) do
        pcall(hook, hookData)
    end

    -- Fire event
    TriggerEvent('hydra:physics:ragdollApplied', {
        ped = ped,
        source = source,
        force = forceMag,
        duration = duration,
        isPlayer = isPlayer,
    })

    return true
end

-- =============================================
-- VEHICLE IMPACT DETECTION
-- =============================================

if cfg.vehicle_impact and cfg.vehicle_impact.enabled then
    local pedStates = {} -- [ped] = { lastHealth, wasHitByVeh }

    CreateThread(function()
        while true do
            Wait(cfg.npc_scan_rate or 250)
            local playerPed = PlayerPedId()
            local playerPos = GetEntityCoords(playerPed)

            -- Build ped list: player + nearby NPCs
            local peds = { playerPed }
            if cfg.npc then
                local handle, ped = FindFirstPed()
                local found = handle ~= -1
                while found do
                    if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                        if #(GetEntityCoords(ped) - playerPos) < cfg.npc_range then
                            peds[#peds + 1] = ped
                        end
                    end
                    found, ped = FindNextPed(handle)
                end
                EndFindPed(handle)
            end

            for _, ped in ipairs(peds) do
                if DoesEntityExist(ped) and not IsPedInAnyVehicle(ped, true) and not IsPedRagdoll(ped) then
                    -- Check if ped has been hit by a vehicle
                    if HasEntityBeenDamagedByAnyVehicle(ped) then
                        -- Find the vehicle that hit them
                        local hitVeh = 0
                        local vHandle, veh = FindFirstVehicle()
                        local vFound = vHandle ~= -1
                        while vFound do
                            if DoesEntityExist(veh) and HasEntityBeenDamagedByEntity(ped, veh, true) then
                                hitVeh = veh
                                break
                            end
                            vFound, veh = FindNextVehicle(vHandle)
                        end
                        EndFindVehicle(vHandle)

                        if hitVeh ~= 0 then
                            local vehSpeed = GetEntitySpeed(hitVeh) * 3.6 -- km/h

                            if vehSpeed >= cfg.vehicle_impact.min_speed then
                                -- Calculate impact force: mass * velocity
                                local vehVel = GetEntityVelocity(hitVeh)
                                local pedPos = GetEntityCoords(ped)
                                local vehPos = GetEntityCoords(hitVeh)

                                -- Direction: vehicle to ped
                                local dir = pedPos - vehPos
                                local dirLen = #dir
                                if dirLen > 0.01 then dir = dir / dirLen end

                                -- Force magnitude based on speed
                                local forceMag = vehSpeed * cfg.vehicle_impact.force_multiplier

                                -- Add vertical component
                                local vertForce = forceMag * cfg.vehicle_impact.vertical_factor
                                local forceVec = vector3(
                                    dir.x * forceMag,
                                    dir.y * forceMag,
                                    vertForce
                                )

                                -- Duration from curve
                                local duration = calcDuration(forceMag, cfg.vehicle_impact.duration_curve)

                                -- Apply ragdoll
                                Hydra.Physics.ApplyRagdoll(ped, forceVec, duration, 'vehicle_impact', {
                                    vehicle = hitVeh,
                                    speed = vehSpeed,
                                    forceMagnitude = forceMag,
                                })

                                -- Fire impact event
                                TriggerEvent('hydra:physics:vehicleImpact', {
                                    ped = ped,
                                    vehicle = hitVeh,
                                    speed = vehSpeed,
                                    force = forceMag,
                                    isPlayer = IsPedAPlayer(ped),
                                })
                            end
                        end

                        ClearEntityLastDamageEntity(ped)
                    end
                end
            end
        end
    end)
end

-- =============================================
-- BULLET IMPACT DETECTION
-- =============================================

if cfg.bullet_impact and cfg.bullet_impact.enabled then
    local prevHealth = {}

    CreateThread(function()
        while true do
            Wait(100)
            local playerPed = PlayerPedId()
            local playerPos = GetEntityCoords(playerPed)

            -- Check player and nearby NPCs
            local peds = { playerPed }
            if cfg.npc then
                local handle, ped = FindFirstPed()
                local found = handle ~= -1
                while found do
                    if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                        if #(GetEntityCoords(ped) - playerPos) < cfg.npc_range then
                            peds[#peds + 1] = ped
                        end
                    end
                    found, ped = FindNextPed(handle)
                end
                EndFindPed(handle)
            end

            for _, ped in ipairs(peds) do
                if not DoesEntityExist(ped) then goto nextPed end
                if IsPedInAnyVehicle(ped, true) or IsPedRagdoll(ped) then goto nextPed end

                local health = GetEntityHealth(ped)
                local prev = prevHealth[ped]
                prevHealth[ped] = health

                if prev and health < prev then
                    local damage = prev - health

                    -- Check if damage was from a weapon (not vehicle, fall, etc.)
                    if HasEntityBeenDamagedByAnyPed(ped) then
                        local weaponHash = GetPedCauseOfDeath(ped)

                        if damage >= cfg.bullet_impact.min_damage then
                            -- Determine force and chance
                            local force = cfg.bullet_impact.force
                            local chance = cfg.bullet_impact.base_chance
                            local duration = cfg.bullet_impact.min_duration

                            -- Scale chance with damage
                            chance = math.min(1.0, chance + (damage / 200.0))

                            -- Headshot override
                            local lastBone = GetPedLastDamageBone(ped)
                            local isHeadshot = lastBone == 31086 or lastBone == 39317

                            if isHeadshot and cfg.bullet_impact.headshot_always then
                                chance = 1.0
                                force = cfg.bullet_impact.headshot_force
                                duration = cfg.bullet_impact.max_duration
                            end

                            -- Heavy weapon override
                            local isHeavy = false
                            if cfg.bullet_impact.heavy_weapon_always then
                                -- Shotgun, RPG, explosive weapon hashes
                                local heavyWeapons = {
                                    [`WEAPON_PUMPSHOTGUN`] = true, [`WEAPON_SAWNOFFSHOTGUN`] = true,
                                    [`WEAPON_ASSAULTSHOTGUN`] = true, [`WEAPON_BULLPUPSHOTGUN`] = true,
                                    [`WEAPON_COMBATSHOTGUN`] = true, [`WEAPON_DBSHOTGUN`] = true,
                                    [`WEAPON_HEAVYSNIPER`] = true, [`WEAPON_HEAVYSNIPER_MK2`] = true,
                                    [`WEAPON_RPG`] = true, [`WEAPON_GRENADELAUNCHER`] = true,
                                    [`WEAPON_MINIGUN`] = true, [`WEAPON_RAILGUN`] = true,
                                }
                                if heavyWeapons[weaponHash] then
                                    isHeavy = true
                                    chance = 1.0
                                    force = cfg.bullet_impact.heavy_weapon_force
                                    duration = cfg.bullet_impact.max_duration
                                end
                            end

                            -- Roll chance
                            if math.random() <= chance then
                                -- Direction: opposite of attacker
                                local attacker = GetPedSourceOfDeath(ped)
                                local forceDir
                                if attacker and DoesEntityExist(attacker) then
                                    local attackerPos = GetEntityCoords(attacker)
                                    local pedPos = GetEntityCoords(ped)
                                    forceDir = pedPos - attackerPos
                                    local len = #forceDir
                                    if len > 0.01 then forceDir = forceDir / len end
                                else
                                    forceDir = vector3(math.random() - 0.5, math.random() - 0.5, 0.1)
                                end

                                local forceVec = forceDir * force
                                duration = math.floor(duration + (damage / 100.0) * (cfg.bullet_impact.max_duration - cfg.bullet_impact.min_duration))

                                Hydra.Physics.ApplyRagdoll(ped, forceVec, duration, 'bullet_impact', {
                                    weapon = weaponHash,
                                    damage = damage,
                                    headshot = isHeadshot,
                                    heavy = isHeavy,
                                    attacker = attacker,
                                })

                                TriggerEvent('hydra:physics:bulletImpact', {
                                    ped = ped,
                                    weapon = weaponHash,
                                    damage = damage,
                                    bone = lastBone,
                                    attacker = attacker,
                                    isPlayer = IsPedAPlayer(ped),
                                })
                            end
                        end

                        ClearEntityLastDamageEntity(ped)
                    end
                end

                ::nextPed::
            end

            -- Clean stale health tracking
            for ped in pairs(prevHealth) do
                if not DoesEntityExist(ped) then
                    prevHealth[ped] = nil
                end
            end
        end
    end)
end

-- =============================================
-- MELEE IMPACT
-- =============================================

if cfg.melee_impact and cfg.melee_impact.enabled then
    CreateThread(function()
        while true do
            Wait(150)
            local playerPed = PlayerPedId()
            local playerPos = GetEntityCoords(playerPed)

            local peds = { playerPed }
            if cfg.npc then
                local handle, ped = FindFirstPed()
                local found = handle ~= -1
                while found do
                    if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                        if #(GetEntityCoords(ped) - playerPos) < 30.0 then
                            peds[#peds + 1] = ped
                        end
                    end
                    found, ped = FindNextPed(handle)
                end
                EndFindPed(handle)
            end

            for _, ped in ipairs(peds) do
                if not DoesEntityExist(ped) or IsPedRagdoll(ped) then goto skip end

                if HasEntityBeenDamagedByAnyPed(ped) then
                    local weapon = GetPedCauseOfDeath(ped)
                    -- Melee weapon hashes
                    local isMelee = weapon == `WEAPON_UNARMED` or weapon == `WEAPON_BAT`
                        or weapon == `WEAPON_CROWBAR` or weapon == `WEAPON_GOLFCLUB`
                        or weapon == `WEAPON_HAMMER` or weapon == `WEAPON_HATCHET`
                        or weapon == `WEAPON_KNIFE` or weapon == `WEAPON_MACHETE`
                        or weapon == `WEAPON_WRENCH` or weapon == `WEAPON_BATTLEAXE`
                        or weapon == `WEAPON_POOLCUE` or weapon == `WEAPON_SWITCHBLADE`
                        or weapon == `WEAPON_NIGHTSTICK` or weapon == `WEAPON_DAGGER`

                    if isMelee then
                        local isHeavy = weapon ~= `WEAPON_UNARMED`
                        local chance = isHeavy and cfg.melee_impact.heavy_chance or cfg.melee_impact.light_chance
                        local force = isHeavy and cfg.melee_impact.heavy_force or cfg.melee_impact.light_force

                        if math.random() <= chance then
                            local attacker = GetPedSourceOfDeath(ped)
                            local dir = vector3(math.random() - 0.5, math.random() - 0.5, 0.15)
                            if attacker and DoesEntityExist(attacker) then
                                local aPos = GetEntityCoords(attacker)
                                local pPos = GetEntityCoords(ped)
                                dir = pPos - aPos
                                local len = #dir
                                if len > 0.01 then dir = dir / len end
                                dir = vector3(dir.x, dir.y, 0.15)
                            end

                            local duration = math.random(cfg.melee_impact.min_duration, cfg.melee_impact.max_duration)
                            Hydra.Physics.ApplyRagdoll(ped, dir * force, duration, 'melee_impact', {
                                attacker = attacker, isHeavy = isHeavy,
                            })

                            TriggerEvent('hydra:physics:meleeImpact', {
                                ped = ped, attacker = attacker, force = force,
                                isHeavy = isHeavy, isPlayer = IsPedAPlayer(ped),
                            })
                        end
                    end

                    ClearEntityLastDamageEntity(ped)
                end

                ::skip::
            end
        end
    end)
end

-- =============================================
-- FALL DETECTION
-- =============================================

if cfg.falling and cfg.falling.enabled then
    local fallingPeds = {} -- [ped] = startZ

    CreateThread(function()
        while true do
            Wait(200)
            local playerPed = PlayerPedId()
            local playerPos = GetEntityCoords(playerPed)

            local peds = { playerPed }
            if cfg.npc then
                local handle, ped = FindFirstPed()
                local found = handle ~= -1
                while found do
                    if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                        if #(GetEntityCoords(ped) - playerPos) < 40.0 then
                            peds[#peds + 1] = ped
                        end
                    end
                    found, ped = FindNextPed(handle)
                end
                EndFindPed(handle)
            end

            for _, ped in ipairs(peds) do
                if not DoesEntityExist(ped) then
                    fallingPeds[ped] = nil
                    goto nextFall
                end

                local pos = GetEntityCoords(ped)
                local isFalling = IsPedFalling(ped) or GetEntityHeightAboveGround(ped) > cfg.falling.min_height

                if isFalling and not fallingPeds[ped] then
                    -- Started falling
                    fallingPeds[ped] = pos.z
                elseif not isFalling and fallingPeds[ped] then
                    -- Landed
                    local fallHeight = fallingPeds[ped] - pos.z
                    fallingPeds[ped] = nil

                    if fallHeight >= cfg.falling.min_height then
                        local force = fallHeight * cfg.falling.force_multiplier
                        local t = math.min(1.0, fallHeight / 20.0)
                        local duration = math.floor(cfg.falling.min_duration + t * (cfg.falling.max_duration - cfg.falling.min_duration))

                        -- Downward + slight random horizontal
                        local forceVec = vector3(
                            (math.random() - 0.5) * force * 0.3,
                            (math.random() - 0.5) * force * 0.3,
                            -force * 0.1
                        )

                        Hydra.Physics.ApplyRagdoll(ped, forceVec, duration, 'fall', {
                            height = fallHeight,
                        })

                        TriggerEvent('hydra:physics:fallImpact', {
                            ped = ped, height = fallHeight, force = force,
                            isPlayer = IsPedAPlayer(ped),
                        })
                    end
                end

                ::nextFall::
            end

            -- Cleanup
            for ped in pairs(fallingPeds) do
                if not DoesEntityExist(ped) then fallingPeds[ped] = nil end
            end
        end
    end)
end

-- =============================================
-- NPC RAGDOLL TRACKING / CLEANUP
-- =============================================

CreateThread(function()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        for ped, expiresAt in pairs(ragdolledNPCs) do
            if not DoesEntityExist(ped) or now >= expiresAt then
                ragdolledNPCs[ped] = nil
                ragdolledCount = math.max(0, ragdolledCount - 1)
            end
        end

        -- Cleanup cooldowns
        for ped in pairs(ragdollCooldowns) do
            if not DoesEntityExist(ped) then ragdollCooldowns[ped] = nil end
        end
    end
end)

-- =============================================
-- HOOK API
-- =============================================

--- Register a pre-ragdoll hook (return false to cancel)
--- @param fn function(hookData) -> boolean|nil
function Hydra.Physics.OnPreRagdoll(fn)
    hooks.preRagdoll[#hooks.preRagdoll + 1] = fn
end

--- Register a post-ragdoll hook (informational)
--- @param fn function(hookData)
function Hydra.Physics.OnPostRagdoll(fn)
    hooks.postRagdoll[#hooks.postRagdoll + 1] = fn
end
