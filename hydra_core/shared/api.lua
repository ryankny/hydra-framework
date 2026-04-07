--[[
    Hydra Framework - Public API

    Developer-facing API. Works cross-resource via exports.
]]

Hydra = Hydra or {}

local isServer = IsDuplicityVersion()
local isCore = GetCurrentResourceName() == 'hydra_core'
local readyCallbacks = {}
local frameworkReady = false

--- Check if framework is ready
--- @return boolean
function Hydra.IsReady()
    if isCore then
        return frameworkReady
    end
    -- Ask hydra_core via export
    if isServer then
        local ok, result = pcall(function()
            return exports['hydra_core']:IsReady()
        end)
        if ok then return result end
    end
    return frameworkReady
end

--- Get framework version
--- @return string
function Hydra.GetVersion()
    if Hydra.Config and Hydra.Config.Get then
        return Hydra.Config.Get('version', '1.0.0')
    end
    return '1.0.0'
end

--- Register a callback for when Hydra is ready
--- @param cb function
function Hydra.OnReady(cb)
    if isCore then
        -- In hydra_core, use local tracking
        if frameworkReady then
            cb()
        else
            readyCallbacks[#readyCallbacks + 1] = cb
        end
    elseif isServer then
        -- In other resources, poll hydra_core's ready state
        CreateThread(function()
            local timeout = GetGameTimer() + 60000
            while not Hydra.IsReady() and GetGameTimer() < timeout do
                Wait(200)
            end
            if Hydra.IsReady() then
                local ok, err = pcall(cb)
                if not ok then
                    Hydra.Utils.Log('error', 'OnReady callback error: %s', tostring(err))
                end
            else
                Hydra.Utils.Log('error', 'OnReady timed out in resource %s', GetCurrentResourceName())
            end
        end)
    else
        -- Client side — just wait for local ready
        if frameworkReady then
            cb()
        else
            readyCallbacks[#readyCallbacks + 1] = cb
        end
    end
end

--- Internal: Mark framework as ready and fire callbacks
function Hydra._SetReady()
    frameworkReady = true
    for _, cb in ipairs(readyCallbacks) do
        local ok, err = pcall(cb)
        if not ok then
            Hydra.Utils.Log('error', 'OnReady callback error: %s', tostring(err))
        end
    end
    readyCallbacks = {}
    Hydra.Utils.Log('info', 'Hydra Framework v%s is ready!', Hydra.GetVersion())
end

--- Quick access to get a module API
--- @param moduleName string
--- @return table|nil
function Hydra.Use(moduleName)
    return Hydra.Modules.Get(moduleName)
end

--- Register a module (shorthand)
--- @param name string
--- @param definition table
--- @return boolean
function Hydra.RegisterModule(name, definition)
    return Hydra.Modules.Register(name, definition)
end

-- Exports
exports('GetVersion', Hydra.GetVersion)
exports('IsReady', Hydra.IsReady)
