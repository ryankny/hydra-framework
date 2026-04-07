--[[
    Hydra Audio - Server Main

    Server-side audio management. Provides module registration,
    admin commands, and server-to-client audio triggers.
]]

Hydra = Hydra or {}
Hydra.Audio = Hydra.Audio or {}

-- ---------------------------------------------------------------------------
-- Server -> Client Audio Triggers
-- ---------------------------------------------------------------------------

--- Tell a specific client to play a sound
--- @param source number Player server ID
--- @param data table { type = 'frontend'|'custom'|'coord', name, soundSet, category, url, options, coords, range }
function Hydra.Audio.PlayClient(source, data)
    TriggerClientEvent('hydra:audio:playClient', source, data)
end

--- Tell all clients to play a sound
--- @param data table Same format as PlayClient
function Hydra.Audio.PlayAll(data)
    TriggerClientEvent('hydra:audio:playClient', -1, data)
end

--- Tell a specific client to stop sounds
--- @param source number Player server ID
--- @param data table|nil { soundId, category, fadeOut }
function Hydra.Audio.StopClient(source, data)
    TriggerClientEvent('hydra:audio:stopClient', source, data)
end

--- Tell all clients to stop sounds
--- @param data table|nil { category, fadeOut }
function Hydra.Audio.StopAllClients(data)
    TriggerClientEvent('hydra:audio:stopClient', -1, data)
end

-- ---------------------------------------------------------------------------
-- Admin Commands
-- ---------------------------------------------------------------------------

RegisterCommand('audio', function(source, args, rawCommand)
    -- Server console or admin check
    if source > 0 then
        if not IsPlayerAceAllowed(tostring(source), 'hydra.admin') then
            TriggerClientEvent('hydra:notify:show', source, {
                message = 'You do not have permission to use this command.',
                type = 'error',
            })
            return
        end
    end

    local subcommand = args[1]

    if subcommand == 'info' then
        local msg = '[Hydra Audio] Server audio system active. Use /audio stopall [playerId] to stop sounds.'
        if source == 0 then
            print(msg)
        else
            TriggerClientEvent('hydra:notify:show', source, {
                message = msg,
                type = 'info',
                duration = 8000,
            })
        end

    elseif subcommand == 'stopall' then
        local targetId = tonumber(args[2])

        if targetId then
            -- Stop all sounds for specific player
            Hydra.Audio.StopClient(targetId, { fadeOut = 500 })
            local msg = ('[Hydra Audio] Stopped all sounds for player %d'):format(targetId)
            if source == 0 then
                print(msg)
            else
                TriggerClientEvent('hydra:notify:show', source, {
                    message = msg,
                    type = 'success',
                })
            end
        else
            -- Stop all sounds for all players
            Hydra.Audio.StopAllClients({ fadeOut = 500 })
            local msg = '[Hydra Audio] Stopped all sounds for all players.'
            if source == 0 then
                print(msg)
            else
                TriggerClientEvent('hydra:notify:show', source, {
                    message = msg,
                    type = 'success',
                })
            end
        end

    else
        local usage = '[Hydra Audio] Usage: /audio info | /audio stopall [playerId]'
        if source == 0 then
            print(usage)
        else
            TriggerClientEvent('hydra:notify:show', source, {
                message = usage,
                type = 'info',
                duration = 8000,
            })
        end
    end
end, true) -- restricted = true, ACE permission based

-- ---------------------------------------------------------------------------
-- Server Events (cross-resource triggers)
-- ---------------------------------------------------------------------------

--- Allow other server scripts to trigger client audio via event
RegisterNetEvent('hydra:audio:playClient')
AddEventHandler('hydra:audio:playClient', function(target, data)
    -- Only accept from server context (source == 0)
    if source ~= 0 then return end
    if target == -1 then
        Hydra.Audio.PlayAll(data)
    else
        Hydra.Audio.PlayClient(target, data)
    end
end)

RegisterNetEvent('hydra:audio:stopClient')
AddEventHandler('hydra:audio:stopClient', function(target, data)
    if source ~= 0 then return end
    if target == -1 then
        Hydra.Audio.StopAllClients(data)
    else
        Hydra.Audio.StopClient(target, data)
    end
end)

-- ---------------------------------------------------------------------------
-- Module Registration
-- ---------------------------------------------------------------------------

Hydra.Modules.Register('audio', {
    label = 'Audio System',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 60,
    dependencies = { 'hydra_core' },

    onLoad = function()
        Hydra.Utils.Log('info', 'Audio system loaded')
    end,

    onReady = function()
        Hydra.Utils.Log('info', 'Audio system ready')
    end,

    api = {
        PlayClient = Hydra.Audio.PlayClient,
        PlayAll = Hydra.Audio.PlayAll,
        StopClient = Hydra.Audio.StopClient,
        StopAllClients = Hydra.Audio.StopAllClients,
    },
})

-- ---------------------------------------------------------------------------
-- Exports (server-side)
-- ---------------------------------------------------------------------------

exports('PlayClient', function(...) return Hydra.Audio.PlayClient(...) end)
exports('PlayAll', function(...) return Hydra.Audio.PlayAll(...) end)
exports('StopClient', function(...) return Hydra.Audio.StopClient(...) end)
exports('StopAllClients', function(...) return Hydra.Audio.StopAllClients(...) end)
