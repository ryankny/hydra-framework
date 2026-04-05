--[[
    Hydra Framework - Secure Event System

    All Hydra events go through this system for:
    - Token-based validation (anti-spoofing)
    - Rate limiting
    - Payload size checks
    - Event logging
]]

Hydra = Hydra or {}
Hydra.Events = Hydra.Events or {}

local registeredEvents = {}
local eventHandlers = {}
local isServer = IsDuplicityVersion()
local HYDRA_PREFIX = 'hydra:'

--- Register a secure event handler
--- @param eventName string
--- @param handler function
--- @param opts table|nil { restricted = bool, rateLimit = number }
function Hydra.Events.Register(eventName, handler, opts)
    opts = opts or {}
    local fullName = HYDRA_PREFIX .. eventName

    registeredEvents[fullName] = {
        handler = handler,
        restricted = opts.restricted or false,
        rateLimit = opts.rateLimit or nil,
        module = opts.module or 'core',
    }

    if isServer then
        RegisterNetEvent(fullName)
        AddEventHandler(fullName, function(...)
            local src = source
            Hydra.Events._HandleServerEvent(fullName, src, ...)
        end)
    else
        RegisterNetEvent(fullName)
        AddEventHandler(fullName, function(...)
            Hydra.Events._HandleClientEvent(fullName, ...)
        end)
    end
end

--- Trigger a Hydra event (local)
--- @param eventName string
--- @vararg any
function Hydra.Events.Emit(eventName, ...)
    local fullName = HYDRA_PREFIX .. eventName
    TriggerEvent(fullName, ...)
end

--- Trigger a server event from client
--- @param eventName string
--- @vararg any
function Hydra.Events.EmitServer(eventName, ...)
    if isServer then
        Hydra.Utils.Log('warn', 'EmitServer called from server side for: %s', eventName)
        return
    end
    local fullName = HYDRA_PREFIX .. eventName
    TriggerServerEvent(fullName, ...)
end

--- Trigger a client event from server
--- @param eventName string
--- @param target number player id (-1 for all)
--- @vararg any
function Hydra.Events.EmitClient(eventName, target, ...)
    if not isServer then
        Hydra.Utils.Log('warn', 'EmitClient called from client side for: %s', eventName)
        return
    end
    local fullName = HYDRA_PREFIX .. eventName
    TriggerClientEvent(fullName, target, ...)
end

--- Internal: Handle incoming server events with security checks
--- @param fullName string
--- @param source number
--- @vararg any
function Hydra.Events._HandleServerEvent(fullName, src, ...)
    local event = registeredEvents[fullName]
    if not event then return end

    -- Rate limit check
    if event.rateLimit and Hydra.Security then
        if not Hydra.Security.CheckRateLimit(src, fullName, event.rateLimit) then
            Hydra.Utils.Log('warn', 'Rate limit exceeded for %s by player %d', fullName, src)
            return
        end
    end

    -- Payload size check
    if Hydra.Security and Hydra.Config.Get('security.sanitize_inputs', true) then
        local args = { ... }
        for i, arg in ipairs(args) do
            if type(arg) == 'string' and #arg > Hydra.Config.Get('security.max_event_payload', 65536) then
                Hydra.Utils.Log('warn', 'Oversized payload from player %d on event %s', src, fullName)
                return
            end
        end
    end

    -- Execute handler
    local ok, err = pcall(event.handler, src, ...)
    if not ok then
        Hydra.Utils.Log('error', 'Event handler error [%s]: %s', fullName, tostring(err))
    end
end

--- Internal: Handle incoming client events
--- @param fullName string
--- @vararg any
function Hydra.Events._HandleClientEvent(fullName, ...)
    local event = registeredEvents[fullName]
    if not event then return end

    local ok, err = pcall(event.handler, ...)
    if not ok then
        Hydra.Utils.Log('error', 'Client event handler error [%s]: %s', fullName, tostring(err))
    end
end

--- Unregister an event
--- @param eventName string
function Hydra.Events.Unregister(eventName)
    local fullName = HYDRA_PREFIX .. eventName
    registeredEvents[fullName] = nil
    RemoveEventHandler(fullName)
end

--- Get all registered events (debug)
--- @return table
function Hydra.Events.GetRegistered()
    local list = {}
    for name, data in pairs(registeredEvents) do
        list[name] = {
            module = data.module,
            restricted = data.restricted,
        }
    end
    return list
end
