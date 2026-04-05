--[[
    Hydra Interact - Server
    Module registration and admin commands.
]]

Hydra = Hydra or {}

local cfg = HydraConfig.Interact

Hydra.Modules.Register('interact', {
    label = 'Interaction System',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 55,
    dependencies = { 'hydra_core' },

    onLoad = function()
        Hydra.Utils.Log('info', '[Interact] Interaction system loaded')
    end,

    onReady = function()
        RegisterCommand('interact', function(src, args)
            if src > 0 then
                local allowed = IsPlayerAceAllowed(src, 'hydra.admin')
                if not allowed then return end
            end

            local sub = args[1]
            if sub == 'info' then
                local msg = '[Interact] System enabled: ' .. tostring(cfg.enabled)
                    .. ' | Use target: ' .. tostring(cfg.use_target)
                    .. ' | Use zones: ' .. tostring(cfg.use_zones)
                    .. ' | Max points: ' .. tostring(cfg.max_active_points)
                    .. ' | Cooldown: ' .. tostring(cfg.cooldown) .. 'ms'
                if src > 0 then
                    TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Interact', msg } })
                else
                    print(msg)
                end
            else
                local msg = 'Usage: /interact [info]'
                if src > 0 then
                    TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Interact', msg } })
                else
                    print(msg)
                end
            end
        end, true)

        -- Server-initiated interaction trigger
        RegisterNetEvent('hydra:interact:serverTrigger')
        AddEventHandler('hydra:interact:serverTrigger', function(targetSrc, interactId)
            local src = source
            if src > 0 then
                local allowed = IsPlayerAceAllowed(src, 'hydra.admin')
                if not allowed then return end
            end
            if targetSrc and interactId then
                TriggerClientEvent('hydra:interact:trigger', targetSrc, interactId)
            end
        end)

        -- Override config for player
        RegisterNetEvent('hydra:interact:setOverride')
        AddEventHandler('hydra:interact:setOverride', function(targetSrc, key, value)
            local src = source
            if src > 0 then
                local allowed = IsPlayerAceAllowed(src, 'hydra.admin')
                if not allowed then return end
            end
            if targetSrc and key then
                TriggerClientEvent('hydra:interact:override', targetSrc, key, value)
            end
        end)
    end,

    api = {
        TriggerForPlayer = function(targetSrc, interactId)
            TriggerClientEvent('hydra:interact:trigger', targetSrc, interactId)
        end,
    },
})
