--[[
    Hydra AntiCheat - Server Event Security

    Event rate limiting, blocked event filtering, argument validation,
    and trigger source verification. This is the first line of defence
    against event manipulation (the most common FiveM cheat vector).
]]

local cfg = HydraConfig.AntiCheat
local Flag = Hydra.AntiCheat.Flag
local IsModuleEnabled = Hydra.AntiCheat.IsModuleEnabled
local GetPlayer = Hydra.AntiCheat.GetPlayer

local os_clock = os.clock
local string_format = string.format

-- ---------------------------------------------------------------------------
-- Event rate limiting
-- ---------------------------------------------------------------------------

local rateLimits = {}   -- [src] = { events = {}, windowStart = clock }

if cfg.events and cfg.events.enabled and cfg.events.rate_limit and cfg.events.rate_limit.enabled then
    local rlCfg = cfg.events.rate_limit
    local windowSec = (rlCfg.window or 1000) / 1000
    local maxEvents = rlCfg.max_events or 30

    -- Hook into all registered server events via a raw handler
    -- We use a middleware pattern: track event counts per source
    local trackedSources = {}

    -- Periodic cleanup of stale rate limit data
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

    -- Export a function that other events can call to check rate limits
    -- This is called from validated event handlers
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
            Flag(src, 'events', string_format('Event rate limit exceeded: %d events in %.1fs', rl.count, now - rl.windowStart),
                rlCfg.severity or 4, rlCfg.action, { count = rl.count, window = windowSec })
            return false
        end

        return true
    end

    exports('CheckRateLimit', Hydra.AntiCheat.CheckRateLimit)
end

-- ---------------------------------------------------------------------------
-- Blocked events — events that must never originate from a client
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
-- Event argument validators
-- ---------------------------------------------------------------------------

local validators = {}

--- Register a validator for a specific event
--- @param eventName string
--- @param fn function(src, ...) -> boolean, string?
function Hydra.AntiCheat.RegisterEventValidator(eventName, fn)
    validators[eventName] = fn
end

--- Validate event arguments — call this from within event handlers
--- @param src number player source
--- @param eventName string
--- @return boolean isValid
function Hydra.AntiCheat.ValidateEvent(src, eventName, ...)
    if not IsModuleEnabled('events') then return true end

    -- Rate limit check
    if not Hydra.AntiCheat.CheckRateLimit(src) then
        return false
    end

    -- Custom validator
    local validator = validators[eventName]
    if validator then
        local ok, reason = validator(src, ...)
        if not ok then
            Flag(src, 'events', string_format('Event validation failed: %s — %s', eventName, reason or 'invalid args'),
                3, 'kick', { event = eventName, reason = reason })
            return false
        end
    end

    return true
end

exports('ValidateEvent', Hydra.AntiCheat.ValidateEvent)
exports('RegisterEventValidator', Hydra.AntiCheat.RegisterEventValidator)

-- ---------------------------------------------------------------------------
-- Built-in validators for common framework events
-- ---------------------------------------------------------------------------

CreateThread(function()
    Wait(500)

    -- Validate that position reports contain proper vector data
    Hydra.AntiCheat.RegisterEventValidator('hydra:anticheat:report:position', function(src, pos, isInVehicle, isOnGround)
        if type(pos) ~= 'vector3' and type(pos) ~= 'table' then
            return false, 'Invalid position data type'
        end
        if type(pos) == 'table' and (type(pos.x) ~= 'number' or type(pos.y) ~= 'number' or type(pos.z) ~= 'number') then
            return false, 'Position missing coordinate fields'
        end
        if type(isInVehicle) ~= 'boolean' then
            return false, 'Invalid vehicle state type'
        end
        return true
    end)

    -- Validate entity count reports
    Hydra.AntiCheat.RegisterEventValidator('hydra:anticheat:report:entities', function(src, counts)
        if type(counts) ~= 'table' then return false, 'Invalid counts' end
        if type(counts.peds) ~= 'number' or type(counts.vehicles) ~= 'number' then
            return false, 'Missing count fields'
        end
        if counts.peds < 0 or counts.vehicles < 0 then
            return false, 'Negative counts'
        end
        return true
    end)
end)

-- ---------------------------------------------------------------------------
-- Trigger source validation — detect spoofed event sources
-- ---------------------------------------------------------------------------

-- Monitor for common exploit patterns: triggering server events with
-- impossible source IDs or from non-existent players
local originalTriggerCheck = {}

--- Wrap a net event handler with source validation
--- @param eventName string
--- @param handler function
--- @return function wrappedHandler
function Hydra.AntiCheat.SecureEvent(eventName, handler)
    RegisterNetEvent(eventName, function(...)
        local src = source
        if not src or src <= 0 then return end

        -- Verify player exists
        if not GetPlayerName(src) then
            Flag(src, 'events', string_format('Event from invalid source: %s', eventName),
                4, 'kick', { event = eventName })
            return
        end

        -- Rate limit
        if not Hydra.AntiCheat.CheckRateLimit(src) then return end

        -- Call original handler
        handler(src, ...)
    end)
end

exports('SecureEvent', Hydra.AntiCheat.SecureEvent)

-- ---------------------------------------------------------------------------
-- Resource command blocking
-- ---------------------------------------------------------------------------

if cfg.resources and cfg.resources.block_resource_commands then
    -- Block players from using start/stop/restart commands
    -- These are registered as chat commands by FiveM
    for _, cmd in ipairs({'start', 'stop', 'restart', 'refresh', 'ensure'}) do
        RegisterCommand(cmd, function(src)
            if src > 0 then
                Flag(src, 'resources', string_format('Attempted resource command: %s', cmd),
                    4, 'kick', { command = cmd })
            end
        end, true)  -- restricted = true (requires ace)
    end
end

-- ---------------------------------------------------------------------------
-- Particle spam tracking
-- ---------------------------------------------------------------------------

if cfg.particles and cfg.particles.enabled then
    local particleCounts = {}   -- [src] = { count, lastReset }

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

    -- Cleanup
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
