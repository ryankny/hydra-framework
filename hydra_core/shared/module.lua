--[[
    Hydra Framework - Module System

    Provides the module registration and lifecycle API.
    Modules are the building blocks of Hydra - everything is a module.
]]

Hydra = Hydra or {}
Hydra.Modules = Hydra.Modules or {}

local modules = {}
local moduleOrder = {}
local isServer = IsDuplicityVersion()

--- Module lifecycle states
local STATE = {
    REGISTERED  = 'registered',
    LOADING     = 'loading',
    READY       = 'ready',
    ERROR       = 'error',
    UNLOADED    = 'unloaded',
}

--- Register a new module
--- @param name string unique module identifier
--- @param definition table module definition
--- @return boolean success
function Hydra.Modules.Register(name, definition)
    if modules[name] then
        Hydra.Utils.Log('warn', 'Module "%s" is already registered, skipping', name)
        return false
    end

    local module = {
        name = name,
        label = definition.label or name,
        version = definition.version or '1.0.0',
        author = definition.author or 'Unknown',
        dependencies = definition.dependencies or {},
        state = STATE.REGISTERED,
        priority = definition.priority or 50,

        -- Lifecycle hooks
        onLoad = definition.onLoad or nil,
        onReady = definition.onReady or nil,
        onUnload = definition.onUnload or nil,
        onPlayerJoin = definition.onPlayerJoin or nil,
        onPlayerDrop = definition.onPlayerDrop or nil,

        -- Module's public API
        api = definition.api or {},

        -- Internal data
        _data = {},
        _startTime = nil,
    }

    modules[name] = module
    moduleOrder[#moduleOrder + 1] = name

    -- Sort by priority (higher = loads first)
    table.sort(moduleOrder, function(a, b)
        return (modules[a].priority or 50) > (modules[b].priority or 50)
    end)

    Hydra.Utils.Log('debug', 'Module registered: %s v%s', name, module.version)
    return true
end

--- Load a module (called during boot sequence)
--- @param name string
--- @return boolean success
function Hydra.Modules.Load(name)
    local module = modules[name]
    if not module then
        Hydra.Utils.Log('error', 'Cannot load unknown module: %s', name)
        return false
    end

    if module.state == STATE.READY then
        return true
    end

    -- Check dependencies
    for _, dep in ipairs(module.dependencies) do
        if not modules[dep] or modules[dep].state ~= STATE.READY then
            Hydra.Utils.Log('error', 'Module "%s" requires "%s" which is not ready', name, dep)
            module.state = STATE.ERROR
            return false
        end
    end

    module.state = STATE.LOADING
    module._startTime = GetGameTimer()

    -- Call onLoad
    if module.onLoad then
        local ok, err = pcall(module.onLoad)
        if not ok then
            module.state = STATE.ERROR
            Hydra.Utils.Log('error', 'Module "%s" onLoad failed: %s', name, tostring(err))
            return false
        end
    end

    module.state = STATE.READY
    local elapsed = GetGameTimer() - module._startTime
    Hydra.Utils.Log('info', 'Module loaded: %s v%s (%dms)', name, module.version, elapsed)

    return true
end

--- Load all registered modules in priority order
--- @return number loaded count
function Hydra.Modules.LoadAll()
    local loaded = 0
    for _, name in ipairs(moduleOrder) do
        if Hydra.Modules.Load(name) then
            loaded = loaded + 1
        end
    end

    -- Fire onReady for all loaded modules
    for _, name in ipairs(moduleOrder) do
        local module = modules[name]
        if module.state == STATE.READY and module.onReady then
            local ok, err = pcall(module.onReady)
            if not ok then
                Hydra.Utils.Log('error', 'Module "%s" onReady failed: %s', name, tostring(err))
            end
        end
    end

    return loaded
end

--- Get a module's public API
--- @param name string
--- @return table|nil
function Hydra.Modules.Get(name)
    local module = modules[name]
    if not module or module.state ~= STATE.READY then
        return nil
    end
    return module.api
end

--- Check if a module is loaded
--- @param name string
--- @return boolean
function Hydra.Modules.IsLoaded(name)
    local module = modules[name]
    return module ~= nil and module.state == STATE.READY
end

--- Unload a module
--- @param name string
--- @return boolean
function Hydra.Modules.Unload(name)
    local module = modules[name]
    if not module then return false end

    if module.onUnload then
        pcall(module.onUnload)
    end

    module.state = STATE.UNLOADED
    Hydra.Utils.Log('info', 'Module unloaded: %s', name)
    return true
end

--- Get all module statuses
--- @return table
function Hydra.Modules.GetAll()
    local list = {}
    for _, name in ipairs(moduleOrder) do
        local m = modules[name]
        list[#list + 1] = {
            name = m.name,
            label = m.label,
            version = m.version,
            state = m.state,
            priority = m.priority,
        }
    end
    return list
end

--- Broadcast a lifecycle event to all ready modules
--- @param event string lifecycle hook name
--- @vararg any
function Hydra.Modules.Broadcast(event, ...)
    local args = { ... }
    for _, name in ipairs(moduleOrder) do
        local module = modules[name]
        if module.state == STATE.READY and module[event] then
            local ok, err = pcall(module[event], table.unpack(args))
            if not ok then
                Hydra.Utils.Log('error', 'Module "%s" %s handler error: %s', name, event, tostring(err))
            end
        end
    end
end

--- Get internal module data (for the module itself)
--- @param name string
--- @return table
function Hydra.Modules.GetData(name)
    if modules[name] then
        return modules[name]._data
    end
    return {}
end

--- Shorthand: Get module API (alias)
--- @param name string
--- @return table|nil
function Hydra.Use(name)
    return Hydra.Modules.Get(name)
end

-- When running inside hydra_core, register exports.
-- When running in other resources (via @hydra_core/shared/module.lua),
-- redirect Register calls to hydra_core's export so modules register
-- into hydra_core's central table, not a local copy.
if GetCurrentResourceName() == 'hydra_core' then
    exports('GetModule', Hydra.Modules.Get)
    exports('IsModuleLoaded', Hydra.Modules.IsLoaded)

    if isServer then
        exports('RegisterModule', Hydra.Modules.Register)
        exports('UnregisterModule', Hydra.Modules.Unload)
        exports('GetModules', Hydra.Modules.GetAll)
    end
else
    -- Proxy: redirect to hydra_core's central module registry
    local _originalRegister = Hydra.Modules.Register
    Hydra.Modules.Register = function(name, definition)
        if isServer then
            local ok, result = pcall(function()
                return exports['hydra_core']:RegisterModule(name, definition)
            end)
            if ok then return result end
            -- Fallback to local if export fails (hydra_core not started yet)
            return _originalRegister(name, definition)
        else
            return _originalRegister(name, definition)
        end
    end
end
