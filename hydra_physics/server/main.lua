--[[
    Hydra Physics - Server

    Module registration and server-side configuration.
    Physics runs entirely client-side; server provides
    admin overrides and module lifecycle management.
]]

Hydra = Hydra or {}
Hydra.Physics = {}

local cfg = HydraPhysicsConfig

-- =============================================
-- MODULE REGISTRATION
-- =============================================

Hydra.Modules.Register('physics', {
    label = 'Hydra Physics',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 75,
    dependencies = {},

    onLoad = function()
        local features = {}
        if cfg.handling and cfg.handling.enabled then features[#features + 1] = 'handling' end
        if cfg.weight_transfer and cfg.weight_transfer.enabled then features[#features + 1] = 'weight_transfer' end
        if cfg.surface_traction and cfg.surface_traction.enabled then features[#features + 1] = 'surface_traction' end
        if cfg.ragdoll and cfg.ragdoll.enabled then features[#features + 1] = 'ragdoll' end
        if cfg.impact_events and cfg.impact_events.enabled then features[#features + 1] = 'impacts' end

        Hydra.Utils.Log('info', 'Physics module loaded (%s)', table.concat(features, ', '))
    end,

    api = {
        -- Server-side API: push overrides to clients
        SetOverride = function(section, key, value)
            TriggerClientEvent('hydra:physics:override', -1, section, key, value)
        end,
    },
})

-- =============================================
-- ADMIN COMMAND
-- =============================================

RegisterCommand('physics', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, 'hydra.admin') then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'error', title = 'No Permission',
            message = 'You do not have permission.',
        })
        return
    end

    local reply = function(msg)
        if src > 0 then
            TriggerClientEvent('hydra:chat:systemMessage', src, {
                message = msg, color = '#6C5CE7',
            })
        else
            print('[Hydra Physics] ' .. msg)
        end
    end

    local subCmd = args[1]

    if subCmd == 'ragdoll' then
        -- /physics ragdoll <on|off>
        local state = args[2]
        if state == 'on' then
            TriggerClientEvent('hydra:physics:override', -1, 'ragdoll', 'enabled', true)
            reply('Ragdoll physics ENABLED')
        elseif state == 'off' then
            TriggerClientEvent('hydra:physics:override', -1, 'ragdoll', 'enabled', false)
            reply('Ragdoll physics DISABLED')
        else
            reply('Usage: /physics ragdoll <on|off>')
        end

    elseif subCmd == 'handling' then
        -- /physics handling <on|off>
        local state = args[2]
        if state == 'on' then
            TriggerClientEvent('hydra:physics:override', -1, 'handling', 'enabled', true)
            reply('Vehicle handling overrides ENABLED')
        elseif state == 'off' then
            TriggerClientEvent('hydra:physics:override', -1, 'handling', 'enabled', false)
            reply('Vehicle handling overrides DISABLED')
        else
            reply('Usage: /physics handling <on|off>')
        end

    elseif subCmd == 'unstick' then
        -- /physics unstick [player_id]
        local targetId = tonumber(args[2])
        if not targetId and src > 0 then targetId = src end
        if not targetId then
            reply('Usage: /physics unstick [player_id]')
            return
        end
        TriggerClientEvent('hydra:physics:forceUnstick', targetId)
        local name = GetPlayerName(targetId) or 'Unknown'
        reply(('Unstuck %s (%d)'):format(name, targetId))

    elseif subCmd == 'info' then
        reply('--- Physics Configuration ---')
        reply(('Handling: %s'):format(cfg.handling.enabled and 'ON' or 'OFF'))
        reply(('  Classes configured: %d'):format(countTable(cfg.handling.classes)))
        reply(('Weight Transfer: %s (intensity: %.1f)'):format(
            cfg.weight_transfer.enabled and 'ON' or 'OFF', cfg.weight_transfer.intensity))
        reply(('Surface Traction: %s'):format(cfg.surface_traction.enabled and 'ON' or 'OFF'))
        reply(('Ragdoll: %s (player: %s, npc: %s)'):format(
            cfg.ragdoll.enabled and 'ON' or 'OFF',
            cfg.ragdoll.player and 'yes' or 'no',
            cfg.ragdoll.npc and 'yes' or 'no'))
        reply(('Rollover: %s (intensity: %.1f)'):format(
            cfg.rollover.enabled and 'ON' or 'OFF', cfg.rollover.intensity))
        reply(('Aquaplaning: %s (onset: %.0f km/h)'):format(
            cfg.aquaplaning.enabled and 'ON' or 'OFF', cfg.aquaplaning.onset_speed))
        reply(('Bogging: %s (surfaces: %d)'):format(
            cfg.bogging.enabled and 'ON' or 'OFF', countTable(cfg.bogging.surfaces)))
        reply(('Impact Events: %s'):format(cfg.impact_events.enabled and 'ON' or 'OFF'))

    else
        reply('Usage: /physics <ragdoll|handling|unstick|info>')
        reply('  ragdoll <on|off>   - Toggle ragdoll physics')
        reply('  handling <on|off>  - Toggle handling overrides')
        reply('  unstick [id]       - Unstick a bogged vehicle')
        reply('  info               - Show current configuration')
    end
end, false)

-- Utility
local function countTable(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- Server exports
exports('PhysicsSetOverride', function(section, key, value)
    TriggerClientEvent('hydra:physics:override', -1, section, key, value)
end)
