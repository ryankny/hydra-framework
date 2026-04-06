--[[
    Hydra Commands - Client Main

    Receives command registrations from the server, executes client-side
    command handlers, manages local-only commands, provides chat suggestions,
    and tracks client-side cooldowns.
]]

Hydra = Hydra or {}
Hydra.Commands = Hydra.Commands or {}

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------

local cfg = HydraConfig.Commands

local localCommands = {}     -- [name] = { handler, description, category, ... }
local serverCommands = {}    -- [name] = metadata received from server
local cooldowns = {}         -- [name] = last used timestamp (ms)

local string_lower = string.lower
local string_format = string.format
local math_min = math.min

-- Forward declarations
local sendSuggestion

-- ---------------------------------------------------------------------------
-- Utility: Parse raw argument string into positional tokens
-- ---------------------------------------------------------------------------

local function tokenize(rawArgs)
    local tokens = {}
    if not rawArgs or rawArgs == '' then return tokens end
    for token in rawArgs:gmatch('%S+') do
        if #tokens >= cfg.max_args then break end
        tokens[#tokens + 1] = token
    end
    return tokens
end

-- ---------------------------------------------------------------------------
-- Utility: Coerce a string value to the declared type
-- ---------------------------------------------------------------------------

local function coerce(value, argDef)
    local t = argDef.type or 'string'

    if t == 'number' then
        local n = tonumber(value)
        if not n then
            return nil, string_format('Argument "%s" must be a number.', argDef.name)
        end
        return n

    elseif t == 'playerId' then
        local id = tonumber(value)
        if not id then
            return nil, string_format('Argument "%s" must be a player ID.', argDef.name)
        end
        return id

    elseif t == 'boolean' then
        local lower = string_lower(value)
        if lower == 'true' or lower == 'yes' or lower == '1' then
            return true
        elseif lower == 'false' or lower == 'no' or lower == '0' then
            return false
        end
        return nil, string_format('Argument "%s" must be true/false or yes/no.', argDef.name)
    end

    return value
end

-- ---------------------------------------------------------------------------
-- Utility: Parse tokens into named arguments
-- ---------------------------------------------------------------------------

local function parseArgs(tokens, argDefs)
    local parsed = {}
    if not argDefs or #argDefs == 0 then return parsed end

    for i, def in ipairs(argDefs) do
        local raw = tokens[i]
        if raw then
            local val, err = coerce(raw, def)
            if err then return nil, err end
            parsed[def.name] = val
        elseif def.required then
            return nil, string_format('Missing required argument: %s', def.name)
        elseif def.default ~= nil then
            parsed[def.name] = def.default
        end
    end

    return parsed
end

-- ---------------------------------------------------------------------------
-- Utility: Show a local feedback message
-- ---------------------------------------------------------------------------

local function showMessage(message, msgType)
    if Hydra.Notify and Hydra.Notify.Show then
        Hydra.Notify.Show(message, msgType or 'info', 5000)
    else
        TriggerEvent('chat:addMessage', {
            args = { 'Commands', message },
            color = { 100, 180, 255 },
        })
    end
end

-- ---------------------------------------------------------------------------
-- Utility: Check and enforce cooldown
-- ---------------------------------------------------------------------------

local function checkCooldown(name, cooldownMs)
    if cooldownMs <= 0 then return true end

    local now = GetGameTimer()
    local key = string_lower(name)
    if cooldowns[key] and (now - cooldowns[key]) < cooldownMs then
        return false
    end
    cooldowns[key] = now
    return true
end

-- ---------------------------------------------------------------------------
-- Utility: Build handler wrapper for a local command
-- ---------------------------------------------------------------------------

local function buildHandler(name, cmd)
    return function(source, rawTokens, rawString)
        if cmd._disabled then return end

        -- Cooldown
        if not checkCooldown(name, cmd.cooldown or cfg.cooldown_default) then
            showMessage(cfg.cooldown_message, 'error')
            return
        end

        -- Parse arguments
        local rawArgs = rawString or table.concat(rawTokens, ' ')
        local tokens = type(rawTokens) == 'table' and rawTokens or tokenize(rawArgs)
        local parsed, err = parseArgs(tokens, cmd.args)
        if err then
            showMessage(err, 'error')
            if cmd.args and #cmd.args > 0 then
                local usage = '/' .. name
                for _, def in ipairs(cmd.args) do
                    if def.required then
                        usage = usage .. ' <' .. def.name .. '>'
                    else
                        usage = usage .. ' [' .. def.name .. ']'
                    end
                end
                showMessage('Usage: ' .. usage, 'info')
            end
            return
        end

        -- Execute
        local ok, handlerErr = pcall(cmd.handler, parsed, rawArgs)
        if not ok then
            if cfg.debug then
                showMessage('Command error: ' .. tostring(handlerErr), 'error')
            else
                showMessage('An error occurred while running this command.', 'error')
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Client API
-- ---------------------------------------------------------------------------

--- Register a client-only local command (not managed by the server).
--- @param name string command name (no leading slash)
--- @param handler function(args, rawArgs) handler function
--- @param options table|nil options
function Hydra.Commands.RegisterLocal(name, handler, options)
    if not cfg.enabled then return false end

    name = string_lower(name)
    options = options or {}

    if localCommands[name] then
        Hydra.Utils.Log('warn', 'Local command "/%s" already registered.', name)
        return false
    end

    local cmd = {
        name = name,
        handler = handler,
        description = options.description or '',
        category = options.category or 'general',
        cooldown = options.cooldown or cfg.cooldown_default,
        aliases = options.aliases or {},
        args = options.args or {},
        module = options.module or 'unknown',
        hidden = options.hidden or false,
        _disabled = false,
    }

    localCommands[name] = cmd

    -- Register with FiveM
    RegisterCommand(name, buildHandler(name, cmd), false)

    -- Register aliases
    for _, alias in ipairs(cmd.aliases) do
        alias = string_lower(alias)
        if not localCommands[alias] then
            localCommands[alias] = cmd
            RegisterCommand(alias, buildHandler(alias, cmd), false)
        end
    end

    -- Send suggestion to chat
    sendSuggestion(name, cmd)

    if cfg.debug then
        Hydra.Utils.Log('debug', 'Registered local command: /%s', name)
    end

    return true
end

--- Get all commands known to this client (local + server-registered).
--- @return table
function Hydra.Commands.GetAll()
    local result = {}

    -- Local commands
    for name, cmd in pairs(localCommands) do
        if not cmd._disabled then
            result[#result + 1] = {
                name = name,
                description = cmd.description,
                category = cmd.category,
                module = cmd.module,
                source = 'local',
            }
        end
    end

    -- Server-registered client commands
    for name, cmd in pairs(serverCommands) do
        result[#result + 1] = {
            name = name,
            description = cmd.description or '',
            category = cmd.category or 'general',
            module = cmd.module or 'unknown',
            source = 'server',
        }
    end

    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

-- ---------------------------------------------------------------------------
-- Chat suggestion helper
-- ---------------------------------------------------------------------------

sendSuggestion = function(name, cmd)
    local params = {}
    if cmd.args then
        for _, def in ipairs(cmd.args) do
            params[#params + 1] = {
                name = def.name,
                help = def.help or ('(' .. (def.type or 'string') .. ')'),
            }
        end
    end

    -- Standard FiveM chat suggestion
    TriggerEvent('chat:addSuggestion', '/' .. name, cmd.description or '', params)
end

-- ---------------------------------------------------------------------------
-- Network events: server -> client
-- ---------------------------------------------------------------------------

--- Receive a client command registration from the server.
RegisterNetEvent('hydra:commands:register')
AddEventHandler('hydra:commands:register', function(name, options)
    name = string_lower(name)
    serverCommands[name] = options

    -- Register the command locally so FiveM recognises it
    if not localCommands[name] then
        RegisterCommand(name, function(source, rawTokens, rawString)
            -- Cooldown
            local cd = (options.cooldown or cfg.cooldown_default)
            if not checkCooldown(name, cd) then
                showMessage(cfg.cooldown_message, 'error')
                return
            end

            -- Parse arguments
            local rawArgs = rawString or table.concat(rawTokens, ' ')
            local tokens = type(rawTokens) == 'table' and rawTokens or tokenize(rawArgs)
            local parsed, err = parseArgs(tokens, options.args)
            if err then
                showMessage(err, 'error')
                return
            end

            -- Tell server to execute the client command handler
            TriggerServerEvent('hydra:commands:clientExecute', name, rawArgs)
        end, options.restricted or false)

        -- Register aliases
        if options.aliases then
            for _, alias in ipairs(options.aliases) do
                alias = string_lower(alias)
                if not localCommands[alias] and not serverCommands[alias] then
                    serverCommands[alias] = options
                    RegisterCommand(alias, function(source, rawTokens, rawString)
                        local cd = (options.cooldown or cfg.cooldown_default)
                        if not checkCooldown(alias, cd) then
                            showMessage(cfg.cooldown_message, 'error')
                            return
                        end
                        local rawArgs = rawString or table.concat(rawTokens, ' ')
                        TriggerServerEvent('hydra:commands:clientExecute', name, rawArgs)
                    end, options.restricted or false)
                end
            end
        end
    end

    -- Send chat suggestion
    if options.args then
        local params = {}
        for _, def in ipairs(options.args) do
            params[#params + 1] = {
                name = def.name,
                help = def.help or ('(' .. (def.type or 'string') .. ')'),
            }
        end
        TriggerEvent('chat:addSuggestion', '/' .. name, options.description or '', params)
    else
        TriggerEvent('chat:addSuggestion', '/' .. name, options.description or '', {})
    end

    if cfg.debug then
        Hydra.Utils.Log('debug', 'Received server command registration: /%s', name)
    end
end)

--- Receive a command execution request from the server.
RegisterNetEvent('hydra:commands:execute')
AddEventHandler('hydra:commands:execute', function(name, rawArgs)
    name = string_lower(name)
    local cmd = localCommands[name]
    if not cmd or not cmd.handler then return end

    local tokens = tokenize(rawArgs)
    local parsed, err = parseArgs(tokens, cmd.args)
    if err then
        showMessage(err, 'error')
        return
    end

    local ok, handlerErr = pcall(cmd.handler, parsed, rawArgs)
    if not ok then
        if cfg.debug then
            showMessage('Command error: ' .. tostring(handlerErr), 'error')
        else
            showMessage('An error occurred while running this command.', 'error')
        end
    end
end)

--- Receive chat suggestion data from the server.
RegisterNetEvent('hydra:commands:suggestions')
AddEventHandler('hydra:commands:suggestions', function(data)
    if not data or not data.name then return end
    TriggerEvent('chat:addSuggestion', data.name, data.help or '', data.params or {})
end)

-- ---------------------------------------------------------------------------
-- Client exports
-- ---------------------------------------------------------------------------

exports('RegisterLocal', Hydra.Commands.RegisterLocal)
exports('GetAll', Hydra.Commands.GetAll)

-- ---------------------------------------------------------------------------
-- Cooldown cleanup
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(60000)
        local now = GetGameTimer()
        local maxAge = 300000
        for key, ts in pairs(cooldowns) do
            if (now - ts) > maxAge then
                cooldowns[key] = nil
            end
        end
    end
end)
