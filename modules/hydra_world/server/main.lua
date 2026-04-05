--[[
    Hydra World - Server

    Module registration, admin commands for runtime
    world tuning, and server-to-client overrides.
]]

Hydra = Hydra or {}
Hydra.World = Hydra.World or {}

local cfg = HydraWorldConfig

-- =============================================
-- RUNTIME OVERRIDES
-- =============================================

-- Server-side override state (persists during resource lifetime)
local overrides = {
    ped_density = nil,
    vehicle_density = nil,
    npc_accuracy = nil,
}

--- Push a world override to all clients
--- @param category string e.g. 'population', 'npc', 'scenario'
--- @param key string
--- @param value any
function Hydra.World.SetOverride(category, key, value)
    overrides[key] = value
    TriggerClientEvent('hydra:world:override', -1, category, key, value)
end

--- Push current overrides to a newly joining player
local function syncOverrides(src)
    for key, value in pairs(overrides) do
        if value ~= nil then
            local cat = 'population'
            if key == 'npc_accuracy' then cat = 'npc' end
            TriggerClientEvent('hydra:world:override', src, cat, key, value)
        end
    end
end

-- =============================================
-- ADMIN COMMANDS
-- =============================================

RegisterCommand(cfg.admin.command, function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, cfg.admin.permission) then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'error', title = 'No Permission',
            message = 'You do not have permission.',
        })
        return
    end

    local subCmd = args[1]
    local reply = function(msg)
        if src > 0 then
            TriggerClientEvent('hydra:chat:systemMessage', src, {
                message = msg,
                color = '#6C5CE7',
            })
        else
            print('[Hydra World] ' .. msg)
        end
    end

    if subCmd == 'density' or subCmd == 'pop' then
        -- /world density <ped> [vehicle]
        local ped = tonumber(args[2])
        local veh = tonumber(args[3])
        if not ped then
            reply('Usage: /world density <ped_mult> [vehicle_mult]')
            reply('Current: ped=' .. tostring(overrides.ped_density or cfg.population.ped_density) ..
                  ' vehicle=' .. tostring(overrides.vehicle_density or cfg.population.vehicle_density))
            return
        end
        ped = math.max(0.0, math.min(3.0, ped))
        veh = veh and math.max(0.0, math.min(3.0, veh)) or ped

        Hydra.World.SetOverride('population', 'ped_density', ped)
        Hydra.World.SetOverride('population', 'vehicle_density', veh)
        reply(('Density set: ped=%.1f vehicle=%.1f'):format(ped, veh))

        if Hydra.Logs then
            local name = src > 0 and GetPlayerName(src) or 'Console'
            Hydra.Logs.Admin(src > 0 and src or nil, 'World Density',
                ('%s set density: ped=%.1f veh=%.1f'):format(name, ped, veh))
        end

    elseif subCmd == 'accuracy' then
        -- /world accuracy <0.0-1.0>
        local val = tonumber(args[2])
        if not val then
            reply('Usage: /world accuracy <0.0-1.0>')
            reply('Current: ' .. tostring(overrides.npc_accuracy or cfg.npc_behavior.npc_accuracy))
            return
        end
        val = math.max(0.0, math.min(1.0, val))
        Hydra.World.SetOverride('npc', 'accuracy', val)
        reply(('NPC accuracy set to %.2f'):format(val))

    elseif subCmd == 'scenario' then
        -- /world scenario <group> <on|off>
        local group = args[2]
        local state = args[3]
        if not group or not state then
            reply('Usage: /world scenario <group_name> <on|off>')
            return
        end
        local enabled = state == 'on' or state == 'true' or state == '1'
        Hydra.World.SetOverride('scenario', group, enabled)
        reply(('Scenario "%s" %s'):format(group, enabled and 'enabled' or 'disabled'))

    elseif subCmd == 'cleararea' then
        -- /world cleararea [radius] - clear NPCs/vehicles near admin
        if src <= 0 then
            reply('This command must be used in-game.')
            return
        end
        local radius = tonumber(args[2]) or 50.0
        radius = math.max(10.0, math.min(500.0, radius))

        TriggerClientEvent('hydra:world:clearArea', src, radius)
        reply(('Cleared area (radius: %.0f)'):format(radius))

    elseif subCmd == 'clearweapons' then
        -- /world clearweapons [player_id]
        local targetId = tonumber(args[2])
        if not targetId and src > 0 then targetId = src end
        if not targetId then
            reply('Usage: /world clearweapons [player_id]')
            return
        end
        TriggerClientEvent('hydra:world:clearWeapons', targetId)
        local name = GetPlayerName(targetId) or 'Unknown'
        reply(('Cleared weapons for %s (%d)'):format(name, targetId))

    elseif subCmd == 'info' then
        -- /world info - show current world settings
        reply('--- World Configuration ---')
        reply(('Ped Density: %.2f (override: %s)'):format(
            cfg.population.ped_density,
            overrides.ped_density and tostring(overrides.ped_density) or 'none'))
        reply(('Vehicle Density: %.2f (override: %s)'):format(
            cfg.population.vehicle_density,
            overrides.vehicle_density and tostring(overrides.vehicle_density) or 'none'))
        reply(('NPC Accuracy: %.2f (override: %s)'):format(
            cfg.npc_behavior.npc_accuracy,
            overrides.npc_accuracy and tostring(overrides.npc_accuracy) or 'none'))
        reply(('Wanted Level: %s'):format(cfg.law.disable_wanted_level and 'DISABLED' or 'ENABLED'))
        reply(('Dispatch: %s'):format(cfg.law.disable_dispatch and 'DISABLED' or 'ENABLED'))
        reply(('Ambient Cops: %s'):format(cfg.law.disable_ambient_cops and 'DISABLED' or 'ENABLED'))

    elseif subCmd == 'reset' then
        -- /world reset - clear all runtime overrides
        overrides = { ped_density = nil, vehicle_density = nil, npc_accuracy = nil }
        -- Force clients to re-read config defaults
        TriggerClientEvent('hydra:world:reset', -1)
        reply('World overrides reset to config defaults.')

    else
        reply('Usage: /world <density|accuracy|scenario|cleararea|clearweapons|info|reset>')
        reply('  density <ped> [vehicle]  - Set population density')
        reply('  accuracy <0-1>           - Set NPC accuracy')
        reply('  scenario <group> <on|off> - Toggle scenario group')
        reply('  cleararea [radius]       - Clear nearby NPCs/vehicles')
        reply('  clearweapons [id]        - Remove player weapons')
        reply('  info                     - Show current settings')
        reply('  reset                    - Reset to config defaults')
    end
end, false)

-- Client clear area handler
RegisterNetEvent('hydra:world:clearArea')
-- (Handled on client side)

-- =============================================
-- MODULE REGISTRATION
-- =============================================

Hydra.Modules.Register('world', {
    label = 'Hydra World',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 80,
    dependencies = {},

    onLoad = function()
        local features = {}
        if cfg.population.enabled then features[#features + 1] = 'population' end
        if cfg.law.enabled then features[#features + 1] = 'law' end
        if cfg.scenarios.enabled then features[#features + 1] = 'scenarios' end
        if cfg.environment.enabled then features[#features + 1] = 'environment' end
        if cfg.vehicles.enabled then features[#features + 1] = 'vehicles' end
        if cfg.blacklist.enabled then features[#features + 1] = 'blacklist' end
        if cfg.restricted_zones.enabled then features[#features + 1] = 'zones' end

        Hydra.Utils.Log('info', 'World module loaded (%s)', table.concat(features, ', '))
    end,

    onPlayerJoin = function(src)
        syncOverrides(src)

        -- Clear weapons on spawn if configured
        if cfg.blacklist and cfg.blacklist.enabled and cfg.blacklist.remove_weapons_on_spawn then
            TriggerClientEvent('hydra:world:clearWeapons', src)
        end
    end,

    api = {
        SetOverride = function(...) Hydra.World.SetOverride(...) end,
    },
})

-- Server exports
exports('WorldSetOverride', function(...) Hydra.World.SetOverride(...) end)
