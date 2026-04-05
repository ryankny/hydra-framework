--[[
    Hydra NPC - Server

    Module registration, admin commands, and server-triggered
    NPC management for cross-resource coordination.
]]

Hydra = Hydra or {}
Hydra.NPC = Hydra.NPC or {}

local cfg = HydraConfig.NPC
if not cfg.enabled then return end

-- ── Server API ──

function Hydra.NPC.CreateClient(src, options)
    if not src or src <= 0 then return end
    TriggerClientEvent('hydra:npc:create', src, options)
end

function Hydra.NPC.CreateAll(options)
    TriggerClientEvent('hydra:npc:create', -1, options)
end

function Hydra.NPC.RemoveClient(src, tag)
    if not src or src <= 0 then return end
    if tag then
        TriggerClientEvent('hydra:npc:removeByTag', src, tag)
    else
        TriggerClientEvent('hydra:npc:removeAll', src)
    end
end

function Hydra.NPC.RemoveAll(tag)
    if tag then
        TriggerClientEvent('hydra:npc:removeByTag', -1, tag)
    else
        TriggerClientEvent('hydra:npc:removeAll', -1)
    end
end

-- ── Admin Command ──

RegisterCommand('npc', function(src, args)
    if src > 0 then
        local allowed = IsPlayerAceAllowed(src, 'hydra.admin')
        if not allowed then
            TriggerClientEvent('hydra:notify:show', src, {
                type = 'error', title = 'NPC',
                message = 'No permission.', duration = 2000,
            })
            return
        end
    end

    local sub = args[1]

    if sub == 'info' then
        local msg = '[Hydra NPC] Config: max=%d, spawn_dist=%.0f, despawn_dist=%.0f, proximity=%s'
        print(msg:format(cfg.max_npcs, cfg.spawn_distance, cfg.despawn_distance,
            tostring(cfg.enable_proximity_spawning)))
        if src > 0 then
            TriggerClientEvent('hydra:notify:show', src, {
                type = 'info', title = 'NPC System',
                message = ('Max: %d | Spawn dist: %.0f | Proximity: %s'):format(
                    cfg.max_npcs, cfg.spawn_distance, tostring(cfg.enable_proximity_spawning)
                ),
                duration = 5000,
            })
        end

    elseif sub == 'clear' then
        local target = tonumber(args[2])
        if target then
            TriggerClientEvent('hydra:npc:removeAll', target)
            print(('[Hydra NPC] Cleared all NPCs for player %d'):format(target))
        else
            TriggerClientEvent('hydra:npc:removeAll', -1)
            print('[Hydra NPC] Cleared all NPCs for all players')
        end

    elseif sub == 'cleartag' then
        local tag = args[2]
        if not tag then
            print('[Hydra NPC] Usage: /npc cleartag <tag> [playerId]')
            return
        end
        local target = tonumber(args[3]) or -1
        TriggerClientEvent('hydra:npc:removeByTag', target, tag)
        print(('[Hydra NPC] Cleared NPCs with tag "%s"'):format(tag))

    else
        local help = {
            '/npc info - Show NPC system config',
            '/npc clear [playerId] - Remove all managed NPCs',
            '/npc cleartag <tag> [playerId] - Remove NPCs by tag',
        }
        for _, line in ipairs(help) do
            if src > 0 then
                TriggerClientEvent('chat:addMessage', src, { args = { 'Hydra NPC', line } })
            else
                print(line)
            end
        end
    end
end, true)

-- ── Module Registration ──

Hydra.Modules.Register('npc', {
    label = 'NPC Manager',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 55,
    dependencies = { 'hydra_core' },

    onLoad = function()
        Hydra.Utils.Log('info', 'NPC manager loaded')
    end,

    onReady = function()
        Hydra.Utils.Log('info', 'NPC manager ready')
    end,

    api = {
        CreateClient = Hydra.NPC.CreateClient,
        CreateAll = Hydra.NPC.CreateAll,
        RemoveClient = Hydra.NPC.RemoveClient,
        RemoveAll = Hydra.NPC.RemoveAll,
    },
})

-- ── Server Exports ──

exports('CreateClient', function(...) return Hydra.NPC.CreateClient(...) end)
exports('CreateAll', function(...) return Hydra.NPC.CreateAll(...) end)
exports('RemoveClient', function(...) return Hydra.NPC.RemoveClient(...) end)
exports('RemoveAll', function(...) return Hydra.NPC.RemoveAll(...) end)
