--[[
    Hydra Framework - Client Callbacks

    Promise-based callback system for client-to-server communication.
    Supports both callback and async/await patterns.
]]

Hydra = Hydra or {}
Hydra.ClientCallbacks = Hydra.ClientCallbacks or {}

local pendingCallbacks = {}
local callbackCounter = 0

--- Initialize client callback listener
function Hydra.ClientCallbacks.Init()
    RegisterNetEvent('hydra:callback:response')
    AddEventHandler('hydra:callback:response', function(callbackId, success, ...)
        local pending = pendingCallbacks[callbackId]
        if pending then
            pending.success = success
            pending.args = { ... }
            pending.done = true
            pendingCallbacks[callbackId] = nil
        end
    end)
end

--- Trigger a server callback (async with callback function)
--- @param name string callback name
--- @param cb function response handler
--- @vararg any arguments to pass
function Hydra.ClientCallbacks.Trigger(name, cb, ...)
    callbackCounter = callbackCounter + 1
    local callbackId = callbackCounter

    pendingCallbacks[callbackId] = {
        done = false,
        success = false,
        args = {},
        callback = cb,
    }

    TriggerServerEvent('hydra:callback:request', callbackId, name, ...)

    -- Wait for response in a thread
    CreateThread(function()
        local timeout = GetGameTimer() + 10000
        local pending = pendingCallbacks[callbackId]
        while pending and not pending.done and GetGameTimer() < timeout do
            Wait(0)
            pending = pendingCallbacks[callbackId]
        end

        if pending and pending.done and pending.callback then
            pending.callback(table.unpack(pending.args))
        end
        pendingCallbacks[callbackId] = nil
    end)
end

--- Trigger a server callback (await pattern - use in CreateThread)
--- @param name string callback name
--- @vararg any arguments to pass
--- @return any response values
function Hydra.ClientCallbacks.Await(name, ...)
    callbackCounter = callbackCounter + 1
    local callbackId = callbackCounter

    local result = {
        done = false,
        success = false,
        args = {},
    }
    pendingCallbacks[callbackId] = result

    TriggerServerEvent('hydra:callback:request', callbackId, name, ...)

    -- Block until response
    local timeout = GetGameTimer() + 10000
    while not result.done and GetGameTimer() < timeout do
        Wait(0)
    end

    pendingCallbacks[callbackId] = nil

    if result.done and result.success then
        return table.unpack(result.args)
    end

    return nil
end

-- Shorthand
Hydra.Callback = Hydra.ClientCallbacks.Trigger
Hydra.AwaitCallback = Hydra.ClientCallbacks.Await
