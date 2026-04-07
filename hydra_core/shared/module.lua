--[[
    Hydra Framework - Module System

    Simple module registry for tracking loaded modules.
    Lifecycle hooks are handled directly by each module via events.
    No functions are passed through exports — only metadata.
]]

Hydra = Hydra or {}
Hydra.Modules = Hydra.Modules or {}

local modules = {}
local moduleOrder = {}
local isServer = IsDuplicityVersion()
local isCore = GetCurrentResourceName() == 'hydra_core'

local STATE = {
    REGISTERED  = 'registered',
    READY       = 'ready',
    ERROR       = 'error',
}

--- Register a module (metadata only — no lifecycle hooks)
--- @param name string
--- @param definition table { label, version, author, priority, dependencies }
--- @return boolean
function Hydra.Modules.Register(name, definition)
    definition = definition or {}

    if isCore then
        -- Store directly
        if modules[name] then return true end
        modules[name] = {
            name = name,
            label = definition.label or name,
            version = definition.version or '1.0.0',
            author = definition.author or 'Unknown',
            dependencies = definition.dependencies or {},
            priority = definition.priority or 50,
            state = STATE.REGISTERED,
        }
        moduleOrder[#moduleOrder + 1] = name
        table.sort(moduleOrder, function(a, b)
            return (modules[a].priority or 50) > (modules[b].priority or 50)
        end)
    elseif isServer then
        -- Send metadata to hydra_core via export
        pcall(function()
            exports['hydra_core']:RegisterModule(name, {
                label = definition.label or name,
                version = definition.version or '1.0.0',
                author = definition.author or 'Unknown',
                dependencies = definition.dependencies or {},
                priority = definition.priority or 50,
            })
        end)
    end

    Hydra.Utils.Log('debug', 'Module registered: %s v%s', name, definition.version or '1.0.0')
    return true
end

--- Resolve dependency name (handles hydra_ prefix)
local function resolveDep(dep)
    if modules[dep] then return dep end
    if dep:sub(1, 6) == 'hydra_' then
        local short = dep:sub(7)
        if modules[short] then return short end
    end
    if modules['hydra_' .. dep] then return 'hydra_' .. dep end
    return dep
end

--- Mark a module as ready (checks dependencies)
--- @param name string
--- @return boolean
function Hydra.Modules.MarkReady(name)
    local module = modules[name]
    if not module then return false end
    if module.state == STATE.READY then return true end

    -- Check dependencies
    for _, dep in ipairs(module.dependencies) do
        if dep == 'hydra_core' or dep == 'core' then
            -- Always satisfied
        else
            local resolved = resolveDep(dep)
            if not modules[resolved] or modules[resolved].state ~= STATE.READY then
                Hydra.Utils.Log('error', 'Module "%s" requires "%s" which is not ready', name, dep)
                module.state = STATE.ERROR
                return false
            end
        end
    end

    module.state = STATE.READY
    Hydra.Utils.Log('info', 'Module ready: %s v%s', name, module.version)
    return true
end

--- Mark all registered modules as ready (in priority order)
--- @return number count of ready modules
function Hydra.Modules.ReadyAll()
    local count = 0
    for _, name in ipairs(moduleOrder) do
        if Hydra.Modules.MarkReady(name) then
            count = count + 1
        end
    end
    return count
end

--- Check if a module is loaded/ready
--- @param name string
--- @return boolean
function Hydra.Modules.IsLoaded(name)
    -- Check local table first (works in hydra_core)
    local module = modules[name]
    if module and module.state == STATE.READY then return true end
    local alt = name:sub(1, 6) == 'hydra_' and name:sub(7) or ('hydra_' .. name)
    local altMod = modules[alt]
    if altMod and altMod.state == STATE.READY then return true end

    -- If not in hydra_core, ask hydra_core via export
    if not isCore and isServer then
        local ok, result = pcall(function()
            return exports['hydra_core']:IsModuleLoaded(name)
        end)
        if ok then return result end
    end

    return false
end

--- Get all module statuses
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

--- Get a module by name
function Hydra.Modules.Get(name)
    return modules[name] or modules[resolveDep(name)]
end

--- Broadcast is now a simple event trigger
function Hydra.Modules.Broadcast(event, ...)
    TriggerEvent('hydra:' .. event, ...)
end

-- Exports (hydra_core only)
if isCore then
    exports('GetModule', Hydra.Modules.Get)
    exports('IsModuleLoaded', Hydra.Modules.IsLoaded)

    if isServer then
        exports('RegisterModule', function(name, metadata)
            Hydra.Modules.Register(name, metadata)
            return true
        end)
        exports('GetModules', Hydra.Modules.GetAll)
    end
end
