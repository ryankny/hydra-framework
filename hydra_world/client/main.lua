--[[
    Hydra World - Client Main

    Module registration, admin event handling,
    and unified API exports.
]]

Hydra = Hydra or {}
Hydra.World = Hydra.World or {}

local cfg = HydraWorldConfig

-- =============================================
-- SERVER OVERRIDES
-- =============================================

-- Server can push runtime overrides to clients
RegisterNetEvent('hydra:world:override')
AddEventHandler('hydra:world:override', function(category, key, value)
    if type(category) ~= 'string' or type(key) ~= 'string' then return end

    if category == 'population' then
        if key == 'ped_density' and Hydra.World.SetDensity then
            Hydra.World.SetDensity(tonumber(value), nil)
        elseif key == 'vehicle_density' and Hydra.World.SetDensity then
            Hydra.World.SetDensity(nil, tonumber(value))
        end
    elseif category == 'npc' then
        if key == 'accuracy' and Hydra.World.SetNPCAccuracy then
            Hydra.World.SetNPCAccuracy(tonumber(value) or 0.4)
        end
    elseif category == 'scenario' then
        if Hydra.World.SetScenarioGroup then
            Hydra.World.SetScenarioGroup(key, value == true or value == 'true')
        end
    end
end)

-- =============================================
-- CLEAR AREA (admin command)
-- =============================================

RegisterNetEvent('hydra:world:clearArea')
AddEventHandler('hydra:world:clearArea', function(radius)
    radius = tonumber(radius) or 50.0
    local pos = GetEntityCoords(PlayerPedId())
    ClearAreaOfPeds(pos.x, pos.y, pos.z, radius, 0)
    ClearAreaOfVehicles(pos.x, pos.y, pos.z, radius, false, false, false, false, false, false)
    ClearAreaOfCops(pos.x, pos.y, pos.z, radius, 0)
    ClearAreaOfObjects(pos.x, pos.y, pos.z, radius, 0)

    TriggerEvent('hydra:notify:show', {
        type = 'success', title = 'World',
        message = ('Cleared area (radius: %.0f)'):format(radius),
        duration = 3000,
    })
end)

-- =============================================
-- RESET OVERRIDES
-- =============================================

RegisterNetEvent('hydra:world:reset')
AddEventHandler('hydra:world:reset', function()
    -- Reset density to config defaults
    if Hydra.World.SetDensity then
        Hydra.World.SetDensity(cfg.population.ped_density, cfg.population.vehicle_density)
    end
    if Hydra.World.SetNPCAccuracy then
        Hydra.World.SetNPCAccuracy(cfg.npc_behavior.npc_accuracy)
    end
end)

-- =============================================
-- WEAPON REMOVAL ON SPAWN
-- =============================================

if cfg.blacklist and cfg.blacklist.enabled and cfg.blacklist.remove_weapons_on_spawn then
    RegisterNetEvent('hydra:world:clearWeapons')
    AddEventHandler('hydra:world:clearWeapons', function()
        RemoveAllPedWeapons(PlayerPedId(), true)
    end)
end

-- =============================================
-- MODULE EXPORTS
-- =============================================

exports('SetDensity', function(ped, veh)
    if Hydra.World.SetDensity then Hydra.World.SetDensity(ped, veh) end
end)

exports('GetDensity', function()
    if Hydra.World.GetDensity then return Hydra.World.GetDensity() end
    return 1.0, 1.0
end)

exports('GetCurrentZone', function()
    if Hydra.World.GetCurrentZone then return Hydra.World.GetCurrentZone() end
    return 'UNKNOWN'
end)

exports('HasSeatbelt', function()
    if Hydra.World.HasSeatbelt then return Hydra.World.HasSeatbelt() end
    return false
end)

exports('ClearWanted', function()
    if Hydra.World.ClearWanted then Hydra.World.ClearWanted() end
end)

exports('GetRestrictedZone', function()
    if Hydra.World.GetRestrictedZone then return Hydra.World.GetRestrictedZone() end
    return nil
end)

exports('SetScenarioGroup', function(group, enabled)
    if Hydra.World.SetScenarioGroup then Hydra.World.SetScenarioGroup(group, enabled) end
end)
