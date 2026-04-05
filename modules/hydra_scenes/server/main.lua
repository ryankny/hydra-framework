--[[
    Hydra Scenes - Server
    Module registration, admin commands, and server-side scene control.
]]

Hydra = Hydra or {}
Hydra.Scenes = Hydra.Scenes or {}

local cfg = HydraConfig.Scenes

-- ---------------------------------------------------------------------------
-- Module registration
-- ---------------------------------------------------------------------------

Hydra.Modules.Register('scenes', {
    label = 'Scene Engine',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 45,
    dependencies = { 'hydra_core' },

    onLoad = function()
        Hydra.Utils.Log('info', '[Scenes] Scene engine loaded')
    end,

    onReady = function()
        -- ── Admin command: /scene ──
        RegisterCommand('scene', function(src, args)
            if src > 0 then
                local allowed = IsPlayerAceAllowed(src, 'hydra.admin')
                if not allowed then return end
            end

            local sub = args[1]

            if sub == 'stop' then
                local target = tonumber(args[2])
                if target then
                    TriggerClientEvent('hydra:scenes:stop', target)
                    local msg = '[Scenes] Stopped scene for player ' .. target
                    if src > 0 then
                        TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Scenes', msg } })
                    else
                        print(msg)
                    end
                else
                    local msg = 'Usage: /scene stop [playerId]'
                    if src > 0 then
                        TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Scenes', msg } })
                    else
                        print(msg)
                    end
                end

            elseif sub == 'play' then
                local target = tonumber(args[2])
                local sceneName = args[3]
                if target and sceneName then
                    TriggerClientEvent('hydra:scenes:play', target, sceneName)
                    local msg = '[Scenes] Playing scene "' .. sceneName .. '" for player ' .. target
                    if src > 0 then
                        TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Scenes', msg } })
                    else
                        print(msg)
                    end
                else
                    local msg = 'Usage: /scene play [playerId] [sceneName]'
                    if src > 0 then
                        TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Scenes', msg } })
                    else
                        print(msg)
                    end
                end

            elseif sub == 'info' then
                local msg = '[Scenes] System enabled: ' .. tostring(cfg.enabled)
                    .. ' | Max concurrent: ' .. tostring(cfg.max_concurrent)
                    .. ' | Allow skip: ' .. tostring(cfg.allow_skip)
                if src > 0 then
                    TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Scenes', msg } })
                else
                    print(msg)
                end

            else
                local msg = 'Usage: /scene [play|stop|info]'
                if src > 0 then
                    TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Scenes', msg } })
                else
                    print(msg)
                end
            end
        end, true)

        -- ── Cleanup on player disconnect ──
        if cfg.cleanup_on_disconnect then
            AddEventHandler('playerDropped', function(reason)
                local src = source
                -- The client-side cleanup runs automatically via onResourceStop,
                -- but we log it server-side for auditing.
                if cfg.debug then
                    Hydra.Utils.Log('debug', '[Scenes] Player %d disconnected — client cleanup triggered', src)
                end
            end)
        end
    end,

    -- Server-side API exposed via the module system
    api = {
        PlayClient = function(targetSrc, name, data)
            if targetSrc and name then
                TriggerClientEvent('hydra:scenes:play', targetSrc, name, data)
            end
        end,
        StopClient = function(targetSrc)
            if targetSrc then
                TriggerClientEvent('hydra:scenes:stop', targetSrc)
            end
        end,
    },
})

-- ---------------------------------------------------------------------------
-- Server-side API functions (also accessible via exports)
-- ---------------------------------------------------------------------------

--- Tell a specific client to play a registered scene.
--- @param targetSrc number Player server ID
--- @param name string Scene name (must be registered on that client)
--- @param data table|nil Optional scene data
function Hydra.Scenes.PlayClient(targetSrc, name, data)
    if not targetSrc or not name then return end
    TriggerClientEvent('hydra:scenes:play', targetSrc, name, data)
end

--- Tell a specific client to stop its current scene.
--- @param targetSrc number Player server ID
function Hydra.Scenes.StopClient(targetSrc)
    if not targetSrc then return end
    TriggerClientEvent('hydra:scenes:stop', targetSrc)
end

-- ---------------------------------------------------------------------------
-- Server exports
-- ---------------------------------------------------------------------------

exports('PlayClient', function(src, name, data) return Hydra.Scenes.PlayClient(src, name, data) end)
exports('StopClient', function(src) return Hydra.Scenes.StopClient(src) end)
