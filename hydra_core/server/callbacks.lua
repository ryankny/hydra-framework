--[[
    Hydra Framework - Server Callbacks

    Provides an optimized server callback system (like ESX.TriggerCallback / QBCore.Functions.CreateCallback).
    Uses promises on client side for async/await pattern.
]]

Hydra = Hydra or {}
Hydra.Callbacks = Hydra.Callbacks or {}

local serverCallbacks = {}
local callbackTimeout = 10000 -- 10 seconds default timeout

--- Initialize the callback system
function Hydra.Callbacks.Init()
    -- Listen for client callback requests
    RegisterNetEvent('hydra:callback:request')
    AddEventHandler('hydra:callback:request', function(callbackId, callbackName, ...)
        local src = source

        -- Validate source
        if not Hydra.Security.ValidateSource(src) then return end

        -- Rate limit callbacks
        if not Hydra.Security.CheckRateLimit(src, 'callback:' .. callbackName) then
            TriggerClientEvent('hydra:callback:response', src, callbackId, false, 'Rate limited')
            return
        end

        local callback = serverCallbacks[callbackName]
        if not callback then
            Hydra.Utils.Log('warn', 'Unknown callback requested: %s (player %d)', callbackName, src)
            TriggerClientEvent('hydra:callback:response', src, callbackId, false, 'Unknown callback')
            return
        end

        -- Execute callback with source and respond
        local ok, result = pcall(function()
            callback(src, function(...)
                TriggerClientEvent('hydra:callback:response', src, callbackId, true, ...)
            end, ...)
        end)

        if not ok then
            Hydra.Utils.Log('error', 'Callback error [%s]: %s', callbackName, tostring(result))
            TriggerClientEvent('hydra:callback:response', src, callbackId, false, 'Server error')
        end
    end)

    Hydra.Utils.Log('debug', 'Callback system initialized')
end

--- Register a server callback
--- @param name string callback name
--- @param handler function(source, cb, ...)
function Hydra.Callbacks.Register(name, handler)
    serverCallbacks[name] = handler
    Hydra.Utils.Log('debug', 'Registered callback: %s', name)
end

--- Unregister a callback
--- @param name string
function Hydra.Callbacks.Unregister(name)
    serverCallbacks[name] = nil
end

--- Server-to-server callback (direct invoke)
--- @param name string
--- @param source number
--- @vararg any
--- @return any
function Hydra.Callbacks.Invoke(name, src, ...)
    local callback = serverCallbacks[name]
    if not callback then
        Hydra.Utils.Log('warn', 'Attempted to invoke unknown callback: %s', name)
        return nil
    end

    local result = nil
    local done = false

    callback(src, function(...)
        result = { ... }
        done = true
    end, ...)

    -- If callback is synchronous, result is already set
    -- If async, wait briefly
    local timeout = GetGameTimer() + callbackTimeout
    while not done and GetGameTimer() < timeout do
        Wait(0)
    end

    if result then
        return table.unpack(result)
    end
    return nil
end

-- Exports
exports('RegisterCallback', Hydra.Callbacks.Register)
exports('TriggerCallback', Hydra.Callbacks.Invoke)
