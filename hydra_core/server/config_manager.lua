--[[
    Hydra Framework - Server Config Manager

    Handles config file loading, merging, and live updates.
    Supports convars for server.cfg overrides.
]]

Hydra = Hydra or {}
Hydra.ConfigManager = Hydra.ConfigManager or {}

--- Load config overrides from convars
function Hydra.ConfigManager.LoadConvars()
    -- Server owners can override config via server.cfg convars
    local overrides = {
        { convar = 'hydra_locale',             path = 'locale' },
        { convar = 'hydra_debug',              path = 'debug.enabled',           type = 'bool' },
        { convar = 'hydra_log_level',          path = 'debug.log_level' },
        { convar = 'hydra_max_players',        path = 'server.max_players',      type = 'int' },
        { convar = 'hydra_maintenance',        path = 'server.maintenance_mode', type = 'bool' },
        { convar = 'hydra_rate_limit',         path = 'security.rate_limit',     type = 'int' },
        { convar = 'hydra_exploit_protection', path = 'security.exploit_protection', type = 'bool' },
        { convar = 'hydra_db_adapter',         path = 'database.adapter' },
    }

    for _, override in ipairs(overrides) do
        local value = GetConvar(override.convar, '__NONE__')
        if value ~= '__NONE__' then
            if override.type == 'bool' then
                value = value == 'true' or value == '1'
            elseif override.type == 'int' then
                value = tonumber(value) or 0
            end
            Hydra.Config.Set(override.path, value)
            Hydra.Utils.Log('debug', 'Config override from convar: %s = %s', override.path, tostring(value))
        end
    end
end

--- Load module-specific config
--- @param moduleName string
--- @param defaults table
--- @return table merged config
function Hydra.ConfigManager.LoadModuleConfig(moduleName, defaults)
    -- Try to load from resource files first
    local configData = LoadResourceFile(GetCurrentResourceName(), ('config/%s.lua'):format(moduleName))
    local config = defaults or {}

    if configData then
        local fn, err = load(configData)
        if fn then
            local ok, result = pcall(fn)
            if ok and type(result) == 'table' then
                -- Deep merge with defaults
                for k, v in pairs(result) do
                    config[k] = v
                end
            end
        else
            Hydra.Utils.Log('error', 'Failed to parse config for module "%s": %s', moduleName, tostring(err))
        end
    end

    -- Store in main config under module namespace
    Hydra.Config.Set('modules.' .. moduleName, config)

    return config
end

--- Initialize config manager (called during boot)
CreateThread(function()
    Wait(0)
    Hydra.ConfigManager.LoadConvars()
end)
