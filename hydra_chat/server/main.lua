--[[
    Hydra Chat - Server

    Message routing, channel management, proximity calculation,
    spam protection, word filtering, and Discord log integration.
]]

Hydra = Hydra or {}
Hydra.Chat = {}

local cfg = HydraChatConfig

-- Mute state: [source] = expiry os.time()
local mutedPlayers = {}

-- Spam tracking: [source] = { timestamps }
local spamTracker = {}

-- Registered server commands: [name] = { handler, description, permission }
local registeredCommands = {}

-- =============================================
-- MESSAGE HANDLING
-- =============================================

--- Process and route a chat message
--- @param src number player source
--- @param channel string channel name
--- @param message string raw message text
function Hydra.Chat.ProcessMessage(src, channel, message)
    if not src or src <= 0 then return end

    -- Validate channel
    local ch = cfg.channels[channel]
    if not ch then
        channel = cfg.default_channel
        ch = cfg.channels[channel]
    end
    if not ch then return end

    -- Permission check
    if ch.permission and not IsPlayerAceAllowed(src, ch.permission) then
        TriggerClientEvent('hydra:chat:systemMessage', src, {
            message = 'You do not have permission to use this channel.',
            color = '#FF7675',
        })
        return
    end

    -- Mute check
    if mutedPlayers[src] then
        if os.time() < mutedPlayers[src] then
            local remaining = mutedPlayers[src] - os.time()
            TriggerClientEvent('hydra:chat:systemMessage', src, {
                message = ('You are muted for %d more seconds.'):format(remaining),
                color = '#FF7675',
            })
            return
        else
            mutedPlayers[src] = nil
        end
    end

    -- Spam protection
    if cfg.spam_protection.enabled then
        if not spamTracker[src] then spamTracker[src] = {} end
        local now = os.time()
        local tracker = spamTracker[src]

        -- Clean old entries
        local clean = {}
        for _, ts in ipairs(tracker) do
            if now - ts < cfg.spam_protection.window then
                clean[#clean + 1] = ts
            end
        end
        spamTracker[src] = clean

        -- Check count
        if #clean >= cfg.spam_protection.max_messages then
            mutedPlayers[src] = now + cfg.spam_protection.cooldown
            TriggerClientEvent('hydra:chat:systemMessage', src, {
                message = ('Spam detected. Muted for %d seconds.'):format(cfg.spam_protection.cooldown),
                color = '#FF7675',
            })
            return
        end

        clean[#clean + 1] = now
        spamTracker[src] = clean
    end

    -- Message length
    if #message > cfg.max_message_length then
        message = message:sub(1, cfg.max_message_length)
    end

    -- Sanitize: strip color codes and trim
    message = message:gsub('%^%d', ''):gsub('<[^>]+>', '')
    message = message:match('^%s*(.-)%s*$') or message
    if #message == 0 then return end

    -- Word filter
    if cfg.word_filter.enabled and #cfg.word_filter.words > 0 then
        local lowerMsg = message:lower()
        for _, word in ipairs(cfg.word_filter.words) do
            local pattern = word:lower():gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]', '%%%1')
            if lowerMsg:find(pattern) then
                if cfg.word_filter.action == 'block' then
                    TriggerClientEvent('hydra:chat:systemMessage', src, {
                        message = 'Message blocked by word filter.',
                        color = '#FF7675',
                    })
                    return
                else
                    -- Case-insensitive replace: build char-class pattern
                    local ciPattern = word:gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]', '%%%1'):gsub('%a', function(c)
                        return '[' .. c:upper() .. c:lower() .. ']'
                    end)
                    message = message:gsub(ciPattern, string.rep('*', #word))
                end
            end
        end
    end

    -- Build formatted message
    local name = GetPlayerName(src) or 'Unknown'
    local formatted = buildFormattedMessage(src, ch, name, message)

    -- Route message
    if ch.proximity then
        -- Proximity: only send to nearby players
        local srcPed = GetPlayerPed(src)
        if srcPed == 0 then return end
        local srcCoords = GetEntityCoords(srcPed)
        local range = ch.range or 30.0

        local players = GetPlayers()
        for _, playerSrc in ipairs(players) do
            local pSrc = tonumber(playerSrc)
            if pSrc then
                if pSrc == src then
                    TriggerClientEvent('hydra:chat:receiveMessage', pSrc, formatted)
                else
                    local targetPed = GetPlayerPed(pSrc)
                    if targetPed ~= 0 then
                        local targetCoords = GetEntityCoords(targetPed)
                        local dist = #(srcCoords - targetCoords)
                        if dist <= range then
                            TriggerClientEvent('hydra:chat:receiveMessage', pSrc, formatted)
                        end
                    end
                end
            end
        end
    else
        -- Global: send to all
        TriggerClientEvent('hydra:chat:receiveMessage', -1, formatted)
    end

    -- Log to Discord
    if cfg.log_to_discord and Hydra.Logs and Hydra.Logs.Chat then
        Hydra.Logs.Chat(src, channel, message)
    end
end

--- Build the formatted message payload for clients
--- @param src number
--- @param ch table channel config
--- @param name string player name
--- @param message string
--- @return table
function buildFormattedMessage(src, ch, name, message)
    local tags = {}

    -- Job tag
    if cfg.show_job_tag and Hydra.Players then
        local player = Hydra.Players.GetPlayer(src)
        if player and player.job and player.job.label then
            tags[#tags + 1] = {
                text = player.job.label,
                color = ch.color,
            }
        end
    end

    -- Admin tag
    if cfg.show_admin_tag and IsPlayerAceAllowed(src, 'hydra.admin') then
        tags[#tags + 1] = {
            text = cfg.admin_tag,
            color = cfg.admin_tag_color,
        }
    end

    return {
        channel = ch.label,
        channelColor = ch.color,
        name = name,
        playerId = src,
        message = message,
        tags = tags,
        format = ch.format,
        timestamp = os.date('%H:%M'),
    }
end

-- =============================================
-- SYSTEM MESSAGES
-- =============================================

--- Send a system message to a player
--- @param src number (-1 for all)
--- @param message string
--- @param color string|nil hex color
function Hydra.Chat.SystemMessage(src, message, color)
    TriggerClientEvent('hydra:chat:systemMessage', src, {
        message = message,
        color = color or '#A0A0B8',
    })
end

--- Send an announcement to all players
--- @param message string
function Hydra.Chat.Announce(message)
    Hydra.Chat.SystemMessage(-1, message, '#FF7675')
end

-- =============================================
-- MUTE MANAGEMENT
-- =============================================

--- Mute a player
--- @param src number
--- @param duration number seconds (0 = permanent until unmute)
function Hydra.Chat.Mute(src, duration)
    if duration and duration > 0 then
        mutedPlayers[src] = os.time() + duration
    else
        mutedPlayers[src] = os.time() + 999999999
    end
end

--- Unmute a player
--- @param src number
function Hydra.Chat.Unmute(src)
    mutedPlayers[src] = nil
end

--- Check if muted
--- @param src number
--- @return boolean
function Hydra.Chat.IsMuted(src)
    if not mutedPlayers[src] then return false end
    if os.time() >= mutedPlayers[src] then
        mutedPlayers[src] = nil
        return false
    end
    return true
end

-- =============================================
-- EVENTS
-- =============================================

--- Client sends a message
RegisterNetEvent('hydra:chat:sendMessage')
AddEventHandler('hydra:chat:sendMessage', function(channel, message)
    local src = source
    if type(channel) ~= 'string' or type(message) ~= 'string' then return end
    Hydra.Chat.ProcessMessage(src, channel, message)
end)

--- Player drop cleanup
AddEventHandler('playerDropped', function()
    local src = source
    spamTracker[src] = nil
end)

-- =============================================
-- COMMAND REGISTRATION API
-- =============================================

--- Register a chat command (for other scripts)
--- @param name string command name (without /)
--- @param handler function(src, args, rawMessage)
--- @param opts table|nil { description, permission, suggestion_args }
function Hydra.Chat.RegisterCommand(name, handler, opts)
    opts = opts or {}
    registeredCommands[name] = {
        handler = handler,
        description = opts.description or '',
        permission = opts.permission or nil,
    }

    RegisterCommand(name, function(src, args, rawMessage)
        if src <= 0 then
            -- Console
            handler(0, args, rawMessage)
            return
        end

        if opts.permission and not IsPlayerAceAllowed(src, opts.permission) then
            TriggerClientEvent('hydra:chat:systemMessage', src, {
                message = 'You do not have permission to use this command.',
                color = '#FF7675',
            })
            return
        end

        handler(src, args, rawMessage)
    end, false)

    -- Send suggestion to clients
    TriggerClientEvent('hydra:chat:addSuggestion', -1, {
        name = '/' .. name,
        description = opts.description or '',
        args = opts.suggestion_args or {},
    })
end

--- Send command suggestions on player join
local function sendSuggestions(src)
    for name, cmd in pairs(registeredCommands) do
        TriggerClientEvent('hydra:chat:addSuggestion', src, {
            name = '/' .. name,
            description = cmd.description or '',
        })
    end

    -- Channel command suggestions
    for channel, cmdName in pairs(cfg.channel_commands) do
        local ch = cfg.channels[channel]
        if ch then
            TriggerClientEvent('hydra:chat:addSuggestion', src, {
                name = '/' .. cmdName,
                description = ('Send message in %s channel'):format(ch.label),
            })
        end
    end
end

-- =============================================
-- CHANNEL SHORTCUT COMMANDS
-- =============================================

for channel, cmdName in pairs(cfg.channel_commands) do
    RegisterCommand(cmdName, function(src, args)
        if src <= 0 then return end
        if #args == 0 then
            -- Switch default channel
            TriggerClientEvent('hydra:chat:switchChannel', src, channel)
            return
        end
        local message = table.concat(args, ' ')
        Hydra.Chat.ProcessMessage(src, channel, message)
    end, false)
end

-- =============================================
-- MODERATION COMMANDS
-- =============================================

RegisterCommand('mute', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, cfg.mute_permission) then
        TriggerClientEvent('hydra:chat:systemMessage', src, {
            message = 'No permission.', color = '#FF7675',
        })
        return
    end

    local targetId = tonumber(args[1])
    local duration = tonumber(args[2]) or 300
    if not targetId then
        local msg = 'Usage: /mute [id] [seconds]'
        if src > 0 then
            TriggerClientEvent('hydra:chat:systemMessage', src, { message = msg })
        else
            print(msg)
        end
        return
    end

    Hydra.Chat.Mute(targetId, duration)
    local targetName = GetPlayerName(targetId) or 'Unknown'

    if src > 0 then
        TriggerClientEvent('hydra:chat:systemMessage', src, {
            message = ('Muted %s for %d seconds.'):format(targetName, duration),
            color = '#FDCB6E',
        })
    end
    TriggerClientEvent('hydra:chat:systemMessage', targetId, {
        message = ('You have been muted for %d seconds.'):format(duration),
        color = '#FF7675',
    })

    if Hydra.Logs then
        Hydra.Logs.Admin(src > 0 and src or nil, 'Mute', ('%s muted for %ds'):format(targetName, duration))
    end
end, false)

RegisterCommand('unmute', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, cfg.mute_permission) then return end

    local targetId = tonumber(args[1])
    if not targetId then return end

    Hydra.Chat.Unmute(targetId)
    TriggerClientEvent('hydra:chat:systemMessage', targetId, {
        message = 'You have been unmuted.', color = '#00B894',
    })
end, false)

RegisterCommand('clear', function(src)
    if src > 0 then
        TriggerClientEvent('hydra:chat:clear', src)
    end
end, false)

RegisterCommand('clearall', function(src)
    if src > 0 and not IsPlayerAceAllowed(src, 'hydra.admin') then return end
    TriggerClientEvent('hydra:chat:clear', -1)
end, false)

-- =============================================
-- MODULE REGISTRATION
-- =============================================

Hydra.Modules.Register('chat', {
    label = 'Hydra Chat',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 85,
    dependencies = {},

    onLoad = function()
        Hydra.Utils.Log('info', 'Chat module loaded')
    end,

    onPlayerJoin = function(src)
        sendSuggestions(src)

        -- Welcome message
        Wait(2000)
        TriggerClientEvent('hydra:chat:systemMessage', src, {
            message = 'Welcome to the server! Type /ooc for out-of-character chat.',
            color = '#6C5CE7',
        })
    end,

    api = {
        ProcessMessage = function(...) Hydra.Chat.ProcessMessage(...) end,
        SystemMessage = function(...) Hydra.Chat.SystemMessage(...) end,
        Announce = function(...) Hydra.Chat.Announce(...) end,
        RegisterCommand = function(...) Hydra.Chat.RegisterCommand(...) end,
        Mute = function(...) Hydra.Chat.Mute(...) end,
        Unmute = function(...) Hydra.Chat.Unmute(...) end,
        IsMuted = function(...) return Hydra.Chat.IsMuted(...) end,
    },
})

exports('ChatSystemMessage', function(...) Hydra.Chat.SystemMessage(...) end)
exports('ChatAnnounce', function(...) Hydra.Chat.Announce(...) end)
exports('ChatRegisterCommand', function(...) Hydra.Chat.RegisterCommand(...) end)
exports('ChatMute', function(...) Hydra.Chat.Mute(...) end)
exports('ChatUnmute', function(...) Hydra.Chat.Unmute(...) end)

-- Use core GetPlayers if available, otherwise local fallback
if not GetPlayers or type(GetPlayers) ~= 'function' then
    function GetPlayers()
        local players = {}
        for i = 0, GetNumPlayerIndices() - 1 do
            players[#players + 1] = GetPlayerFromIndex(i)
        end
        return players
    end
end
