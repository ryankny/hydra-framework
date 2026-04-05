--[[
    Hydra Commands - Server Main

    Centralized command registration, permission enforcement, cooldown
    tracking, argument parsing, help generation, and typo suggestion.
    Replaces scattered RegisterCommand calls with a single managed API.
]]

Hydra = Hydra or {}
Hydra.Commands = Hydra.Commands or {}

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------

local cfg = HydraConfig.Commands

local commands = {}           -- [name] = command definition
local aliases = {}            -- [alias] = canonical name
local cooldowns = {}          -- [src:cmd] = last used timestamp (ms)
local categories = {}         -- [category] = { name, ... }
local clientCommands = {}     -- commands forwarded to clients

local string_lower = string.lower
local string_format = string.format
local table_insert = table.insert
local math_min = math.min

-- Forward declarations
local broadcastSuggestion

-- ---------------------------------------------------------------------------
-- Utility: Levenshtein distance (inline, no dependencies)
-- ---------------------------------------------------------------------------

local function levenshtein(a, b)
    local la, lb = #a, #b
    if la == 0 then return lb end
    if lb == 0 then return la end

    local prev = {}
    local curr = {}
    for j = 0, lb do prev[j] = j end

    for i = 1, la do
        curr[0] = i
        for j = 1, lb do
            local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
            curr[j] = math_min(
                prev[j] + 1,         -- deletion
                curr[j - 1] + 1,     -- insertion
                prev[j - 1] + cost   -- substitution
            )
        end
        prev, curr = curr, prev
    end
    return prev[lb]
end

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
        if not GetPlayerName(id) then
            return nil, string_format('No player found with ID %d.', id)
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

    -- Default: string
    return value
end

-- ---------------------------------------------------------------------------
-- Utility: Parse positional tokens into named args using a command's arg defs
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
-- Utility: Send a chat message to a player
-- ---------------------------------------------------------------------------

local function sendMessage(source, message, msgType)
    if source == 0 then
        Hydra.Utils.Log('info', message)
        return
    end

    -- Try hydra_notify first, fall back to basic chat
    if Hydra.Notify and Hydra.Notify.Send then
        Hydra.Notify.Send(source, {
            message = message,
            type = msgType or 'info',
            duration = 6000,
        })
    else
        TriggerClientEvent('chat:addMessage', source, {
            args = { 'Commands', message },
            color = { 100, 180, 255 },
        })
    end
end

-- ---------------------------------------------------------------------------
-- Utility: Log a command invocation
-- ---------------------------------------------------------------------------

local function logCommand(source, name, rawArgs)
    if not cfg.log_usage then return end

    local cmd = commands[name]
    if cfg.log_admin_only and not cmd.permission then return end

    local playerName = (source > 0) and GetPlayerName(source) or 'Console'
    local text = string_format('[CMD] %s (id:%s) -> /%s %s', playerName, tostring(source), name, rawArgs or '')

    Hydra.Utils.Log('info', text)

    -- Forward to hydra_logs if available
    pcall(function()
        TriggerEvent('hydra:logs:write', {
            source = source,
            category = 'command',
            message = text,
        })
    end)
end

-- ---------------------------------------------------------------------------
-- Utility: Build the wrapper handler that RegisterCommand receives
-- ---------------------------------------------------------------------------

local function buildHandler(name, cmd)
    return function(source, rawTokens, rawString)
        -- Enabled check
        if cmd._disabled then
            return
        end

        -- Server-only check
        if cmd.serverOnly and source > 0 then
            sendMessage(source, 'This command can only be used from the server console.', 'error')
            return
        end

        -- Permission check
        if cmd.permission and source > 0 then
            if not IsPlayerAceAllowed(source, cmd.permission) then
                sendMessage(source, cfg.permission_message, 'error')
                return
            end
        end

        -- Cooldown check
        if source > 0 and cmd.cooldown > 0 then
            local key = source .. ':' .. name
            local now = GetGameTimer()
            if cooldowns[key] and (now - cooldowns[key]) < cmd.cooldown then
                sendMessage(source, cfg.cooldown_message, 'error')
                return
            end
            cooldowns[key] = now
        end

        -- Parse arguments
        local rawArgs = rawString or table.concat(rawTokens, ' ')
        local tokens = type(rawTokens) == 'table' and rawTokens or tokenize(rawArgs)
        local parsed, err = parseArgs(tokens, cmd.args)
        if err then
            sendMessage(source, err, 'error')
            if cmd.args and #cmd.args > 0 then
                local usage = '/' .. name
                for _, def in ipairs(cmd.args) do
                    if def.required then
                        usage = usage .. ' <' .. def.name .. '>'
                    else
                        usage = usage .. ' [' .. def.name .. ']'
                    end
                end
                sendMessage(source, 'Usage: ' .. usage, 'info')
            end
            return
        end

        -- Log
        logCommand(source, name, rawArgs)

        -- Execute handler inside pcall
        local ok, handlerErr = pcall(cmd.handler, source, parsed, rawArgs)
        if not ok then
            Hydra.Utils.Log('error', 'Command /%s error: %s', name, tostring(handlerErr))
            sendMessage(source, 'An error occurred while running this command.', 'error')
        end
    end
end

-- ---------------------------------------------------------------------------
-- Utility: Add a command name to its category tracking table
-- ---------------------------------------------------------------------------

local function addToCategory(name, category)
    category = category or 'general'
    if not categories[category] then
        categories[category] = {}
    end
    table_insert(categories[category], name)
end

-- ---------------------------------------------------------------------------
-- Utility: Remove a command name from its category tracking table
-- ---------------------------------------------------------------------------

local function removeFromCategory(name, category)
    category = category or 'general'
    if not categories[category] then return end
    for i, v in ipairs(categories[category]) do
        if v == name then
            table.remove(categories[category], i)
            return
        end
    end
end

-- ---------------------------------------------------------------------------
-- Utility: Find the closest known command name for typo suggestion
-- ---------------------------------------------------------------------------

local function suggestCommand(input)
    if not cfg.suggest_on_typo then return nil end

    local best, bestDist = nil, cfg.typo_threshold + 1
    local lower = string_lower(input)

    for name in pairs(commands) do
        local d = levenshtein(lower, string_lower(name))
        if d < bestDist then
            best = name
            bestDist = d
        end
    end

    return best
end

-- ---------------------------------------------------------------------------
-- Core API
-- ---------------------------------------------------------------------------

--- Register a server command.
--- @param name string command name (no leading slash)
--- @param handler function(source, args, rawArgs)
--- @param options table|nil command options
function Hydra.Commands.Register(name, handler, options)
    if not cfg.enabled then return false end

    name = string_lower(name)
    options = options or {}

    if commands[name] then
        Hydra.Utils.Log('warn', 'Command "/%s" is already registered (module: %s). Skipping.',
            name, tostring(commands[name].module))
        return false
    end

    local cmd = {
        name = name,
        handler = handler,
        description = options.description or '',
        category = options.category or 'general',
        permission = options.permission or nil,
        cooldown = options.cooldown or cfg.cooldown_default,
        aliases = options.aliases or {},
        args = options.args or {},
        serverOnly = options.serverOnly or false,
        restricted = options.restricted or false,
        module = options.module or 'unknown',
        hidden = options.hidden or false,
        _disabled = false,
    }

    commands[name] = cmd
    addToCategory(name, cmd.category)

    -- Register with FiveM
    RegisterCommand(name, buildHandler(name, cmd), cmd.restricted)

    -- Register aliases
    for _, alias in ipairs(cmd.aliases) do
        alias = string_lower(alias)
        if not commands[alias] and not aliases[alias] then
            aliases[alias] = name
            commands[alias] = cmd
            addToCategory(alias, cmd.category)
            RegisterCommand(alias, buildHandler(alias, cmd), cmd.restricted)
        else
            Hydra.Utils.Log('warn', 'Alias "%s" for command "/%s" conflicts with existing command.', alias, name)
        end
    end

    -- Send suggestion data to connected players
    broadcastSuggestion(name, cmd)

    if cfg.debug then
        Hydra.Utils.Log('debug', 'Registered command: /%s (module: %s)', name, cmd.module)
    end

    return true
end

--- Register a client-side command. The handler runs on the client.
--- Server stores metadata and sends registration event to clients.
--- @param name string command name
--- @param options table must include a clientHandler string or rely on client RegisterLocal
function Hydra.Commands.RegisterClient(name, options)
    if not cfg.enabled then return false end

    name = string_lower(name)
    options = options or {}

    if commands[name] then
        Hydra.Utils.Log('warn', 'Command "/%s" is already registered. Cannot register client command.', name)
        return false
    end

    local cmd = {
        name = name,
        handler = nil, -- no server handler
        description = options.description or '',
        category = options.category or 'general',
        permission = options.permission or nil,
        cooldown = options.cooldown or cfg.cooldown_default,
        aliases = options.aliases or {},
        args = options.args or {},
        serverOnly = false,
        restricted = options.restricted or false,
        module = options.module or 'unknown',
        hidden = options.hidden or false,
        clientSide = true,
        _disabled = false,
    }

    commands[name] = cmd
    addToCategory(name, cmd.category)

    -- Store for replication to new clients
    clientCommands[name] = cmd

    -- Notify all connected clients
    TriggerClientEvent('hydra:commands:register', -1, name, {
        description = cmd.description,
        category = cmd.category,
        permission = cmd.permission,
        cooldown = cmd.cooldown,
        aliases = cmd.aliases,
        args = cmd.args,
        restricted = cmd.restricted,
        module = cmd.module,
        hidden = cmd.hidden,
    })

    -- Also register aliases
    for _, alias in ipairs(cmd.aliases) do
        alias = string_lower(alias)
        if not commands[alias] and not aliases[alias] then
            aliases[alias] = name
            commands[alias] = cmd
            addToCategory(alias, cmd.category)
        end
    end

    broadcastSuggestion(name, cmd)

    if cfg.debug then
        Hydra.Utils.Log('debug', 'Registered client command: /%s (module: %s)', name, cmd.module)
    end

    return true
end

--- Unregister a command (cannot un-register from FiveM, but disables it).
--- @param name string
--- @return boolean
function Hydra.Commands.Unregister(name)
    name = string_lower(name)
    local cmd = commands[name]
    if not cmd then return false end

    -- If this is an alias, only remove the alias
    if aliases[name] then
        aliases[name] = nil
        removeFromCategory(name, cmd.category)
        commands[name] = nil
        return true
    end

    -- Disable the command and remove all its aliases
    cmd._disabled = true
    removeFromCategory(name, cmd.category)

    for _, alias in ipairs(cmd.aliases) do
        alias = string_lower(alias)
        aliases[alias] = nil
        removeFromCategory(alias, cmd.category)
        commands[alias] = nil
    end

    commands[name] = nil
    clientCommands[name] = nil

    Hydra.Utils.Log('debug', 'Unregistered command: /%s', name)
    return true
end

--- Check whether a command exists.
--- @param name string
--- @return boolean
function Hydra.Commands.Exists(name)
    return commands[string_lower(name)] ~= nil
end

--- Get information about a command.
--- @param name string
--- @return table|nil
function Hydra.Commands.GetInfo(name)
    local cmd = commands[string_lower(name)]
    if not cmd then return nil end
    return {
        name = cmd.name,
        description = cmd.description,
        category = cmd.category,
        permission = cmd.permission,
        cooldown = cmd.cooldown,
        aliases = cmd.aliases,
        args = cmd.args,
        serverOnly = cmd.serverOnly,
        module = cmd.module,
        hidden = cmd.hidden,
        disabled = cmd._disabled,
        clientSide = cmd.clientSide or false,
    }
end

--- Get all commands, optionally filtered by category.
--- @param category string|nil
--- @return table
function Hydra.Commands.GetAll(category)
    local result = {}
    for name, cmd in pairs(commands) do
        -- Skip aliases so each command appears once
        if not aliases[name] and not cmd._disabled then
            if not category or cmd.category == category then
                result[#result + 1] = Hydra.Commands.GetInfo(name)
            end
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

--- Get all registered categories.
--- @return table
function Hydra.Commands.GetCategories()
    local result = {}
    for cat in pairs(categories) do
        result[#result + 1] = cat
    end
    table.sort(result)
    return result
end

--- Enable or disable a command at runtime.
--- @param name string
--- @param enabled boolean
--- @return boolean
function Hydra.Commands.SetEnabled(name, enabled)
    local cmd = commands[string_lower(name)]
    if not cmd then return false end
    cmd._disabled = not enabled
    return true
end

-- ---------------------------------------------------------------------------
-- Broadcast command suggestion to clients (for chat autocomplete)
-- ---------------------------------------------------------------------------

broadcastSuggestion = function(name, cmd)
    local params = {}
    if cmd.args then
        for _, def in ipairs(cmd.args) do
            params[#params + 1] = {
                name = def.name,
                help = def.help or ('(' .. (def.type or 'string') .. ')'),
            }
        end
    end
    TriggerClientEvent('hydra:commands:suggestions', -1, {
        name = '/' .. name,
        help = cmd.description,
        params = params,
    })
end

-- ---------------------------------------------------------------------------
-- Built-in /help command
-- ---------------------------------------------------------------------------

local function registerHelpCommand()
    Hydra.Commands.Register(cfg.help_command, function(source, args, rawArgs)
        local tokens = tokenize(rawArgs)
        local query = tokens[1]
        local page = tonumber(tokens[2]) or tonumber(tokens[1]) or 1

        -- Specific command help
        if query and not tonumber(query) then
            -- Check if it matches a category
            if categories[string_lower(query)] then
                local catName = string_lower(query)
                local list = Hydra.Commands.GetAll(catName)
                -- Filter by permission
                local visible = {}
                for _, cmd in ipairs(list) do
                    if not cmd.hidden then
                        if not cmd.permission or source == 0 or IsPlayerAceAllowed(source, cmd.permission) then
                            visible[#visible + 1] = cmd
                        end
                    end
                end
                if #visible == 0 then
                    sendMessage(source, 'No commands found in category: ' .. catName, 'info')
                    return
                end
                sendMessage(source, string_format('--- Commands: %s (%d) ---', catName, #visible), 'info')
                for _, cmd in ipairs(visible) do
                    local line = cfg.prefix .. cmd.name
                    if cmd.description ~= '' then
                        line = line .. ' - ' .. cmd.description
                    end
                    sendMessage(source, line, 'info')
                end
                return
            end

            -- Specific command
            local info = Hydra.Commands.GetInfo(query)
            if not info then
                local suggestion = suggestCommand(query)
                if suggestion then
                    sendMessage(source, string_format('Command "/%s" not found. Did you mean /%s?', query, suggestion), 'info')
                else
                    sendMessage(source, string_format('Command "/%s" not found.', query), 'info')
                end
                return
            end

            sendMessage(source, string_format('--- /%s ---', info.name), 'info')
            if info.description ~= '' then
                sendMessage(source, 'Description: ' .. info.description, 'info')
            end
            sendMessage(source, 'Category: ' .. info.category, 'info')
            if info.permission then
                sendMessage(source, 'Permission: ' .. info.permission, 'info')
            end
            if info.module ~= 'unknown' then
                sendMessage(source, 'Module: ' .. info.module, 'info')
            end
            if info.aliases and #info.aliases > 0 then
                sendMessage(source, 'Aliases: ' .. table.concat(info.aliases, ', '), 'info')
            end
            if info.cooldown > 0 then
                sendMessage(source, string_format('Cooldown: %dms', info.cooldown), 'info')
            end
            if info.args and #info.args > 0 then
                sendMessage(source, 'Arguments:', 'info')
                for _, def in ipairs(info.args) do
                    local req = def.required and 'required' or 'optional'
                    local line = string_format('  <%s> (%s, %s)', def.name, def.type or 'string', req)
                    if def.help then
                        line = line .. ' - ' .. def.help
                    end
                    sendMessage(source, line, 'info')
                end
            end

            -- Show usage line
            local usage = cfg.prefix .. info.name
            if info.args and #info.args > 0 then
                for _, def in ipairs(info.args) do
                    if def.required then
                        usage = usage .. ' <' .. def.name .. '>'
                    else
                        usage = usage .. ' [' .. def.name .. ']'
                    end
                end
            end
            sendMessage(source, 'Usage: ' .. usage, 'info')
            return
        end

        -- Paginated command list
        local all = Hydra.Commands.GetAll()
        local visible = {}
        for _, cmd in ipairs(all) do
            if not cmd.hidden then
                if not cmd.permission or source == 0 or IsPlayerAceAllowed(source, cmd.permission) then
                    visible[#visible + 1] = cmd
                end
            end
        end

        local totalPages = math.ceil(#visible / cfg.help_per_page)
        if totalPages == 0 then totalPages = 1 end
        if page < 1 then page = 1 end
        if page > totalPages then page = totalPages end

        local startIdx = (page - 1) * cfg.help_per_page + 1
        local endIdx = math_min(startIdx + cfg.help_per_page - 1, #visible)

        sendMessage(source, string_format('--- Help (Page %d/%d) - %d commands ---', page, totalPages, #visible), 'info')

        for i = startIdx, endIdx do
            local cmd = visible[i]
            local line = cfg.prefix .. cmd.name
            if cmd.description ~= '' then
                line = line .. ' - ' .. cmd.description
            end
            sendMessage(source, line, 'info')
        end

        if totalPages > 1 then
            sendMessage(source, string_format('Use /%s <page> for more. /%s <command> for details.', cfg.help_command, cfg.help_command), 'info')
        end

        -- Show categories
        local cats = Hydra.Commands.GetCategories()
        if #cats > 1 then
            sendMessage(source, 'Categories: ' .. table.concat(cats, ', '), 'info')
        end
    end, {
        description = 'Show available commands and usage information',
        category = 'general',
        module = 'commands',
        args = {
            { name = 'query', type = 'string', required = false, help = 'Command name, category, or page number' },
            { name = 'page', type = 'number', required = false, help = 'Page number', default = 1 },
        },
    })
end

-- ---------------------------------------------------------------------------
-- Unknown command interception (typo suggestions)
-- ---------------------------------------------------------------------------

AddEventHandler('chatCommandNotFound', function(source, command, rawArgs)
    if not cfg.suggest_on_typo then return end
    if source <= 0 then return end

    local suggestion = suggestCommand(command)
    if suggestion then
        sendMessage(source, string_format('%s Did you mean /%s?', cfg.unknown_message, suggestion), 'info')
    else
        sendMessage(source, cfg.unknown_message, 'info')
    end
end)

-- ---------------------------------------------------------------------------
-- Player join: replicate client commands and suggestions
-- ---------------------------------------------------------------------------

AddEventHandler('playerJoining', function()
    local src = source

    -- Send all client command registrations
    for name, cmd in pairs(clientCommands) do
        TriggerClientEvent('hydra:commands:register', src, name, {
            description = cmd.description,
            category = cmd.category,
            permission = cmd.permission,
            cooldown = cmd.cooldown,
            aliases = cmd.aliases,
            args = cmd.args,
            restricted = cmd.restricted,
            module = cmd.module,
            hidden = cmd.hidden,
        })
    end

    -- Send chat suggestions for all registered commands
    for name, cmd in pairs(commands) do
        if not aliases[name] then
            local params = {}
            if cmd.args then
                for _, def in ipairs(cmd.args) do
                    params[#params + 1] = {
                        name = def.name,
                        help = def.help or ('(' .. (def.type or 'string') .. ')'),
                    }
                end
            end
            TriggerClientEvent('hydra:commands:suggestions', src, {
                name = '/' .. name,
                help = cmd.description,
                params = params,
            })
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Cooldown cleanup: periodically remove stale entries
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(60000) -- Every 60 seconds
        local now = GetGameTimer()
        local maxAge = 300000 -- 5 minutes
        for key, ts in pairs(cooldowns) do
            if (now - ts) > maxAge then
                cooldowns[key] = nil
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Server exports
-- ---------------------------------------------------------------------------

exports('Register', Hydra.Commands.Register)
exports('RegisterClient', Hydra.Commands.RegisterClient)
exports('Unregister', Hydra.Commands.Unregister)
exports('Exists', Hydra.Commands.Exists)
exports('GetInfo', Hydra.Commands.GetInfo)
exports('GetAll', Hydra.Commands.GetAll)
exports('GetCategories', Hydra.Commands.GetCategories)
exports('SetEnabled', Hydra.Commands.SetEnabled)

-- ---------------------------------------------------------------------------
-- Module registration and boot
-- ---------------------------------------------------------------------------

Hydra.Modules.Register('commands', {
    label = 'Command System',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 70,
    dependencies = { 'hydra_core' },

    onLoad = function()
        registerHelpCommand()
        Hydra.Utils.Log('info', 'Command system loaded')
    end,

    onReady = function()
        local count = 0
        for name in pairs(commands) do
            if not aliases[name] then count = count + 1 end
        end
        Hydra.Utils.Log('info', 'Command system ready (%d commands registered)', count)
    end,

    api = {
        Register = Hydra.Commands.Register,
        RegisterClient = Hydra.Commands.RegisterClient,
        Unregister = Hydra.Commands.Unregister,
        Exists = Hydra.Commands.Exists,
        GetInfo = Hydra.Commands.GetInfo,
        GetAll = Hydra.Commands.GetAll,
        GetCategories = Hydra.Commands.GetCategories,
        SetEnabled = Hydra.Commands.SetEnabled,
    },
})
