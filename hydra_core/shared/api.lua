--[[
    Hydra Framework - Public API

    This is the main developer-facing API. Script creators interact with Hydra through this.
    Designed to be clean, minimal, and intuitive.

    Usage in any Hydra-compatible script:
        local player = Hydra.GetPlayer(source)
        local money = Hydra.Data.Get('players', identifier, 'money')
        Hydra.Events.EmitClient('notify', source, { msg = 'Hello!' })
]]

Hydra = Hydra or {}

local isServer = IsDuplicityVersion()
local readyCallbacks = {}
local frameworkReady = false

--- Check if framework is ready
--- @return boolean
function Hydra.IsReady()
    return frameworkReady
end

--- Get framework version
--- @return string
function Hydra.GetVersion()
    return Hydra.Config.Get('version', '1.0.0')
end

--- Register a callback for when Hydra is ready
--- @param cb function
function Hydra.OnReady(cb)
    if frameworkReady then
        cb()
    else
        readyCallbacks[#readyCallbacks + 1] = cb
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
