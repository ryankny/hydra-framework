--[[
    Hydra Physics - Client Main

    Unified API, exports, and module-level configuration.
    Serves as the public interface for the physics system.
]]

Hydra = Hydra or {}
Hydra.Physics = Hydra.Physics or {}

local cfg = HydraPhysicsConfig

-- =============================================
-- GETTING-UP SPEED
-- =============================================

-- Modify NM get-up speed for more realistic recovery
if cfg.ragdoll and cfg.ragdoll.enabled and cfg.ragdoll.getup_speed ~= 1.0 then
    CreateThread(function()
        while true do
            Wait(500)
            local ped = PlayerPedId()
            if IsPedRagdoll(ped) or IsPedGettingUp(ped) then
                SetPedMoveRateOverride(ped, cfg.ragdoll.getup_speed)
            end
        end
    end)
end

-- =============================================
-- SERVER OVERRIDE SUPPORT
-- =============================================

-- Admin: force unstick
RegisterNetEvent('hydra:physics:forceUnstick')
AddEventHandler('hydra:physics:forceUnstick', function()
    if Hydra.Physics.ForceUnstick then
        Hydra.Physics.ForceUnstick()
        TriggerEvent('hydra:notify:show', {
            type = 'success', title = 'Physics',
            message = 'Vehicle unstuck by admin.',
            duration = 3000,
        })
    end
end)

RegisterNetEvent('hydra:physics:override')
AddEventHandler('hydra:physics:override', function(section, key, value)
    if type(section) ~= 'string' or type(key) ~= 'string' then return end

    local target = cfg[section]
    if target and target[key] ~= nil then
        target[key] = value
    end
end)

-- =============================================
-- CLIENT EXPORTS
-- =============================================

-- Ragdoll API
exports('ApplyRagdoll', function(ped, forceX, forceY, forceZ, duration, source)
    local force = vector3(forceX or 0, forceY or 0, forceZ or 0)
    return Hydra.Physics.ApplyRagdoll(ped, force, duration or 3000, source or 'external')
end)

-- Handling API
exports('RefreshHandling', function()
    if Hydra.Physics.RefreshHandling then Hydra.Physics.RefreshHandling() end
end)

exports('GetHandlingProfile', function(vehicle)
    if Hydra.Physics.GetHandlingProfile then return Hydra.Physics.GetHandlingProfile(vehicle) end
    return {}
end)

exports('SetHandlingValue', function(vehicle, key, value)
    if Hydra.Physics.SetHandlingValue then return Hydra.Physics.SetHandlingValue(vehicle, key, value) end
    return false
end)

-- Hook API
exports('OnPreRagdoll', function(fn)
    if Hydra.Physics.OnPreRagdoll then Hydra.Physics.OnPreRagdoll(fn) end
end)

exports('OnPostRagdoll', function(fn)
    if Hydra.Physics.OnPostRagdoll then Hydra.Physics.OnPostRagdoll(fn) end
end)

exports('OnVehicleCrash', function(fn)
    if Hydra.Physics.OnVehicleCrash then Hydra.Physics.OnVehicleCrash(fn) end
end)

exports('OnPreImpact', function(fn)
    if Hydra.Physics.OnPreImpact then Hydra.Physics.OnPreImpact(fn) end
end)

exports('OnPostImpact', function(fn)
    if Hydra.Physics.OnPostImpact then Hydra.Physics.OnPostImpact(fn) end
end)

exports('OnForceCalculated', function(fn)
    if Hydra.Physics.OnForceCalculated then Hydra.Physics.OnForceCalculated(fn) end
end)

-- Dynamics API (rollover, aquaplaning, bogging)
exports('GetAquaplaneLevel', function()
    if Hydra.Physics.GetAquaplaneLevel then return Hydra.Physics.GetAquaplaneLevel() end
    return 0.0
end)

exports('GetSinkDepth', function()
    if Hydra.Physics.GetSinkDepth then return Hydra.Physics.GetSinkDepth() end
    return 0.0
end)

exports('IsStuck', function()
    if Hydra.Physics.IsStuck then return Hydra.Physics.IsStuck() end
    return false
end)

exports('GetEscapeProgress', function()
    if Hydra.Physics.GetEscapeProgress then return Hydra.Physics.GetEscapeProgress() end
    return 0.0
end)

exports('ForceUnstick', function()
    if Hydra.Physics.ForceUnstick then Hydra.Physics.ForceUnstick() end
end)
