--[[
    Hydra Framework - Keybind System (Server)

    Server-side component for the keybind management system.
    Handles module registration, admin info commands, and
    server-driven keybind disable/enable for players.
]]

Hydra = Hydra or {}

local isServer = IsDuplicityVersion()
if not isServer then return end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local config = nil

--- Lazy-load config
--- @return table
local function GetConfig()
    if not config then
        config = HydraConfig and HydraConfig.Keybinds or {}
    end
    return config
end

--- Info log helper
--- @param msg string
--- @vararg any
local function InfoLog(msg, ...)
    if Hydra.Utils and Hydra.Utils.Log then
        Hydra.Utils.Log('info', '[Keybinds] ' .. msg, ...)
    else
        print(string.format('[HYDRA][INFO][Keybinds] ' .. msg, ...))
    end
end

--- Debug log helper
--- @param msg string
--- @vararg any
local function DebugLog(msg, ...)
    local cfg = GetConfig()
    if cfg.debug then
        if Hydra.Utils and Hydra.Utils.Log then
            Hydra.Utils.Log('debug', '[Keybinds] ' .. msg, ...)
        else
            print(string.format('[HYDRA][DEBUG][Keybinds] ' .. msg, ...))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Admin command: /keybinds info
-- ---------------------------------------------------------------------------

RegisterCommand('keybinds', function(source, args)
    if source ~= 0 then
        -- Player-issued command on server side; the client handles the list.
        -- Only handle 'info' subcommand on server for admin use.
        if args[1] == 'info' then
            -- Check if player has admin permissions
            local isAdmin = false
            if Hydra.Utils and Hydra.Utils.IsPlayerAdmin then
                isAdmin = Hydra.Utils.IsPlayerAdmin(source)
            else
                -- Fallback: check for ace permission
                isAdmin = IsPlayerAceAllowed(source, 'hydra.admin')
            end

            if not isAdmin then
                TriggerClientEvent('chat:addMessage', source, {
                    args = { '^1[HYDRA]', 'You do not have permission to use this command.' }
                })
                return
            end

            -- Gather info from the requesting player's client
            TriggerClientEvent('chat:addMessage', source, {
                args = { '^5[HYDRA]', 'Keybind system v1.0.0 is active. Use /keybinds in-game to list all bindings.' }
            })
        end
        return
    end

    -- Console command
    if args[1] == 'info' then
        InfoLog('Keybind system v1.0.0 is active on server.')
        InfoLog('Keybind registration and management runs client-side.')
        InfoLog('Use "keybinds disable <player_id>" to disable keybinds for a player.')
        InfoLog('Use "keybinds enable <player_id>" to re-enable keybinds for a player.')
    elseif args[1] == 'disable' then
        local targetId = tonumber(args[2])
        if not targetId then
            print('[HYDRA][Keybinds] Usage: keybinds disable <player_id>')
            return
        end
        TriggerClientEvent('hydra_keybinds:client:setDisabled', targetId, true)
        InfoLog('Disabled keybinds for player %d', targetId)
    elseif args[1] == 'enable' then
        local targetId = tonumber(args[2])
        if not targetId then
            print('[HYDRA][Keybinds] Usage: keybinds enable <player_id>')
            return
        end
        TriggerClientEvent('hydra_keybinds:client:setDisabled', targetId, false)
        InfoLog('Enabled keybinds for player %d', targetId)
    else
        print('[HYDRA][Keybinds] Server commands:')
        print('  keybinds info              - Show system status')
        print('  keybinds disable <id>      - Disable all keybinds for a player')
        print('  keybinds enable <id>       - Re-enable keybinds for a player')
    end
end, true) -- Restricted: requires ace permission for non-console

-- ---------------------------------------------------------------------------
-- Server event: disable/enable keybinds for a specific player
-- ---------------------------------------------------------------------------

--- Disable all keybinds for a player (callable from other server scripts)
--- @param playerId number
function Hydra.Keybinds_DisableForPlayer(playerId)
    if not playerId then return end
    TriggerClientEvent('hydra_keybinds:client:setDisabled', playerId, true)
    DebugLog('Server disabled keybinds for player %d', playerId)
end

--- Enable all keybinds for a player (callable from other server scripts)
--- @param playerId number
function Hydra.Keybinds_EnableForPlayer(playerId)
    if not playerId then return end
    TriggerClientEvent('hydra_keybinds:client:setDisabled', playerId, false)
    DebugLog('Server enabled keybinds for player %d', playerId)
end

-- ---------------------------------------------------------------------------
-- Module registration (server-side)
-- ---------------------------------------------------------------------------

CreateThread(function()
    -- Wait for hydra_core to be ready
    while not Hydra.Modules or not Hydra.Modules.Register do
        Wait(100)
    end

    Hydra.Modules.Register('keybinds', {
        label = 'Keybind System',
        version = '1.0.0',
        author = 'Hydra Framework',
        priority = 70,
        dependencies = { 'hydra_core' },

        api = {
            DisableForPlayer = Hydra.Keybinds_DisableForPlayer,
            EnableForPlayer = Hydra.Keybinds_EnableForPlayer,
        },

        onLoad = function()
            DebugLog('Keybind system server component loading')
        end,

        onReady = function()
            InfoLog('Keybind system server component ready')
        end,

        onUnload = function()
            InfoLog('Keybind system server component unloaded')
        end,
    })
end)
