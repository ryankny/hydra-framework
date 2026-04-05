--[[
    Hydra Camera - Server
    Module registration and admin commands.
]]

Hydra = Hydra or {}

local cfg = HydraConfig.Camera

Hydra.Modules.Register('camera', {
    label = 'Camera System',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 60,
    dependencies = { 'hydra_core' },

    onLoad = function()
        Hydra.Utils.Log('info', '[Camera] Camera system loaded')
    end,

    onReady = function()
        -- Admin command
        RegisterCommand('camera', function(src, args)
            if src > 0 then
                local allowed = IsPlayerAceAllowed(src, 'hydra.admin')
                if not allowed then return end
            end

            local sub = args[1]
            if sub == 'info' then
                local msg = '[Camera] System enabled: ' .. tostring(cfg.enabled)
                    .. ' | Max cameras: ' .. tostring(cfg.max_active_cameras)
                    .. ' | Default FOV: ' .. tostring(cfg.default_fov)
                if src > 0 then
                    TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Camera', msg } })
                else
                    print(msg)
                end

            elseif sub == 'reset' then
                local target = tonumber(args[2])
                if target then
                    TriggerClientEvent('hydra:camera:destroy', target)
                    local msg = '[Camera] Reset cameras for player ' .. target
                    if src > 0 then
                        TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Camera', msg } })
                    else
                        print(msg)
                    end
                else
                    local msg = 'Usage: /camera reset [playerId]'
                    if src > 0 then
                        TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Camera', msg } })
                    else
                        print(msg)
                    end
                end

            else
                local msg = 'Usage: /camera [info|reset]'
                if src > 0 then
                    TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Camera', msg } })
                else
                    print(msg)
                end
            end
        end, true)

        -- Server-triggered camera creation
        RegisterNetEvent('hydra:camera:requestCreate')
        AddEventHandler('hydra:camera:requestCreate', function(targetSrc, data)
            local src = source
            if src > 0 then
                local allowed = IsPlayerAceAllowed(src, 'hydra.admin')
                if not allowed then return end
            end
            if targetSrc and data then
                TriggerClientEvent('hydra:camera:create', targetSrc, data)
            end
        end)

        -- Server-triggered orbit
        RegisterNetEvent('hydra:camera:requestOrbit')
        AddEventHandler('hydra:camera:requestOrbit', function(targetSrc, data)
            local src = source
            if src > 0 then
                local allowed = IsPlayerAceAllowed(src, 'hydra.admin')
                if not allowed then return end
            end
            if targetSrc and data then
                TriggerClientEvent('hydra:camera:orbit', targetSrc, data)
            end
        end)

        -- Override config value for a player
        RegisterNetEvent('hydra:camera:setOverride')
        AddEventHandler('hydra:camera:setOverride', function(targetSrc, key, value)
            local src = source
            if src > 0 then
                local allowed = IsPlayerAceAllowed(src, 'hydra.admin')
                if not allowed then return end
            end
            if targetSrc and key then
                TriggerClientEvent('hydra:camera:override', targetSrc, key, value)
            end
        end)
    end,

    api = {
        CreateForPlayer = function(targetSrc, data)
            TriggerClientEvent('hydra:camera:create', targetSrc, data)
        end,
        DestroyForPlayer = function(targetSrc)
            TriggerClientEvent('hydra:camera:destroy', targetSrc)
        end,
        OrbitForPlayer = function(targetSrc, data)
            TriggerClientEvent('hydra:camera:orbit', targetSrc, data)
        end,
    },
})
