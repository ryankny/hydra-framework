--[[
    Hydra Anims - Server

    Module registration, admin commands, server-triggered
    animation events, and optional sync state tracking.
]]

Hydra = Hydra or {}
Hydra.Anims = Hydra.Anims or {}

local cfg = HydraConfig.Anims

-- =============================================
-- SYNC STATE TRACKING
-- =============================================

-- { [source] = { animId, dict, anim, label, timestamp } | nil }
local playerAnimState = {}

-- =============================================
-- SYNC EVENT
-- =============================================

RegisterNetEvent('hydra:anims:syncState')
AddEventHandler('hydra:anims:syncState', function(state)
    local src = source
    if not src or src <= 0 then return end

    if not cfg.sync_to_server then return end

    if state then
        playerAnimState[src] = {
            animId = state.animId,
            dict = state.dict,
            anim = state.anim,
            scenario = state.scenario,
            label = state.label,
            timestamp = os.time(),
        }
    else
        playerAnimState[src] = nil
    end
end)

-- =============================================
-- SERVER API
-- =============================================

--- Get animation state for a player (requires sync_to_server)
--- @param src number
--- @return table|nil
function Hydra.Anims.GetPlayerState(src)
    return playerAnimState[src]
end

--- Check if a player is playing an animation (requires sync_to_server)
--- @param src number
--- @return boolean
function Hydra.Anims.IsPlaying(src)
    return playerAnimState[src] ~= nil
end

--- Trigger animation on a player from server
--- @param src number player source
--- @param options table animation options (same as client Play)
function Hydra.Anims.Play(src, options)
    if not src or src <= 0 or not options then return end
    TriggerClientEvent('hydra:anims:play', src, options)
end

--- Stop animation on a player from server
--- @param src number player source
--- @param animId string|nil (nil stops all)
--- @param blendOut number|nil
function Hydra.Anims.Stop(src, animId, blendOut)
    if not src or src <= 0 then return end
    TriggerClientEvent('hydra:anims:stop', src, animId, blendOut)
end

--- Stop all animations on a player from server
--- @param src number player source
--- @param blendOut number|nil
function Hydra.Anims.StopAll(src, blendOut)
    if not src or src <= 0 then return end
    TriggerClientEvent('hydra:anims:stop', src, nil, blendOut)
end

-- =============================================
-- ADMIN COMMANDS
-- =============================================

RegisterCommand('anims', function(src, args)
    -- Permission check for players (console always allowed)
    if src > 0 and not IsPlayerAceAllowed(src, 'hydra.admin') then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'error', title = 'No Permission',
            message = 'You do not have permission to use this command.',
        })
        return
    end

    local subcommand = args[1]

    if subcommand == 'info' then
        -- Show active animation count and sync state stats
        local activeCount = 0
        for _ in pairs(playerAnimState) do activeCount = activeCount + 1 end

        local playerCount = #GetPlayers()

        local msg = ('[Hydra Anims] Sync tracking: %s | Tracked players: %d/%d'):format(
            cfg.sync_to_server and 'enabled' or 'disabled',
            activeCount,
            playerCount
        )

        if src > 0 then
            TriggerClientEvent('hydra:notify:show', src, {
                type = 'info', title = 'Animation Manager',
                message = msg,
                duration = 5000,
            })
            -- Also send details in chat
            TriggerClientEvent('chat:addMessage', src, {
                color = { 108, 92, 231 },
                args = { 'Hydra Anims', msg },
            })
        else
            print(msg)
        end

        -- List active states if sync is on
        if cfg.sync_to_server then
            for playerId, state in pairs(playerAnimState) do
                local detail = ('  Player %d: %s (id=%s, since=%s)'):format(
                    playerId,
                    state.label or state.dict or state.scenario or 'unknown',
                    state.animId or '?',
                    os.date('%H:%M:%S', state.timestamp)
                )
                if src > 0 then
                    TriggerClientEvent('chat:addMessage', src, {
                        args = { '', detail },
                    })
                else
                    print(detail)
                end
            end
        end

    elseif subcommand == 'stop' then
        local targetId = tonumber(args[2])
        if not targetId then
            local usage = 'Usage: /anims stop [playerId]'
            if src > 0 then
                TriggerClientEvent('chat:addMessage', src, {
                    color = { 231, 76, 60 },
                    args = { 'Hydra Anims', usage },
                })
            else
                print('[Hydra Anims] ' .. usage)
            end
            return
        end

        -- Validate target exists
        local targetName = GetPlayerName(targetId)
        if not targetName then
            local errMsg = ('Player %d not found'):format(targetId)
            if src > 0 then
                TriggerClientEvent('hydra:notify:show', src, {
                    type = 'error', title = 'Animation Manager',
                    message = errMsg,
                })
            else
                print('[Hydra Anims] ' .. errMsg)
            end
            return
        end

        -- Send stop to client
        Hydra.Anims.StopAll(targetId)

        -- Clear sync state
        playerAnimState[targetId] = nil

        local successMsg = ('Stopped all animations on %s (%d)'):format(targetName, targetId)
        if src > 0 then
            TriggerClientEvent('hydra:notify:show', src, {
                type = 'success', title = 'Animation Manager',
                message = successMsg,
                duration = 3000,
            })
        end

        local adminName = src > 0 and GetPlayerName(src) or 'Console'
        if Hydra.Utils and Hydra.Utils.Log then
            Hydra.Utils.Log('info', '%s force-stopped animations on player %d (%s)', adminName, targetId, targetName)
        else
            print(('[Hydra Anims] %s force-stopped animations on player %d (%s)'):format(adminName, targetId, targetName))
        end

    else
        local helpMsg = 'Usage: /anims info | /anims stop [playerId]'
        if src > 0 then
            TriggerClientEvent('chat:addMessage', src, {
                color = { 108, 92, 231 },
                args = { 'Hydra Anims', helpMsg },
            })
        else
            print('[Hydra Anims] ' .. helpMsg)
        end
    end
end, false)

-- =============================================
-- MODULE REGISTRATION
-- =============================================

Hydra.Modules.Register('anims', {
    label = 'Animation Manager',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 60,
    dependencies = { 'hydra_core' },

    onLoad = function()
        if Hydra.Utils and Hydra.Utils.Log then
            Hydra.Utils.Log('info', 'Animation Manager module loaded')
        else
            print('[Hydra Anims] Animation Manager module loaded')
        end
    end,

    onPlayerDrop = function(src)
        playerAnimState[src] = nil
    end,

    api = {
        GetPlayerState = function(...) return Hydra.Anims.GetPlayerState(...) end,
        IsPlaying = function(...) return Hydra.Anims.IsPlaying(...) end,
        Play = function(...) Hydra.Anims.Play(...) end,
        Stop = function(...) Hydra.Anims.Stop(...) end,
        StopAll = function(...) Hydra.Anims.StopAll(...) end,
    },
})

-- =============================================
-- SERVER EXPORTS
-- =============================================

exports('GetPlayerState', function(src) return Hydra.Anims.GetPlayerState(src) end)
exports('ServerIsPlaying', function(src) return Hydra.Anims.IsPlaying(src) end)
exports('ServerPlay', function(src, options) Hydra.Anims.Play(src, options) end)
exports('ServerStop', function(src, animId, blendOut) Hydra.Anims.Stop(src, animId, blendOut) end)
exports('ServerStopAll', function(src, blendOut) Hydra.Anims.StopAll(src, blendOut) end)
