--[[
    Hydra Framework - Server Security System

    Multi-layered security:
    - Event token validation (anti-spoofing)
    - Rate limiting per player per event
    - Payload validation
    - Exploit event blocking
    - Player validation on connect
    - Suspicious activity logging
]]

Hydra = Hydra or {}
Hydra.Security = Hydra.Security or {}

-- Per-player rate limit tracking: { [source] = { [event] = { count, lastReset } } }
local rateLimits = {}

-- Known exploit events that should never be triggered by clients
local blockedEvents = {
    -- Common exploit patterns
    ['esx:getSharedObject'] = true,
    ['esx_billing:payBill'] = true,
    ['esx_society:withdrawMoney'] = true,
    -- Add more known exploit events as they're discovered
}

-- Player tokens for session validation
local playerTokens = {}

--- Initialize security system
function Hydra.Security.Init()
    local cfg = Hydra.Config.Get('security', {})

    -- Register exploit protection if enabled
    if cfg.exploit_protection ~= false then
        Hydra.Security._RegisterExploitProtection()
    end

    -- Set up rate limit cleanup
    CreateThread(function()
        while true do
            Wait(60000) -- Clean up every minute
            Hydra.Security._CleanupRateLimits()
        end
    end)

    Hydra.Utils.Log('info', 'Security system initialized (tokens=%s, rateLimit=%s, exploitProtection=%s)',
        tostring(cfg.event_tokens ~= false),
        tostring(cfg.rate_limit or 50),
        tostring(cfg.exploit_protection ~= false)
    )
end

--- Validate a player on connection
--- @param source number
--- @return boolean valid
--- @return string|nil reason
function Hydra.Security.ValidatePlayer(src)
    local identifiers = GetPlayerIdentifiers(src)

    -- Must have at least one identifier
    if not identifiers or #identifiers == 0 then
        Hydra.Utils.Log('warn', 'Player %d rejected: no identifiers', src)
        return false, 'No valid identifiers found.'
    end

    -- Generate session token
    if Hydra.Config.Get('security.event_tokens', true) then
        local token = Hydra.Utils.GenerateId()
        playerTokens[src] = token
    end

    return true, nil
end

--- Check rate limit for a player + event combo
--- @param source number
--- @param eventName string
--- @param limit number max per second (optional override)
--- @return boolean allowed
function Hydra.Security.CheckRateLimit(src, eventName, limit)
    limit = limit or Hydra.Config.Get('security.rate_limit', 50)

    if not rateLimits[src] then
        rateLimits[src] = {}
    end

    local now = GetGameTimer()
    local playerLimits = rateLimits[src]

    if not playerLimits[eventName] then
        playerLimits[eventName] = { count = 1, lastReset = now }
        return true
    end

    local entry = playerLimits[eventName]

    -- Reset counter every second
    if now - entry.lastReset >= 1000 then
        entry.count = 1
        entry.lastReset = now
        return true
    end

    entry.count = entry.count + 1

    if entry.count > limit then
        if Hydra.Config.Get('security.security_logging', true) then
            Hydra.Utils.Log('warn', 'SECURITY: Rate limit exceeded - Player %d, Event: %s (%d/%d)',
                src, eventName, entry.count, limit)
        end
        return false
    end

    return true
end

--- Clean up rate limit data for disconnected players
function Hydra.Security._CleanupRateLimits()
    local players = GetPlayers()
    local activeSet = {}
    for _, id in ipairs(players) do
        activeSet[tonumber(id)] = true
    end

    for src in pairs(rateLimits) do
        if not activeSet[src] then
            rateLimits[src] = nil
        end
    end
end

--- Clean up player security data on disconnect
--- @param source number
function Hydra.Security.CleanupPlayer(src)
    rateLimits[src] = nil
    playerTokens[src] = nil
end

--- Register exploit protection handlers
function Hydra.Security._RegisterExploitProtection()
    -- Block known exploit events
    for eventName in pairs(blockedEvents) do
        RegisterNetEvent(eventName)
        AddEventHandler(eventName, function()
            local src = source
            if src and src > 0 then
                Hydra.Utils.Log('warn', 'SECURITY: Blocked exploit event "%s" from player %d (%s)',
                    eventName, src, GetPlayerName(src) or 'unknown')

                if Hydra.Config.Get('security.security_logging', true) then
                    -- Could emit to a logging/webhook system here
                    TriggerEvent('hydra:security:exploitAttempt', src, eventName)
                end
            end
        end)
    end

    -- Monitor for resource injection attempts
    AddEventHandler('onResourceStarting', function(resourceName)
        -- Log non-hydra resource starts for auditing
        if not resourceName:find('^hydra_') then
            Hydra.Utils.Log('debug', 'External resource starting: %s', resourceName)
        end
    end)
end

--- Validate a player source is legitimate
--- @param source number
--- @return boolean
function Hydra.Security.ValidateSource(src)
    if not src or src <= 0 then return false end
    local name = GetPlayerName(src)
    return name ~= nil
end

--- Add a custom blocked event
--- @param eventName string
function Hydra.Security.BlockEvent(eventName)
    blockedEvents[eventName] = true
    RegisterNetEvent(eventName)
    AddEventHandler(eventName, function()
        local src = source
        if src and src > 0 then
            Hydra.Utils.Log('warn', 'SECURITY: Blocked event "%s" from player %d', eventName, src)
        end
    end)
end

--- Get player session token
--- @param source number
--- @return string|nil
function Hydra.Security.GetToken(src)
    return playerTokens[src]
end

-- Export
exports('ValidateSource', Hydra.Security.ValidateSource)
