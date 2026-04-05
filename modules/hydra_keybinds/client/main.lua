--[[
    Hydra Framework - Keybind System (Client)

    Centralized keybind management that replaces scattered RegisterKeyMapping
    calls with a unified API. Tracks all keybinds, detects conflicts, and
    provides runtime enable/disable control.
]]

Hydra = Hydra or {}
Hydra.Keybinds = Hydra.Keybinds or {}

-- Localize frequently used globals
local type = type
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local string_format = string.format
local string_upper = string.upper
local string_lower = string.lower

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------

local keybinds = {}           -- { [id] = { key, description, category, module, onPress, onRelease, enabled, isHold, mapper } }
local conflicts = {}          -- { [key_upper] = { id1, id2, ... } }
local categories = {}         -- { [category] = { id1, id2, ... } }
local globalDisabled = false  -- DisableAll/EnableAll flag
local triggerHooks = {}       -- Listener callbacks for OnTrigger
local registrationOrder = {}  -- Ordered list of keybind ids for consistent iteration

local config = nil            -- Resolved config reference

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Lazy-load config (available after resource start)
--- @return table
local function GetConfig()
    if not config then
        config = HydraConfig and HydraConfig.Keybinds or {}
    end
    return config
end

--- Debug log helper
--- @param msg string
--- @vararg any
local function DebugLog(msg, ...)
    local cfg = GetConfig()
    if cfg.debug then
        if Hydra.Utils and Hydra.Utils.Log then
            Hydra.Utils.Log('debug', '[Keybinds] ' .. msg, ...)
        else
            print(string_format('[HYDRA][DEBUG][Keybinds] ' .. msg, ...))
        end
    end
end

--- Info log helper
--- @param msg string
--- @vararg any
local function InfoLog(msg, ...)
    if Hydra.Utils and Hydra.Utils.Log then
        Hydra.Utils.Log('info', '[Keybinds] ' .. msg, ...)
    else
        print(string_format('[HYDRA][INFO][Keybinds] ' .. msg, ...))
    end
end

--- Warning log helper
--- @param msg string
--- @vararg any
local function WarnLog(msg, ...)
    if Hydra.Utils and Hydra.Utils.Log then
        Hydra.Utils.Log('warn', '[Keybinds] ' .. msg, ...)
    else
        print(string_format('[HYDRA][WARN][Keybinds] ' .. msg, ...))
    end
end

--- Normalize a key string for consistent conflict tracking
--- @param key string
--- @return string
local function NormalizeKey(key)
    return string_upper(key or '')
end

--- Fire all OnTrigger hooks
--- @param id string
--- @param isPress boolean
local function FireTriggerHooks(id, isPress)
    for i = 1, #triggerHooks do
        local ok, err = pcall(triggerHooks[i], id, isPress)
        if not ok then
            WarnLog('OnTrigger hook error: %s', tostring(err))
        end
    end
end

--- Add an id to the conflict tracking table for a given key
--- @param key string (already normalized)
--- @param id string
local function TrackKey(key, id)
    if key == '' then return end
    if not conflicts[key] then
        conflicts[key] = {}
    end
    conflicts[key][#conflicts[key] + 1] = id
end

--- Remove an id from the conflict tracking table for a given key
--- @param key string (already normalized)
--- @param id string
local function UntrackKey(key, id)
    if not conflicts[key] then return end
    for i = #conflicts[key], 1, -1 do
        if conflicts[key][i] == id then
            table.remove(conflicts[key], i)
            break
        end
    end
    if #conflicts[key] == 0 then
        conflicts[key] = nil
    end
end

--- Add an id to a category
--- @param category string
--- @param id string
local function AddToCategory(category, id)
    if not category or category == '' then return end
    if not categories[category] then
        categories[category] = {}
    end
    categories[category][#categories[category] + 1] = id
end

--- Remove an id from a category
--- @param category string
--- @param id string
local function RemoveFromCategory(category, id)
    if not categories[category] then return end
    for i = #categories[category], 1, -1 do
        if categories[category][i] == id then
            table.remove(categories[category], i)
            break
        end
    end
    if #categories[category] == 0 then
        categories[category] = nil
    end
end

--- Check for conflicts on a key and handle according to config
--- @param key string (already normalized)
--- @param id string the new keybind being registered
--- @return boolean allowed (true if registration should proceed)
local function CheckConflict(key, id)
    local cfg = GetConfig()
    if not cfg.conflict_detection then return true end
    if key == '' then return true end

    local existing = conflicts[key]
    if not existing or #existing == 0 then return true end

    -- There are existing bindings on this key
    local conflictIds = {}
    for _, existingId in ipairs(existing) do
        if existingId ~= id then
            conflictIds[#conflictIds + 1] = existingId
        end
    end

    if #conflictIds == 0 then return true end

    local action = cfg.conflict_action or 'warn'

    if action == 'block' then
        WarnLog('Keybind conflict BLOCKED: "%s" wants key [%s] already used by: %s',
            id, key, table.concat(conflictIds, ', '))
        return false
    elseif action == 'warn' then
        WarnLog('Keybind conflict: "%s" shares key [%s] with: %s',
            id, key, table.concat(conflictIds, ', '))
        return true
    end

    -- 'allow' or unknown action
    return true
end

-- ---------------------------------------------------------------------------
-- Core API
-- ---------------------------------------------------------------------------

--- Register a keybind
--- @param id string Unique identifier for this keybind
--- @param options table Keybind options
--- @return boolean success
function Hydra.Keybinds.Register(id, options)
    if not id or type(id) ~= 'string' or id == '' then
        WarnLog('Register called with invalid id')
        return false
    end

    if keybinds[id] then
        WarnLog('Keybind "%s" is already registered, skipping', id)
        return false
    end

    local cfg = GetConfig()
    if not cfg.enabled then
        DebugLog('Keybind system disabled, ignoring registration of "%s"', id)
        return false
    end

    if not options or type(options) ~= 'table' then
        WarnLog('Register called with invalid options for "%s"', id)
        return false
    end

    local key = options.key or ''
    local normalizedKey = NormalizeKey(key)
    local description = options.description or id
    local category = options.category or 'general'
    local module = options.module or 'unknown'
    local isHold = options.isHold or false
    local enabled = options.enabled
    local mapper = options.mapper or 'keyboard'

    if enabled == nil then enabled = true end

    -- Conflict check
    if not CheckConflict(normalizedKey, id) then
        return false
    end

    -- Store keybind data
    local entry = {
        id = id,
        key = key,
        normalizedKey = normalizedKey,
        description = description,
        category = category,
        module = module,
        onPress = options.onPress,
        onRelease = options.onRelease,
        isHold = isHold,
        enabled = enabled,
        mapper = mapper,
    }

    keybinds[id] = entry
    registrationOrder[#registrationOrder + 1] = id

    -- Track key for conflict detection
    TrackKey(normalizedKey, id)

    -- Track category
    AddToCategory(category, id)

    -- Register the FiveM commands and key mapping
    if isHold then
        -- Hold pattern: +command on press, -command on release
        RegisterCommand('+hydra_kb_' .. id, function()
            local kb = keybinds[id]
            if not kb then return end
            if not kb.enabled or globalDisabled then return end
            if kb.onPress then
                local ok, err = pcall(kb.onPress)
                if not ok then
                    WarnLog('onPress error for "%s": %s', id, tostring(err))
                end
            end
            FireTriggerHooks(id, true)
        end, false)

        RegisterCommand('-hydra_kb_' .. id, function()
            local kb = keybinds[id]
            if not kb then return end
            -- Release fires even when globally disabled to prevent stuck states
            if kb.onRelease then
                local ok, err = pcall(kb.onRelease)
                if not ok then
                    WarnLog('onRelease error for "%s": %s', id, tostring(err))
                end
            end
            FireTriggerHooks(id, false)
        end, false)

        RegisterKeyMapping('+hydra_kb_' .. id, description, mapper, key)
    else
        -- Toggle/tap pattern: single command on press
        RegisterCommand('hydra_kb_' .. id, function()
            local kb = keybinds[id]
            if not kb then return end
            if not kb.enabled or globalDisabled then return end
            if kb.onPress then
                local ok, err = pcall(kb.onPress)
                if not ok then
                    WarnLog('onPress error for "%s": %s', id, tostring(err))
                end
            end
            FireTriggerHooks(id, true)
        end, false)

        RegisterKeyMapping('hydra_kb_' .. id, description, mapper, key)
    end

    DebugLog('Registered keybind "%s" [%s] -> %s (%s)', id, key, description, category)
    return true
end

--- Unregister a keybind
--- Note: FiveM does not support unregistering commands/key mappings at runtime.
--- This disables the keybind and removes it from internal tracking.
--- @param id string
--- @return boolean success
function Hydra.Keybinds.Unregister(id)
    local entry = keybinds[id]
    if not entry then
        DebugLog('Cannot unregister unknown keybind: %s', tostring(id))
        return false
    end

    -- Disable to prevent further firing
    entry.enabled = false
    entry.onPress = nil
    entry.onRelease = nil

    -- Remove from conflict tracking
    UntrackKey(entry.normalizedKey, id)

    -- Remove from category
    RemoveFromCategory(entry.category, id)

    -- Remove from ordered list
    for i = #registrationOrder, 1, -1 do
        if registrationOrder[i] == id then
            table.remove(registrationOrder, i)
            break
        end
    end

    keybinds[id] = nil
    DebugLog('Unregistered keybind: %s', id)
    return true
end

--- Enable or disable a keybind at runtime
--- @param id string
--- @param enabled boolean
--- @return boolean success
function Hydra.Keybinds.SetEnabled(id, enabled)
    local entry = keybinds[id]
    if not entry then
        DebugLog('SetEnabled: unknown keybind "%s"', tostring(id))
        return false
    end

    entry.enabled = (enabled == true)
    DebugLog('Keybind "%s" %s', id, entry.enabled and 'enabled' or 'disabled')
    return true
end

--- Check if a keybind exists
--- @param id string
--- @return boolean
function Hydra.Keybinds.Exists(id)
    return keybinds[id] ~= nil
end

--- Get keybind info (returns a safe copy without callback references)
--- @param id string
--- @return table|nil
function Hydra.Keybinds.GetInfo(id)
    local entry = keybinds[id]
    if not entry then return nil end

    return {
        id = entry.id,
        key = entry.key,
        description = entry.description,
        category = entry.category,
        module = entry.module,
        isHold = entry.isHold,
        enabled = entry.enabled,
        mapper = entry.mapper,
    }
end

--- Get all keybinds, optionally filtered by category
--- @param category string|nil Filter by category, or nil for all
--- @return table Array of keybind info tables
function Hydra.Keybinds.GetAll(category)
    local result = {}

    if category then
        local ids = categories[category]
        if not ids then return result end
        for _, id in ipairs(ids) do
            local info = Hydra.Keybinds.GetInfo(id)
            if info then
                result[#result + 1] = info
            end
        end
    else
        for _, id in ipairs(registrationOrder) do
            local info = Hydra.Keybinds.GetInfo(id)
            if info then
                result[#result + 1] = info
            end
        end
    end

    return result
end

--- Get all registered categories
--- @return table Array of category names
function Hydra.Keybinds.GetCategories()
    local result = {}
    for cat in pairs(categories) do
        result[#result + 1] = cat
    end
    table.sort(result)
    return result
end

--- Get all key conflicts (keys bound to multiple actions)
--- @return table { [key] = { id1, id2, ... } } only keys with 2+ bindings
function Hydra.Keybinds.GetConflicts()
    local result = {}
    for key, ids in pairs(conflicts) do
        if #ids > 1 then
            local copy = {}
            for i = 1, #ids do
                copy[i] = ids[i]
            end
            result[key] = copy
        end
    end
    return result
end

--- Disable all keybinds temporarily (e.g. during NUI focus)
function Hydra.Keybinds.DisableAll()
    globalDisabled = true
    DebugLog('All keybinds disabled')
end

--- Re-enable all keybinds
function Hydra.Keybinds.EnableAll()
    globalDisabled = false
    DebugLog('All keybinds enabled')
end

--- Check if all keybinds are globally disabled
--- @return boolean
function Hydra.Keybinds.IsDisabled()
    return globalDisabled
end

--- Register a hook that fires when any keybind is triggered
--- @param fn function(id, isPress) Callback
function Hydra.Keybinds.OnTrigger(fn)
    if type(fn) ~= 'function' then
        WarnLog('OnTrigger requires a function argument')
        return
    end
    triggerHooks[#triggerHooks + 1] = fn
end

-- ---------------------------------------------------------------------------
-- List command
-- ---------------------------------------------------------------------------

CreateThread(function()
    -- Wait a tick for config to be available
    Wait(0)

    local cfg = GetConfig()
    local cmdName = cfg.list_command or 'keybinds'

    RegisterCommand(cmdName, function()
        local cats = Hydra.Keybinds.GetCategories()

        if #cats == 0 then
            print('^5[HYDRA]^0 No keybinds registered.')
            return
        end

        print('^5[HYDRA]^0 ====== Registered Keybinds ======')

        for _, cat in ipairs(cats) do
            local binds = Hydra.Keybinds.GetAll(cat)
            if #binds > 0 then
                print(string_format('^3  [%s]^0', string_upper(cat)))
                for _, kb in ipairs(binds) do
                    local status = kb.enabled and '^2ON^0' or '^1OFF^0'
                    local holdTag = kb.isHold and ' (hold)' or ''
                    print(string_format('    ^7[%s]^0 %s - %s [%s]%s',
                        kb.key, kb.id, kb.description, status, holdTag))
                end
            end
        end

        local conflictMap = Hydra.Keybinds.GetConflicts()
        local hasConflicts = false
        for _ in pairs(conflictMap) do hasConflicts = true; break end

        if hasConflicts then
            print('^1  [CONFLICTS]^0')
            for key, ids in pairs(conflictMap) do
                print(string_format('    ^1[%s]^0 shared by: %s', key, table.concat(ids, ', ')))
            end
        end

        if globalDisabled then
            print('^1  All keybinds currently DISABLED^0')
        end

        print('^5[HYDRA]^0 ================================')
    end, false)
end)

-- ---------------------------------------------------------------------------
-- Server-driven disable/enable event
-- ---------------------------------------------------------------------------

RegisterNetEvent('hydra_keybinds:client:setDisabled', function(disabled)
    if disabled then
        Hydra.Keybinds.DisableAll()
    else
        Hydra.Keybinds.EnableAll()
    end
end)

-- ---------------------------------------------------------------------------
-- Exports
-- ---------------------------------------------------------------------------

exports('Register', function(id, options) return Hydra.Keybinds.Register(id, options) end)
exports('Unregister', function(id) return Hydra.Keybinds.Unregister(id) end)
exports('SetEnabled', function(id, enabled) return Hydra.Keybinds.SetEnabled(id, enabled) end)
exports('Exists', function(id) return Hydra.Keybinds.Exists(id) end)
exports('GetInfo', function(id) return Hydra.Keybinds.GetInfo(id) end)
exports('GetAll', function(category) return Hydra.Keybinds.GetAll(category) end)
exports('GetCategories', function() return Hydra.Keybinds.GetCategories() end)
exports('GetConflicts', function() return Hydra.Keybinds.GetConflicts() end)
exports('DisableAll', function() Hydra.Keybinds.DisableAll() end)
exports('EnableAll', function() Hydra.Keybinds.EnableAll() end)
exports('IsDisabled', function() return Hydra.Keybinds.IsDisabled() end)
exports('OnTrigger', function(fn) Hydra.Keybinds.OnTrigger(fn) end)

-- ---------------------------------------------------------------------------
-- Module registration (client-side)
-- ---------------------------------------------------------------------------

CreateThread(function()
    -- Wait for hydra_core to be ready
    while not Hydra.Modules or not Hydra.Modules.Register do
        Wait(100)
    end

    Hydra.Modules.Register('keybinds', {
        label = 'Keybind System',
        version = '1.0.0',
        author = 'Hydra Framework',
        priority = 70,
        dependencies = { 'hydra_core' },

        api = {
            Register = Hydra.Keybinds.Register,
            Unregister = Hydra.Keybinds.Unregister,
            SetEnabled = Hydra.Keybinds.SetEnabled,
            Exists = Hydra.Keybinds.Exists,
            GetInfo = Hydra.Keybinds.GetInfo,
            GetAll = Hydra.Keybinds.GetAll,
            GetCategories = Hydra.Keybinds.GetCategories,
            GetConflicts = Hydra.Keybinds.GetConflicts,
            DisableAll = Hydra.Keybinds.DisableAll,
            EnableAll = Hydra.Keybinds.EnableAll,
            IsDisabled = Hydra.Keybinds.IsDisabled,
            OnTrigger = Hydra.Keybinds.OnTrigger,
        },

        onLoad = function()
            local cfg = GetConfig()
            DebugLog('Keybind system loading (conflict_detection=%s, conflict_action=%s)',
                tostring(cfg.conflict_detection), tostring(cfg.conflict_action))
        end,

        onReady = function()
            InfoLog('Keybind system ready')
        end,

        onUnload = function()
            -- Clear all internal state on unload
            for _, id in ipairs(registrationOrder) do
                local entry = keybinds[id]
                if entry then
                    entry.enabled = false
                    entry.onPress = nil
                    entry.onRelease = nil
                end
            end
            keybinds = {}
            conflicts = {}
            categories = {}
            registrationOrder = {}
            globalDisabled = false
            triggerHooks = {}
            InfoLog('Keybind system unloaded')
        end,
    })
end)
