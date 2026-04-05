--[[
    Hydra Object - Server

    Module registration, admin commands, and server-triggered
    object management for cross-resource coordination.
]]

Hydra = Hydra or {}
Hydra.Object = Hydra.Object or {}

local cfg = HydraConfig.Object
if not cfg.enabled then return end

-- ── Server API ──

function Hydra.Object.CreateClient(src, options)
    if not src or src <= 0 then return end
    TriggerClientEvent('hydra:object:create', src, options)
end

function Hydra.Object.CreateAll(options)
    TriggerClientEvent('hydra:object:create', -1, options)
end

function Hydra.Object.RemoveTagClient(src, tag)
    if not src or src <= 0 then return end
    TriggerClientEvent('hydra:object:removeByTag', src, tag)
end

function Hydra.Object.RemoveTagAll(tag)
    TriggerClientEvent('hydra:object:removeByTag', -1, tag)
end

function Hydra.Object.RemoveAllClient(src)
    if not src or src <= 0 then return end
    TriggerClientEvent('hydra:object:removeAll', src)
end

-- ── Admin Command ──

RegisterCommand('object', function(src, args)
    if src > 0 then
        local allowed = IsPlayerAceAllowed(src, 'hydra.admin')
        if not allowed then
            TriggerClientEvent('hydra:notify:show', src, {
                type = 'error', title = 'Object',
                message = 'No permission.', duration = 2000,
            })
            return
        end
    end

    local sub = args[1]

    if sub == 'info' then
        local msg = '[Hydra Object] Config: max=%d, max_per_owner=%d, orphan_timeout=%ds, cleanup_interval=%ds'
        print(msg:format(cfg.max_objects, cfg.max_per_owner, cfg.orphan_timeout / 1000, cfg.cleanup_interval / 1000))
        if src > 0 then
            TriggerClientEvent('hydra:notify:show', src, {
                type = 'info', title = 'Object System',
                message = ('Max: %d | Per-owner: %d | Orphan timeout: %ds'):format(
                    cfg.max_objects, cfg.max_per_owner, cfg.orphan_timeout / 1000
                ),
                duration = 5000,
            })
        end

    elseif sub == 'clear' then
        local target = tonumber(args[2])
        if target then
            TriggerClientEvent('hydra:object:removeAll', target)
            print(('[Hydra Object] Cleared all objects for player %d'):format(target))
        else
            TriggerClientEvent('hydra:object:removeAll', -1)
            print('[Hydra Object] Cleared all objects for all players')
        end

    elseif sub == 'cleartag' then
        local tag = args[2]
        if not tag then
            print('[Hydra Object] Usage: /object cleartag <tag> [playerId]')
            return
        end
        local target = tonumber(args[3]) or -1
        TriggerClientEvent('hydra:object:removeByTag', target, tag)
        print(('[Hydra Object] Cleared objects with tag "%s"'):format(tag))

    else
        local help = {
            '/object info - Show object system config',
            '/object clear [playerId] - Remove all tracked objects',
            '/object cleartag <tag> [playerId] - Remove objects by tag',
        }
        for _, line in ipairs(help) do
            if src > 0 then
                TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra Object', line } })
            else
                print(line)
            end
        end
    end
end, true)

-- ── Server events (cross-resource triggers with source validation) ──

RegisterNetEvent('hydra:object:serverCreate')
AddEventHandler('hydra:object:serverCreate', function(targetSrc, options)
    if source == 0 then return end -- Block client triggers
end)

-- ── Module Registration ──

Hydra.Modules.Register('object', {
    label = 'Object Manager',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 55,
    dependencies = { 'hydra_core' },

    onLoad = function()
        Hydra.Utils.Log('info', 'Object manager loaded')
    end,

    onReady = function()
        Hydra.Utils.Log('info', 'Object manager ready')
    end,

    api = {
        CreateClient = Hydra.Object.CreateClient,
        CreateAll = Hydra.Object.CreateAll,
        RemoveTagClient = Hydra.Object.RemoveTagClient,
        RemoveTagAll = Hydra.Object.RemoveTagAll,
        RemoveAllClient = Hydra.Object.RemoveAllClient,
    },
})

-- ── Server Exports ──

exports('CreateClient', function(...) return Hydra.Object.CreateClient(...) end)
exports('CreateAll', function(...) return Hydra.Object.CreateAll(...) end)
exports('RemoveTagClient', function(...) return Hydra.Object.RemoveTagClient(...) end)
exports('RemoveTagAll', function(...) return Hydra.Object.RemoveTagAll(...) end)
exports('RemoveAllClient', function(...) return Hydra.Object.RemoveAllClient(...) end)
