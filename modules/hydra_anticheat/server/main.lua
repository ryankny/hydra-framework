--[[
    Hydra AntiCheat - Server Main

    Core engine: player state tracking, strike system, ban management,
    detection dispatch, exemption checks, logging, and admin commands.
    All enforcement is server-authoritative — client reports are validated.
]]

Hydra = Hydra or {}
Hydra.AntiCheat = Hydra.AntiCheat or {}

-- ---------------------------------------------------------------------------
-- Localise globals for performance
-- ---------------------------------------------------------------------------
local cfg = HydraConfig.AntiCheat

local os_time = os.time
local os_clock = os.clock
local string_format = string.format
local string_lower = string.lower
local table_insert = table.insert
local table_remove = table.remove
local math_floor = math.floor
local GetPlayerName = GetPlayerName
local GetPlayerPed = GetPlayerPed
local DropPlayer = DropPlayer
local IsPlayerAceAllowed = IsPlayerAceAllowed
local GetNumPlayerIdentifiers = GetNumPlayerIdentifiers
local GetPlayerIdentifier = GetPlayerIdentifier
local GetEntityCoords = GetEntityCoords

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------

local players = {}              -- [src] = { identifiers, strikes, history, state, ... }
local bans = {}                 -- [identifier] = { reason, expires, by, timestamp }
local detectionHandlers = {}    -- [module] = handler function
local globalHooks = {
    onDetection = {},           -- Called for every detection
    onBan = {},                 -- Called when a player is banned
    onKick = {},                -- Called when a player is kicked
}
local moduleEnabled = {}        -- [module] = bool, runtime toggles

-- Initialise module enabled states from config
for _, mod in ipairs({'events','resources','movement','godmode','weapons','entities','explosions','spectate','particles','ped_flags'}) do
    if cfg[mod] then
        moduleEnabled[mod] = cfg[mod].enabled ~= false
    end
end

-- ---------------------------------------------------------------------------
-- Identifier helpers
-- ---------------------------------------------------------------------------

local function getIdentifiers(src)
    local ids = {}
    local n = GetNumPlayerIdentifiers(src)
    for i = 0, n - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id then
            local prefix = id:match('^([^:]+):')
            if prefix then
                ids[prefix] = id
            end
            ids[#ids + 1] = id
        end
    end
    return ids
end

local function getPrimaryIdentifier(ids)
    return ids['license'] or ids['license2'] or ids['steam'] or ids['discord'] or ids[1] or 'unknown'
end

-- ---------------------------------------------------------------------------
-- Logging
-- ---------------------------------------------------------------------------

local function log(level, message, src)
    if not cfg.logging.enabled then return end
    local tag = src and string_format('[AC] [%s:%s]', src, GetPlayerName(src) or '?') or '[AC]'
    local line = string_format('%s [%s] %s', tag, level, message)

    if cfg.logging.console then
        if level == 'CRITICAL' or level == 'BAN' then
            print('^1' .. line .. '^0')
        elseif level == 'WARN' then
            print('^3' .. line .. '^0')
        elseif level == 'DEBUG' and cfg.debug then
            print('^5' .. line .. '^0')
        else
            print(line)
        end
    end

    -- hydra_logs integration
    pcall(function()
        exports['hydra_logs']:Send(cfg.logging.channel, {
            title = string_format('AntiCheat — %s', level),
            description = message,
            source = src,
            fields = src and {
                { name = 'Player', value = GetPlayerName(src) or 'Unknown', inline = true },
                { name = 'Server ID', value = tostring(src), inline = true },
            } or nil,
        })
    end)
end

local function logDetection(src, module, reason, severity, data)
    local p = players[src]
    if not p then return end

    local entry = {
        module = module,
        reason = reason,
        severity = severity,
        timestamp = os_time(),
        data = data,
    }

    -- Store in player history
    table_insert(p.history, entry)
    if #p.history > (cfg.logging.history_limit or 50) then
        table_remove(p.history, 1)
    end

    log('DETECTION', string_format('[%s] %s (severity %d)', module, reason, severity), src)

    -- Fire global hooks
    for _, fn in ipairs(globalHooks.onDetection) do
        pcall(fn, src, module, reason, severity, data)
    end
end

-- ---------------------------------------------------------------------------
-- Exemption checks
-- ---------------------------------------------------------------------------

local function isExempt(src, module)
    if not src or not players[src] then return true end

    -- ACE permission check
    if IsPlayerAceAllowed(src, cfg.exemptions.ace_permission) then
        local exemptMods = cfg.exemptions.admin_exempt or {}
        for _, m in ipairs(exemptMods) do
            if m == 'all' or m == module then return true end
        end
    end

    return false
end

-- ---------------------------------------------------------------------------
-- Strike system
-- ---------------------------------------------------------------------------

local function addStrike(src, module, reason, severity)
    local p = players[src]
    if not p then return 0 end

    local now = os_time()

    -- Decay old strikes
    if cfg.strikes.enabled and cfg.strikes.decay_time > 0 then
        local fresh = {}
        for _, s in ipairs(p.strikes) do
            if (now - s.time) < cfg.strikes.decay_time then
                fresh[#fresh + 1] = s
            end
        end
        p.strikes = fresh
    end

    -- Add new strike (severity acts as weight)
    local weight = severity or 1
    for _ = 1, weight do
        table_insert(p.strikes, { module = module, reason = reason, time = now })
    end

    return #p.strikes
end

-- ---------------------------------------------------------------------------
-- Punishment actions
-- ---------------------------------------------------------------------------

local function executeBan(src, reason, duration, module)
    local p = players[src]
    if not p then return end

    local identifier = getPrimaryIdentifier(p.identifiers)
    local now = os_time()
    local expires = (duration and duration > 0) and (now + duration) or 0

    -- Store ban for all identifiers
    for _, id in ipairs(p.identifiers) do
        if type(id) == 'string' then
            bans[id] = {
                reason = reason,
                expires = expires,
                by = 'AntiCheat',
                timestamp = now,
                module = module,
                playerName = GetPlayerName(src) or 'Unknown',
            }
        end
    end

    -- Persist ban via hydra_data if available
    pcall(function()
        exports['hydra_data']:Insert('anticheat_bans', {
            identifier = identifier,
            all_identifiers = p.identifiers,
            reason = reason,
            module = module,
            expires = expires,
            timestamp = now,
            playerName = GetPlayerName(src) or 'Unknown',
        })
    end)

    log('BAN', string_format('%s — %s (duration: %s)', reason, module or 'unknown',
        expires == 0 and 'permanent' or (duration .. 's')), src)

    for _, fn in ipairs(globalHooks.onBan) do
        pcall(fn, src, reason, module, duration)
    end

    -- Screenshot before drop
    if cfg.ban.screenshot_on_ban then
        pcall(function() exports['screenshot-basic']:requestServerScreenshot(src, {}) end)
    end

    Wait(100)
    DropPlayer(src, cfg.ban.message or 'You have been banned.')
end

local function executeKick(src, reason, module)
    log('KICK', string_format('%s — %s', reason, module or 'unknown'), src)

    for _, fn in ipairs(globalHooks.onKick) do
        pcall(fn, src, reason, module)
    end

    if cfg.strikes.reset_on_kick then
        local p = players[src]
        if p then p.strikes = {} end
    end

    DropPlayer(src, reason)
end

local function executeWarn(src, reason, module)
    log('WARN', string_format('%s — %s', reason, module or 'unknown'), src)
    TriggerClientEvent('hydra:anticheat:warn', src, reason)
end

-- ---------------------------------------------------------------------------
-- Central detection handler — ALL detections flow through here
-- ---------------------------------------------------------------------------

function Hydra.AntiCheat.Flag(src, module, reason, severity, action, data)
    if not cfg.enabled then return end
    if not src or src <= 0 then return end
    if isExempt(src, module) then return end
    if moduleEnabled[module] == false then return end

    severity = severity or 1
    action = action or 'log'

    logDetection(src, module, reason, severity, data)

    -- Strike system
    if cfg.strikes.enabled then
        local totalStrikes = addStrike(src, module, reason, severity)
        if totalStrikes >= cfg.strikes.threshold then
            log('CRITICAL', string_format('Strike threshold reached (%d/%d)', totalStrikes, cfg.strikes.threshold), src)
            executeBan(src, 'Strike threshold exceeded — ' .. reason, cfg.ban.default_duration, module)
            return
        end
    end

    -- Execute configured action
    if action == 'ban' then
        executeBan(src, reason, cfg.ban.default_duration, module)
    elseif action == 'kick' then
        executeKick(src, reason, module)
    elseif action == 'warn' then
        executeWarn(src, reason, module)
    end
    -- 'log' = already logged above, no further action
end

-- ---------------------------------------------------------------------------
-- Ban check on join
-- ---------------------------------------------------------------------------

local function checkBanOnJoin(src, deferrals)
    local ids = getIdentifiers(src)

    -- Check in-memory bans
    for _, id in ipairs(ids) do
        if type(id) == 'string' then
            local ban = bans[id]
            if ban then
                if ban.expires == 0 or ban.expires > os_time() then
                    deferrals.done(cfg.ban.message)
                    return true
                else
                    bans[id] = nil  -- Expired
                end
            end
        end
    end

    -- Check persisted bans via hydra_data
    local banned = false
    pcall(function()
        for _, id in ipairs(ids) do
            if type(id) == 'string' then
                local results = exports['hydra_data']:Find('anticheat_bans', { identifier = id })
                if results and #results > 0 then
                    local ban = results[1]
                    if ban.expires == 0 or ban.expires > os_time() then
                        deferrals.done(cfg.ban.message)
                        banned = true
                        return
                    end
                end
            end
        end
    end)

    return banned
end

-- ---------------------------------------------------------------------------
-- Player lifecycle
-- ---------------------------------------------------------------------------

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update('Checking anti-cheat...')

    if checkBanOnJoin(src, deferrals) then return end

    -- Initialise player state
    players[src] = {
        identifiers = getIdentifiers(src),
        strikes = {},
        history = {},
        state = {
            lastPos = nil,
            lastPosTime = 0,
            health = 200,
            armour = 0,
            spawnTime = os_clock(),
            damageTaken = 0,
            damageIgnored = 0,
            weaponFired = {},
            entityCount = { peds = 0, vehicles = 0, objects = 0 },
        },
        joinTime = os_time(),
    }

    deferrals.done()
    log('DEBUG', 'Player passed anti-cheat check', src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    players[src] = nil
end)

-- Also handle late joins (if playerConnecting was missed)
RegisterNetEvent('hydra:anticheat:client:ready', function()
    local src = source
    if not players[src] then
        players[src] = {
            identifiers = getIdentifiers(src),
            strikes = {},
            history = {},
            state = {
                lastPos = nil,
                lastPosTime = 0,
                health = 200,
                armour = 0,
                spawnTime = os_clock(),
                damageTaken = 0,
                damageIgnored = 0,
                weaponFired = {},
                entityCount = { peds = 0, vehicles = 0, objects = 0 },
            },
            joinTime = os_time(),
        }
    end
end)

-- ---------------------------------------------------------------------------
-- Player state getters (used by detection modules)
-- ---------------------------------------------------------------------------

function Hydra.AntiCheat.GetPlayer(src)
    return players[src]
end

function Hydra.AntiCheat.GetPlayerState(src)
    local p = players[src]
    return p and p.state or nil
end

function Hydra.AntiCheat.SetPlayerState(src, key, value)
    local p = players[src]
    if p then p.state[key] = value end
end

function Hydra.AntiCheat.GetAllPlayers()
    return players
end

-- ---------------------------------------------------------------------------
-- Runtime module toggling
-- ---------------------------------------------------------------------------

function Hydra.AntiCheat.EnableModule(module)
    moduleEnabled[module] = true
    log('INFO', string_format('Module "%s" enabled', module))
end

function Hydra.AntiCheat.DisableModule(module)
    moduleEnabled[module] = false
    log('INFO', string_format('Module "%s" disabled', module))
end

function Hydra.AntiCheat.IsModuleEnabled(module)
    return moduleEnabled[module] ~= false
end

-- ---------------------------------------------------------------------------
-- Hook registration
-- ---------------------------------------------------------------------------

function Hydra.AntiCheat.OnDetection(fn)
    if type(fn) == 'function' then globalHooks.onDetection[#globalHooks.onDetection + 1] = fn end
end

function Hydra.AntiCheat.OnBan(fn)
    if type(fn) == 'function' then globalHooks.onBan[#globalHooks.onBan + 1] = fn end
end

function Hydra.AntiCheat.OnKick(fn)
    if type(fn) == 'function' then globalHooks.onKick[#globalHooks.onKick + 1] = fn end
end

-- ---------------------------------------------------------------------------
-- Manual admin actions
-- ---------------------------------------------------------------------------

function Hydra.AntiCheat.Ban(src, reason, duration)
    if not src or not players[src] then return false end
    executeBan(src, reason or 'Manual ban', duration or cfg.ban.default_duration, 'admin')
    return true
end

function Hydra.AntiCheat.Unban(identifier)
    bans[identifier] = nil
    local removed = false
    pcall(function()
        exports['hydra_data']:Delete('anticheat_bans', { identifier = identifier })
        removed = true
    end)
    log('INFO', string_format('Unbanned identifier: %s', identifier))
    return removed
end

function Hydra.AntiCheat.Kick(src, reason)
    if not src or not players[src] then return false end
    executeKick(src, reason or 'Kicked by admin', 'admin')
    return true
end

function Hydra.AntiCheat.GetStrikes(src)
    local p = players[src]
    return p and #p.strikes or 0
end

function Hydra.AntiCheat.GetHistory(src)
    local p = players[src]
    return p and p.history or {}
end

function Hydra.AntiCheat.ClearStrikes(src)
    local p = players[src]
    if p then p.strikes = {} end
end

-- ---------------------------------------------------------------------------
-- Whitelist check for resource-triggered events
-- ---------------------------------------------------------------------------

function Hydra.AntiCheat.IsTrustedResource(resource)
    for _, r in ipairs(cfg.trusted_resources or {}) do
        if r == resource then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Admin commands (via hydra_commands or direct)
-- ---------------------------------------------------------------------------

local function registerAdminCommands()
    local function acCommand(src, args)
        if src > 0 and not IsPlayerAceAllowed(src, 'hydra.admin') then return end

        local sub = args[1] and string_lower(args[1]) or 'status'

        if sub == 'status' then
            local count = 0
            for _ in pairs(players) do count = count + 1 end
            local modules = {}
            for mod, en in pairs(moduleEnabled) do
                modules[#modules + 1] = string_format('  %s: %s', mod, en and '^2ON^0' or '^1OFF^0')
            end
            print(string_format('^3[AntiCheat]^0 Enabled: %s | Tracking %d players',
                cfg.enabled and '^2YES^0' or '^1NO^0', count))
            for _, m in ipairs(modules) do print(m) end

        elseif sub == 'strikes' then
            local target = tonumber(args[2])
            if not target then print('^1Usage: /ac strikes [playerId]^0') return end
            local p = players[target]
            if not p then print('^1Player not found^0') return end
            print(string_format('^3[AntiCheat]^0 %s has %d strikes:', GetPlayerName(target), #p.strikes))
            for i, s in ipairs(p.strikes) do
                print(string_format('  %d. [%s] %s (at %s)', i, s.module, s.reason, os.date('%H:%M:%S', s.time)))
            end

        elseif sub == 'history' then
            local target = tonumber(args[2])
            if not target then print('^1Usage: /ac history [playerId]^0') return end
            local p = players[target]
            if not p then print('^1Player not found^0') return end
            print(string_format('^3[AntiCheat]^0 Detection history for %s (%d entries):', GetPlayerName(target), #p.history))
            for i, h in ipairs(p.history) do
                print(string_format('  %d. [%s] %s — sev %d @ %s', i, h.module, h.reason, h.severity, os.date('%H:%M:%S', h.timestamp)))
            end

        elseif sub == 'ban' then
            local target = tonumber(args[2])
            local reason = args[3] or 'Admin ban'
            if not target then print('^1Usage: /ac ban [playerId] [reason]^0') return end
            Hydra.AntiCheat.Ban(target, reason)

        elseif sub == 'unban' then
            local identifier = args[2]
            if not identifier then print('^1Usage: /ac unban [identifier]^0') return end
            Hydra.AntiCheat.Unban(identifier)
            print('^2Unbanned: ' .. identifier .. '^0')

        elseif sub == 'clearstrikes' then
            local target = tonumber(args[2])
            if not target then print('^1Usage: /ac clearstrikes [playerId]^0') return end
            Hydra.AntiCheat.ClearStrikes(target)
            print('^2Strikes cleared for ' .. (GetPlayerName(target) or target) .. '^0')

        elseif sub == 'enable' then
            local mod = args[2]
            if not mod then print('^1Usage: /ac enable [module]^0') return end
            Hydra.AntiCheat.EnableModule(mod)

        elseif sub == 'disable' then
            local mod = args[2]
            if not mod then print('^1Usage: /ac disable [module]^0') return end
            Hydra.AntiCheat.DisableModule(mod)

        else
            print('^3[AntiCheat]^0 Commands: status, strikes, history, ban, unban, clearstrikes, enable, disable')
        end
    end

    -- Register via hydra_commands if available
    local ok = pcall(function()
        exports['hydra_commands']:Register('ac', acCommand, {
            description = 'AntiCheat admin commands',
            category = 'admin',
            permission = 'hydra.admin',
            args = {
                { name = 'subcommand', type = 'string', required = false },
                { name = 'target', type = 'string', required = false },
                { name = 'extra', type = 'string', required = false },
            },
        })
    end)
    if not ok then
        RegisterCommand('ac', function(src, args) acCommand(src, args) end, true)
    end
end

-- ---------------------------------------------------------------------------
-- Strike decay thread
-- ---------------------------------------------------------------------------

CreateThread(function()
    if not cfg.strikes.enabled or cfg.strikes.decay_time <= 0 then return end

    while true do
        Wait(60000)    -- Check every minute
        local now = os_time()
        for src, p in pairs(players) do
            if #p.strikes > 0 then
                local fresh = {}
                for _, s in ipairs(p.strikes) do
                    if (now - s.time) < cfg.strikes.decay_time then
                        fresh[#fresh + 1] = s
                    end
                end
                p.strikes = fresh
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Module registration
-- ---------------------------------------------------------------------------

CreateThread(function()
    Wait(100)
    registerAdminCommands()

    local ok = pcall(function()
        Hydra.Modules.Register('hydra_anticheat', {
            priority = 95,
            dependencies = { 'hydra_core' },
            api = {
                Flag = Hydra.AntiCheat.Flag,
                Ban = Hydra.AntiCheat.Ban,
                Unban = Hydra.AntiCheat.Unban,
                Kick = Hydra.AntiCheat.Kick,
                GetStrikes = Hydra.AntiCheat.GetStrikes,
                GetHistory = Hydra.AntiCheat.GetHistory,
                ClearStrikes = Hydra.AntiCheat.ClearStrikes,
                EnableModule = Hydra.AntiCheat.EnableModule,
                DisableModule = Hydra.AntiCheat.DisableModule,
                IsModuleEnabled = Hydra.AntiCheat.IsModuleEnabled,
                OnDetection = Hydra.AntiCheat.OnDetection,
                OnBan = Hydra.AntiCheat.OnBan,
                OnKick = Hydra.AntiCheat.OnKick,
                GetPlayer = Hydra.AntiCheat.GetPlayer,
                IsTrustedResource = Hydra.AntiCheat.IsTrustedResource,
            },
            hooks = {
                onLoad = function()
                    log('INFO', string_format('AntiCheat loaded — %d modules active', (function()
                        local c = 0
                        for _, v in pairs(moduleEnabled) do if v then c = c + 1 end end
                        return c
                    end)()))
                end,
            },
        })
    end)
    if not ok then
        log('WARN', 'Could not register with Hydra.Modules — running standalone')
    end

    log('INFO', 'Hydra AntiCheat server engine initialised')
end)

-- ---------------------------------------------------------------------------
-- Exports
-- ---------------------------------------------------------------------------

exports('Flag', Hydra.AntiCheat.Flag)
exports('Ban', Hydra.AntiCheat.Ban)
exports('Unban', Hydra.AntiCheat.Unban)
exports('Kick', Hydra.AntiCheat.Kick)
exports('GetStrikes', Hydra.AntiCheat.GetStrikes)
exports('GetHistory', Hydra.AntiCheat.GetHistory)
exports('ClearStrikes', Hydra.AntiCheat.ClearStrikes)
exports('EnableModule', Hydra.AntiCheat.EnableModule)
exports('DisableModule', Hydra.AntiCheat.DisableModule)
exports('IsModuleEnabled', Hydra.AntiCheat.IsModuleEnabled)
exports('OnDetection', Hydra.AntiCheat.OnDetection)
exports('OnBan', Hydra.AntiCheat.OnBan)
exports('OnKick', Hydra.AntiCheat.OnKick)
exports('GetPlayer', Hydra.AntiCheat.GetPlayer)
exports('IsTrustedResource', Hydra.AntiCheat.IsTrustedResource)
