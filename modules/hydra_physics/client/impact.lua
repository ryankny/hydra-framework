--[[
    Hydra Physics - Impact Detection System

    Central impact event bus for vehicle crashes and object
    collisions. Designed as the foundation for future vehicle
    damage and ped damage modules to hook into.
]]

Hydra = Hydra or {}
Hydra.Physics = Hydra.Physics or {}

local cfg = HydraPhysicsConfig.impact_events
if not cfg or not cfg.enabled then return end

-- Hook registry for impact events
local impactHooks = {
    preImpact = {},
    postImpact = {},
    vehicleCrash = {},
    forceCalculated = {},
}

-- =============================================
-- VEHICLE CRASH DETECTION
-- =============================================

if cfg.vehicle_crash and cfg.vehicle_crash.enabled then
    local crashCfg = cfg.vehicle_crash
    local vehicleSpeeds = {}  -- [entity] = lastSpeed
    local crashCooldowns = {} -- [entity] = next_allowed

    CreateThread(function()
        while true do
            Wait(cfg.tick_rate or 100)
            local ped = PlayerPedId()
            local playerPos = GetEntityCoords(ped)

            -- Collect vehicles to monitor
            local vehicles = {}
            local playerVeh = GetVehiclePedIsIn(ped, false)
            if playerVeh ~= 0 then vehicles[#vehicles + 1] = playerVeh end

            -- Also monitor nearby NPC vehicles for crash events
            if cfg.npc then
                local handle, veh = FindFirstVehicle()
                local found = handle ~= -1
                while found do
                    if DoesEntityExist(veh) and veh ~= playerVeh then
                        if #(GetEntityCoords(veh) - playerPos) < cfg.npc_range then
                            vehicles[#vehicles + 1] = veh
                        end
                    end
                    found, veh = FindNextVehicle(handle)
                end
                EndFindVehicle(handle)
            end

            local now = GetGameTimer()

            for _, veh in ipairs(vehicles) do
                if not DoesEntityExist(veh) then goto nextVeh end

                local speed = GetEntitySpeed(veh) * 3.6 -- km/h
                local prevSpeed = vehicleSpeeds[veh] or speed
                vehicleSpeeds[veh] = speed

                -- Calculate deceleration
                local decel = prevSpeed - speed

                -- Check for sudden deceleration (crash)
                if decel >= crashCfg.min_decel and prevSpeed >= crashCfg.min_speed then
                    -- Cooldown check
                    if crashCooldowns[veh] and now < crashCooldowns[veh] then
                        goto nextVeh
                    end
                    crashCooldowns[veh] = now + crashCfg.cooldown

                    -- Calculate crash force
                    local force = decel * (prevSpeed / 100.0)
                    local vel = GetEntityVelocity(veh)
                    local forwardVec = GetEntityForwardVector(veh)

                    -- Determine crash direction
                    -- Dot product of velocity with forward = front/rear
                    local dotForward = vel.x * forwardVec.x + vel.y * forwardVec.y
                    -- Dot product with right vector = side
                    local rightVec = vector3(-forwardVec.y, forwardVec.x, 0.0)
                    local dotRight = vel.x * rightVec.x + vel.y * rightVec.y

                    local direction = 'front'
                    if dotForward < -0.5 then direction = 'rear' end
                    if math.abs(dotRight) > math.abs(dotForward) then
                        direction = dotRight > 0 and 'right' or 'left'
                    end

                    -- Impact point estimation
                    local vehPos = GetEntityCoords(veh)

                    -- Pre-impact hook
                    local hookData = {
                        vehicle = veh,
                        speed = prevSpeed,
                        decel = decel,
                        force = force,
                        direction = direction,
                        position = vehPos,
                        cancelled = false,
                    }

                    for _, hook in ipairs(impactHooks.preImpact) do
                        local ok, result = pcall(hook, hookData)
                        if ok and result == false then goto nextVeh end
                        if hookData.cancelled then goto nextVeh end
                    end

                    -- Force calculation hook (lets damage modules modify)
                    for _, hook in ipairs(impactHooks.forceCalculated) do
                        pcall(hook, hookData)
                    end

                    -- Vehicle crash hooks (for damage modules)
                    for _, hook in ipairs(impactHooks.vehicleCrash) do
                        pcall(hook, hookData)
                    end

                    -- Fire the event
                    TriggerEvent('hydra:physics:vehicleCrash', {
                        vehicle = veh,
                        speed = prevSpeed,
                        decel = decel,
                        force = hookData.force,
                        direction = direction,
                        driver = GetPedInVehicleSeat(veh, -1),
                        isPlayerVehicle = veh == playerVeh,
                    })

                    -- Post-impact hooks
                    for _, hook in ipairs(impactHooks.postImpact) do
                        pcall(hook, hookData)
                    end
                end

                ::nextVeh::
            end

            -- Cleanup stale tracking
            for veh in pairs(vehicleSpeeds) do
                if not DoesEntityExist(veh) then
                    vehicleSpeeds[veh] = nil
                    crashCooldowns[veh] = nil
                end
            end
        end
    end)
end

-- =============================================
-- OBJECT IMPACT DETECTION
-- =============================================

local objCfg = HydraPhysicsConfig.ragdoll and HydraPhysicsConfig.ragdoll.object_impact
if objCfg and objCfg.enabled then
    CreateThread(function()
        while true do
            Wait(250)
            local playerPed = PlayerPedId()
            local playerPos = GetEntityCoords(playerPed)

            -- Check player and nearby NPCs for object damage
            local peds = { playerPed }
            if HydraPhysicsConfig.ragdoll.npc then
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
                if not DoesEntityExist(ped) or IsPedRagdoll(ped) then goto nextObj end

                if HasEntityBeenDamagedByAnyObject(ped) then
                    -- Find the object
                    local oHandle, obj = FindFirstObject()
                    local oFound = oHandle ~= -1
                    local hitObj = 0

                    while oFound do
                        if DoesEntityExist(obj) and HasEntityBeenDamagedByEntity(ped, obj, true) then
                            hitObj = obj
                            break
                        end
                        oFound, obj = FindNextObject(oHandle)
                    end
                    EndFindObject(oHandle)

                    if hitObj ~= 0 then
                        local objSpeed = #GetEntityVelocity(hitObj)

                        if objSpeed >= objCfg.min_speed then
                            local force = objSpeed * objCfg.force_multiplier
                            local pedPos = GetEntityCoords(ped)
                            local objPos = GetEntityCoords(hitObj)
                            local dir = pedPos - objPos
                            local dirLen = #dir
                            if dirLen > 0.01 then dir = dir / dirLen end

                            local forceVec = vector3(dir.x * force, dir.y * force, force * 0.2)
                            local t = math.min(1.0, force / 20.0)
                            local duration = math.floor(objCfg.min_duration + t * (objCfg.max_duration - objCfg.min_duration))

                            Hydra.Physics.ApplyRagdoll(ped, forceVec, duration, 'object_impact', {
                                object = hitObj, speed = objSpeed,
                            })

                            TriggerEvent('hydra:physics:objectImpact', {
                                ped = ped, object = hitObj, speed = objSpeed,
                                force = force, isPlayer = IsPedAPlayer(ped),
                            })
                        end
                    end

                    ClearEntityLastDamageEntity(ped)
                end

                ::nextObj::
            end
        end
    end)
end

-- =============================================
-- EXPLOSION DETECTION
-- =============================================

local explCfg = HydraPhysicsConfig.ragdoll and HydraPhysicsConfig.ragdoll.explosion_impact
if explCfg and explCfg.enabled then
    AddEventHandler('explosionEvent', function(sender, ev)
        local playerPed = PlayerPedId()
        local playerPos = GetEntityCoords(playerPed)
        local explPos = vector3(ev.posX, ev.posY, ev.posZ)

        -- Check player and nearby NPCs
        local peds = { playerPed }
        if HydraPhysicsConfig.ragdoll.npc then
            local handle, ped = FindFirstPed()
            local found = handle ~= -1
            while found do
                if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                    if #(GetEntityCoords(ped) - playerPos) < HydraPhysicsConfig.ragdoll.npc_range then
                        peds[#peds + 1] = ped
                    end
                end
                found, ped = FindNextPed(handle)
            end
            EndFindPed(handle)
        end

        for _, ped in ipairs(peds) do
            if not DoesEntityExist(ped) or IsPedInAnyVehicle(ped, true) then goto nextExpl end

            local pedPos = GetEntityCoords(ped)
            local dist = #(pedPos - explPos)

            if dist <= explCfg.max_range then
                -- Force inversely proportional to distance
                local proximity = 1.0 - (dist / explCfg.max_range)
                local force = proximity * explCfg.force_multiplier * 50.0

                local dir = pedPos - explPos
                local dirLen = #dir
                if dirLen > 0.01 then dir = dir / dirLen end

                local forceVec = vector3(
                    dir.x * force,
                    dir.y * force,
                    force * 0.5  -- Explosions launch upward
                )

                Hydra.Physics.ApplyRagdoll(ped, forceVec, explCfg.duration, 'explosion', {
                    coords = explPos, distance = dist,
                })

                TriggerEvent('hydra:physics:explosionImpact', {
                    ped = ped, coords = explPos, distance = dist,
                    force = force, isPlayer = IsPedAPlayer(ped),
                })
            end

            ::nextExpl::
        end
    end)
end

-- =============================================
-- IMPACT HOOK API
-- =============================================

--- Register a pre-impact hook (return false to cancel)
--- @param fn function(hookData)
function Hydra.Physics.OnPreImpact(fn)
    impactHooks.preImpact[#impactHooks.preImpact + 1] = fn
end

--- Register a post-impact hook
--- @param fn function(hookData)
function Hydra.Physics.OnPostImpact(fn)
    impactHooks.postImpact[#impactHooks.postImpact + 1] = fn
end

--- Register a vehicle crash hook (for damage modules)
--- @param fn function(hookData)
function Hydra.Physics.OnVehicleCrash(fn)
    impactHooks.vehicleCrash[#impactHooks.vehicleCrash + 1] = fn
end

--- Register a force calculation hook (modify force before apply)
--- @param fn function(hookData)
function Hydra.Physics.OnForceCalculated(fn)
    impactHooks.forceCalculated[#impactHooks.forceCalculated + 1] = fn
end
