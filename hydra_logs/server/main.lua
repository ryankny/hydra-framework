--[[
    Hydra Logs - Server Main

    Public API for sending logs. Modules and scripts call
    Hydra.Logs.Send() or use the channel-specific helpers.
    Also hooks into framework events for automatic logging.
]]

Hydra = Hydra or {}
Hydra.Logs = Hydra.Logs or {}

local cfg = HydraLogsConfig

-- =============================================
-- PUBLIC API
-- =============================================

--- Send a log to a channel
--- @param channel string channel name from config
--- @param data table
---   title       string
---   description string
---   fields      table[]|nil
---   source      number|nil   player source (auto-adds identifier fields)
---   color       number|nil   override channel color
---   footer      string|nil
function Hydra.Logs.Send(channel, data)
    if not cfg.enabled then return end

    local ch = cfg.channels[channel]
    if not ch or not ch.enabled then return end

    local url = ch.url
    if not url or url == '' then
        url = cfg.default_url
    end
    if not url or url == '' then return end

    -- Build fields
    local fields = data.fields or {}

    -- Add player identifiers if source provided
    if data.source and data.source > 0 then
        local playerFields = Hydra.Logs._GetPlayerFields(data.source)
        for _, f in ipairs(playerFields) do
            table.insert(fields, 1, f)
        end
    end

    local embed = Hydra.Logs._BuildEmbed({
        title = ('[%s] %s'):format(ch.label or channel, data.title or ''),
        description = data.description or '',
        color = data.color or ch.color,
        fields = fields,
        footer = data.footer,
    })

    Hydra.Logs._Enqueue(url, embed)
end

--- Quick log helper - just title + description
--- @param channel string
--- @param title string
--- @param description string
--- @param src number|nil
function Hydra.Logs.Quick(channel, title, description, src)
    Hydra.Logs.Send(channel, {
        title = title,
        description = description,
        source = src,
    })
end

-- =============================================
-- CHANNEL-SPECIFIC HELPERS
-- =============================================

function Hydra.Logs.Connection(src, message)
    Hydra.Logs.Send('connections', {
        title = 'Player Connected',
        description = message or '',
        source = src,
    })
end

function Hydra.Logs.Disconnection(src, reason)
    Hydra.Logs.Send('disconnections', {
        title = 'Player Disconnected',
        description = reason or 'No reason',
        source = src,
    })
end

function Hydra.Logs.Chat(src, channel, message)
    Hydra.Logs.Send('chat', {
        title = 'Chat Message',
        description = message,
        source = src,
        fields = {
            { name = 'Channel', value = channel or 'global', inline = true },
        },
    })
end

function Hydra.Logs.Death(src, killerId, cause)
    local fields = {}
    if killerId and killerId > 0 then
        local killerFields = Hydra.Logs._GetPlayerFields(killerId)
        for _, f in ipairs(killerFields) do
            f.name = 'Killer ' .. f.name
            fields[#fields + 1] = f
        end
    end
    if cause then
        fields[#fields + 1] = { name = 'Cause', value = cause, inline = true }
    end

    Hydra.Logs.Send('deaths', {
        title = killerId and killerId > 0 and 'Player Killed' or 'Player Died',
        description = '',
        source = src,
        fields = fields,
    })
end

function Hydra.Logs.Money(src, action, account, amount, newBalance)
    Hydra.Logs.Send('money', {
        title = 'Money ' .. (action or 'Transaction'),
        source = src,
        fields = {
            { name = 'Action', value = action or 'unknown', inline = true },
            { name = 'Account', value = account or 'cash', inline = true },
            { name = 'Amount', value = ('$%s'):format(tostring(amount or 0)), inline = true },
            { name = 'New Balance', value = newBalance and ('$%s'):format(tostring(newBalance)) or 'N/A', inline = true },
        },
    })
end

function Hydra.Logs.Admin(src, action, details)
    Hydra.Logs.Send('admin', {
        title = 'Admin Action',
        description = details or '',
        source = src,
        fields = {
            { name = 'Action', value = action or 'unknown', inline = true },
        },
    })
end

function Hydra.Logs.Job(src, oldJob, newJob)
    Hydra.Logs.Send('jobs', {
        title = 'Job Changed',
        source = src,
        fields = {
            { name = 'Old Job', value = oldJob or 'none', inline = true },
            { name = 'New Job', value = newJob or 'none', inline = true },
        },
    })
end

function Hydra.Logs.AntiCheat(src, detection, details)
    Hydra.Logs.Send('anticheat', {
        title = 'Detection: ' .. (detection or 'Unknown'),
        description = details or '',
        source = src,
    })
end

-- =============================================
-- AUTOMATIC FRAMEWORK HOOKS
-- =============================================

-- Player connect
AddEventHandler('playerConnecting', function(name, _, deferrals)
    local src = source
    Hydra.Logs.Connection(src, ('**%s** is connecting to the server.'):format(name))
end)

-- Player drop
AddEventHandler('playerDropped', function(reason)
    local src = source
    local name = GetPlayerName(src) or 'Unknown'
    Hydra.Logs.Disconnection(src, ('**%s** disconnected: %s'):format(name, reason or 'Unknown'))
end)

-- Death hook (if hydra_death fires this event)
AddEventHandler('hydra:death:playerDied', function(src)
    local name = GetPlayerName(src) or 'Unknown'
    Hydra.Logs.Death(src, nil, 'Died')
end)

-- =============================================
-- MODULE REGISTRATION
-- =============================================

Hydra.Modules.Register('logs', {
    label = 'Hydra Logs',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 90, -- Load early so other modules can log
    dependencies = {},

    onLoad = function()
        local activeChannels = 0
        for _, ch in pairs(cfg.channels) do
            if ch.enabled and (ch.url ~= '' or cfg.default_url ~= '') then
                activeChannels = activeChannels + 1
            end
        end
        Hydra.Utils.Log('info', 'Logs module loaded - %d channels configured', activeChannels)
    end,

    api = {
        Send = function(...) Hydra.Logs.Send(...) end,
        Quick = function(...) Hydra.Logs.Quick(...) end,
        Connection = function(...) Hydra.Logs.Connection(...) end,
        Disconnection = function(...) Hydra.Logs.Disconnection(...) end,
        Chat = function(...) Hydra.Logs.Chat(...) end,
        Death = function(...) Hydra.Logs.Death(...) end,
        Money = function(...) Hydra.Logs.Money(...) end,
        Admin = function(...) Hydra.Logs.Admin(...) end,
        Job = function(...) Hydra.Logs.Job(...) end,
        AntiCheat = function(...) Hydra.Logs.AntiCheat(...) end,
    },
})

-- Exports
exports('LogSend', function(...) Hydra.Logs.Send(...) end)
exports('LogQuick', function(...) Hydra.Logs.Quick(...) end)
exports('LogConnection', function(...) Hydra.Logs.Connection(...) end)
exports('LogDisconnection', function(...) Hydra.Logs.Disconnection(...) end)
exports('LogChat', function(...) Hydra.Logs.Chat(...) end)
exports('LogDeath', function(...) Hydra.Logs.Death(...) end)
exports('LogMoney', function(...) Hydra.Logs.Money(...) end)
exports('LogAdmin', function(...) Hydra.Logs.Admin(...) end)
exports('LogJob', function(...) Hydra.Logs.Job(...) end)
exports('LogAntiCheat', function(...) Hydra.Logs.AntiCheat(...) end)
