--[[
    Hydra Framework - Shared Config System

    Provides configuration access on both server and client.
    Server owns the config; client receives a filtered copy.
]]

Hydra = Hydra or {}
Hydra.Config = Hydra.Config or {}

local configCache = {}
local configLoaded = false
local pathCache = {} -- Cache parsed dot-notation paths

--- Deep merge two tables (b overrides a)
--- @param a table
--- @param b table
--- @return table
local function deepMerge(a, b)
    local result = {}
    for k, v in pairs(a) do
        if type(v) == 'table' and type(b[k]) == 'table' then
            result[k] = deepMerge(v, b[k])
        else
            result[k] = v
        end
    end
    for k, v in pairs(b) do
        if result[k] == nil then
            result[k] = v
        end
    end
    return result
end

--- Get a config value by dot-notation path
--- @param path string e.g. 'security.rate_limit'
--- @param default any fallback value
--- @return any
function Hydra.Config.Get(path, default)
    if not configLoaded then
        return default
    end

    -- Cache parsed path keys to avoid re-parsing on every call
    local keys = pathCache[path]
    if not keys then
        keys = {}
        for key in path:gmatch('[^%.]+') do
            keys[#keys + 1] = key
        end
        pathCache[path] = keys
    end

    local current = configCache
    for i = 1, #keys do
        if type(current) ~= 'table' then
            return default
        end
        current = current[keys[i]]
        if current == nil then
            return default
        end
    end

    return current
end

--- Set a config value (server-only writes, client caches locally)
--- @param path string
--- @param value any
function Hydra.Config.Set(path, value)
    local keys = {}
    for key in path:gmatch('[^%.]+') do
        keys[#keys + 1] = key
    end

    local current = configCache
    for i = 1, #keys - 1 do
        if current[keys[i]] == nil then
            current[keys[i]] = {}
        end
        current = current[keys[i]]
    end

    current[keys[#keys]] = value
end

--- Load base config
--- @param config table
function Hydra.Config.Load(config)
    configCache = config and deepMerge(configCache, config) or configCache
    configLoaded = true
end

--- Get entire config table (read-only copy)
--- @return table
function Hydra.Config.GetAll()
    return configCache
end

--- Check if config has been loaded
--- @return boolean
function Hydra.Config.IsLoaded()
    return configLoaded
end

-- Export functions
exports('GetConfig', Hydra.Config.Get)
exports('SetConfig', Hydra.Config.Set)
