--[[
    Hydra AntiCheat - Server Event Security

    Event rate limiting, blocked event filtering, argument validation,
    trigger source verification, honeypot events, per-event limits,
    payload size validation, and resource command blocking.
]]

local cfg = HydraConfig.AntiCheat
local Flag = Hydra.AntiCheat.Flag
local IsModuleEnabled = Hydra.AntiCheat.IsModuleEnabled
local GetPlayer = Hydra.AntiCheat.GetPlayer

local os_clock = os.clock
local string_format = string.format
local string_len = string.len

-- ---------------------------------------------------------------------------
-- Event rate limiting (global)
-- ---------------------------------------------------------------------------

local rateLimits = {}

if cfg.events and cfg.events.enabled and cfg.events.rate_limit and cfg.events.rate_limit.enabled then
    local rlCfg = cfg.events.rate_limit
    local windowSec = (rlCfg.window or 1000) / 1000
    local maxEvents = rlCfg.max_events or 30

    -- Periodic cleanup
    CreateThread(function()
        while true do
            Wait(10000)
            local now = os_clock()
            for src, data in pairs(rateLimits) do
                if (now - data.windowStart) > windowSec * 5 then
                    rateLimits[src] = nil
                end
            end
        end
    end)

    function Hydra.AntiCheat.CheckRateLimit(src)
        if not IsModuleEnabled('events') then return true end
        if not src or src <= 0 then return true end

        local now = os_clock()
        local rl = rateLimits[src]

        if not rl or (now - rl.windowStart) > windowSec then
            rateLimits[src] = { count = 1, windowStart = now }
            return true
        end

        rl.count = rl.count + 1

        if rl.count > maxEvents then
            Flag(src, 'events', string_format('Event rate limit: %d events in %.1fs', rl.count, now - rl.windowStart),
                rlCfg.severity or 4, rlCfg.action, { count = rl.count, window = windowSec })
            return false
        end

        return true
    end

    exports('CheckRateLimit', Hydra.AntiCheat.CheckRateLimit)
end

-- ---------------------------------------------------------------------------
-- Per-event rate limiting
-- ---------------------------------------------------------------------------

local perEventLimits = {}   -- [src] = { [eventName] = { count, lastReset } }

if cfg.events and cfg.events.per_event_limits then
    function Hydra.AntiCheat.CheckPerEventLimit(src, eventName)
        local limit = cfg.events.per_event_limits[eventName]
        if not limit then return true end

        local now = os_clock()
        perEventLimits[src] = perEventLimits[src] or {}
        local pel = perEventLimits[src][eventName]

        if not pel or (now - pel.lastReset) > 1.0 then
            perEventLimits[src][eventName] = { count = 1, lastReset = now }
            return true
        end

        pel.count = pel.count + 1
        if pel.count > limit then
            Flag(src, 'events', string_format('Per-event rate limit [%s]: %d/sec (max %d)', eventName, pel.count, limit),
                3, 'kick', { event = eventName, count = pel.count })
            return false
        end

        return true
    end

    -- Cleanup
    AddEventHandler('playerDropped', function()
        perEventLimits[source] = nil
    end)
end

-- ---------------------------------------------------------------------------
-- Blocked events
-- ---------------------------------------------------------------------------

if cfg.events and cfg.events.enabled and cfg.events.blocked_events then
    for _, eventName in ipairs(cfg.events.blocked_events) do
        RegisterNetEvent(eventName, function()
            local src = source
            if src and src > 0 then
                Flag(src, 'events', string_format('Triggered blocked event: %s', eventName),
                    5, 'ban', { event = eventName })
            end
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Honeypot events — fake events that only cheaters trigger
-- ---------------------------------------------------------------------------

if cfg.honeypots and cfg.honeypots.enabled then
    for _, eventName in ipairs(cfg.honeypots.events or {}) do
        RegisterNetEvent(eventName, function(...)
            local src = source
            if src and src > 0 then
                Flag(src, 'honeypots', string_format('Honeypot triggered: %s', eventName),
                    cfg.honeypots.severity or 5, cfg.honeypots.action or 'ban', { event = eventName })
            end
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Event argument validators
-- ---------------------------------------------------------------------------

local validators = {}

function Hydra.AntiCheat.RegisterEventValidator(eventName, fn)
    validators[eventName] = fn
end

function Hydra.AntiCheat.ValidateEvent(src, eventName, ...)
    if not IsModuleEnabled('events') then return true end

    -- Rate limit check
    if Hydra.AntiCheat.CheckRateLimit and not Hydra.AntiCheat.CheckRateLimit(src) then
        return false
    end

    -- Per-event rate limit
    if Hydra.AntiCheat.CheckPerEventLimit and not Hydra.AntiCheat.CheckPerEventLimit(src, eventName) then
        return false
    end

    -- Custom validator
    local validator = validators[eventName]
    if validator then
        local ok, reason = validator(src, ...)
        if not ok then
            Flag(src, 'events', string_format('Validation failed [%s]: %s', eventName, reason or 'invalid'),
                3, 'kick', { event = eventName, reason = reason })
            return false
        end
    end

    return true
end

exports('ValidateEvent', Hydra.AntiCheat.ValidateEvent)
exports('RegisterEventValidator', Hydra.AntiCheat.RegisterEventValidator)

-- ---------------------------------------------------------------------------
-- Built-in validators
-- ---------------------------------------------------------------------------

CreateThread(function()
    Wait(500)

    Hydra.AntiCheat.RegisterEventValidator('hydra:anticheat:report:position', function(src, pos, isInVehicle, isOnGround)
        if type(pos) ~= 'vector3' and type(pos) ~= 'table' then
            return false, 'Invalid position type'
        end
        if type(pos) == 'table' and (type(pos.x) ~= 'number' or type(pos.y) ~= 'number' or type(pos.z) ~= 'number') then
            return false, 'Missing coordinates'
        end
        if type(isInVehicle) ~= 'boolean' then
            return false, 'Invalid vehicle state'
        end
        return true
    end)

    Hydra.AntiCheat.RegisterEventValidator('hydra:anticheat:report:entities', function(src, counts)
        if type(counts) ~= 'table' then return false, 'Invalid counts' end
        if type(counts.peds) ~= 'number' or type(counts.vehicles) ~= 'number' then
            return false, 'Missing fields'
        end
        if counts.peds < 0 or counts.vehicles < 0 then
            return false, 'Negative counts'
        end
        return true
    end)

    -- Validate combat reports
    Hydra.AntiCheat.RegisterEventValidator('hydra:anticheat:report:combat', function(src, data)
        if type(data) ~= 'table' then return false, 'Invalid data' end
        return true
    end)

    -- Validate recoil samples
    Hydra.AntiCheat.RegisterEventValidator('hydra:anticheat:report:recoil', function(src, samples)
        if type(samples) ~= 'table' then return false, 'Invalid samples' end
        if #samples > 100 then return false, 'Too many samples' end
        return true
    end)
end)

-- ---------------------------------------------------------------------------
-- Trigger source validation
-- ---------------------------------------------------------------------------

function Hydra.AntiCheat.SecureEvent(eventName, handler)
    RegisterNetEvent(eventName, function(...)
        local src = source
        if not src or src <= 0 then return end
        if not GetPlayerName(src) then
            Flag(src, 'events', string_format('Event from invalid source: %s', eventName),
                4, 'kick', { event = eventName })
            return
        end
        if Hydra.AntiCheat.CheckRateLimit and not Hydra.AntiCheat.CheckRateLimit(src) then return end
        handler(src, ...)
    end)
end

exports('SecureEvent', Hydra.AntiCheat.SecureEvent)

-- ---------------------------------------------------------------------------
-- Resource command blocking
-- ---------------------------------------------------------------------------

if cfg.resources and cfg.resources.block_resource_commands then
    for _, cmd in ipairs({'start', 'stop', 'restart', 'refresh', 'ensure'}) do
        RegisterCommand(cmd, function(src)
            if src > 0 then
                Flag(src, 'resources', string_format('Resource command attempt: %s', cmd),
                    4, 'kick', { command = cmd })
            end
        end, true)
    end
end

-- ---------------------------------------------------------------------------
-- Particle spam tracking
-- ---------------------------------------------------------------------------

if cfg.particles and cfg.particles.enabled then
    local particleCounts = {}

    RegisterNetEvent('hydra:anticheat:report:particle', function()
        local src = source
        if not IsModuleEnabled('particles') then return end

        local now = os_clock()
        local pc = particleCounts[src]

        if not pc or (now - pc.lastReset) > 1.0 then
            particleCounts[src] = { count = 1, lastReset = now }
            return
        end

        pc.count = pc.count + 1
        if pc.count > cfg.particles.max_per_second then
            Flag(src, 'particles', string_format('Particle spam: %d/sec (max %d)', pc.count, cfg.particles.max_per_second),
                cfg.particles.severity or 3, cfg.particles.action, { count = pc.count })
        end
    end)

    CreateThread(function()
        while true do
            Wait(30000)
            local now = os_clock()
            for src, pc in pairs(particleCounts) do
                if (now - pc.lastReset) > 10 then
                    particleCounts[src] = nil
                end
            end
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Cleanup on player drop
-- ---------------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    rateLimits[source] = nil
end)
