--[[
    Hydra Chat - Client

    Manages chat input, NUI communication, channel switching,
    and command suggestions. Intercepts default FiveM chat.
]]

Hydra = Hydra or {}
Hydra.Chat = {}

local cfg = HydraChatConfig
local isChatOpen = false
local currentChannel = cfg.default_channel
local suggestions = {}

-- =============================================
-- NUI COMMUNICATION
-- =============================================

--- Open chat input
function Hydra.Chat.Open()
    if isChatOpen then return end
    isChatOpen = true

    SetNuiFocus(true, false)

    SendNUIMessage({
        module = 'chat',
        action = 'open',
        data = {
            channel = currentChannel,
            channelLabel = getChannelLabel(currentChannel),
            channelColor = getChannelColor(currentChannel),
        },
    })
end

--- Close chat input
function Hydra.Chat.Close()
    if not isChatOpen then return end
    isChatOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({
        module = 'chat',
        action = 'close',
    })
end

--- Toggle chat
function Hydra.Chat.Toggle()
    if isChatOpen then
        Hydra.Chat.Close()
    else
        Hydra.Chat.Open()
    end
end

-- =============================================
-- RECEIVE MESSAGES
-- =============================================

RegisterNetEvent('hydra:chat:receiveMessage')
AddEventHandler('hydra:chat:receiveMessage', function(data)
    SendNUIMessage({
        module = 'chat',
        action = 'message',
        data = data,
    })
end)

RegisterNetEvent('hydra:chat:systemMessage')
AddEventHandler('hydra:chat:systemMessage', function(data)
    SendNUIMessage({
        module = 'chat',
        action = 'system',
        data = data,
    })
end)

RegisterNetEvent('hydra:chat:switchChannel')
AddEventHandler('hydra:chat:switchChannel', function(channel)
    currentChannel = channel
    SendNUIMessage({
        module = 'chat',
        action = 'switchChannel',
        data = {
            channel = channel,
            channelLabel = getChannelLabel(channel),
            channelColor = getChannelColor(channel),
        },
    })
end)

RegisterNetEvent('hydra:chat:clear')
AddEventHandler('hydra:chat:clear', function()
    SendNUIMessage({
        module = 'chat',
        action = 'clear',
    })
end)

RegisterNetEvent('hydra:chat:addSuggestion')
AddEventHandler('hydra:chat:addSuggestion', function(data)
    suggestions[data.name] = data
    SendNUIMessage({
        module = 'chat',
        action = 'addSuggestion',
        data = data,
    })
end)

-- =============================================
-- NUI CALLBACKS
-- =============================================

--- Chat message submitted
RegisterNUICallback('chat:send', function(data, cb)
    isChatOpen = false
    SetNuiFocus(false, false)

    local message = data.message
    if not message or #message == 0 then
        cb({ ok = true })
        return
    end

    -- Check if it's a command
    if message:sub(1, 1) == cfg.command_prefix then
        -- Let FiveM handle the command natively
        ExecuteCommand(message:sub(2))
    else
        -- Send as chat message
        TriggerServerEvent('hydra:chat:sendMessage', currentChannel, message)
    end

    cb({ ok = true })
end)

--- Chat input closed (escape)
RegisterNUICallback('chat:close', function(_, cb)
    isChatOpen = false
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

--- Channel cycle (tab key in chat)
RegisterNUICallback('chat:cycleChannel', function(_, cb)
    local channels = {}
    for name, ch in pairs(cfg.channels) do
        if not ch.permission or IsPlayerAceAllowed(PlayerId(), ch.permission or '') then
            channels[#channels + 1] = name
        end
    end
    table.sort(channels)

    local currentIdx = 1
    for i, name in ipairs(channels) do
        if name == currentChannel then
            currentIdx = i
            break
        end
    end

    local nextIdx = (currentIdx % #channels) + 1
    currentChannel = channels[nextIdx]

    cb({
        ok = true,
        channel = currentChannel,
        channelLabel = getChannelLabel(currentChannel),
        channelColor = getChannelColor(currentChannel),
    })
end)

-- =============================================
-- KEYBIND - T to open chat
-- =============================================

RegisterCommand('hydra_chat_open', function()
    Hydra.Chat.Open()
end, false)

RegisterKeyMapping('hydra_chat_open', 'Open Chat', 'keyboard', 'T')

-- Disable default FiveM chat
CreateThread(function()
    Wait(1000)
    -- Override the default chat resource behavior
    TriggerEvent('chat:addTemplate', 'hydra_override', '<div></div>')
end)

-- =============================================
-- HELPERS
-- =============================================

function getChannelLabel(channel)
    local ch = cfg.channels[channel]
    return ch and ch.label or channel
end

function getChannelColor(channel)
    local ch = cfg.channels[channel]
    return ch and ch.color or '#A0A0B8'
end

-- =============================================
-- EXPORTS
-- =============================================

exports('OpenChat', function() Hydra.Chat.Open() end)
exports('CloseChat', function() Hydra.Chat.Close() end)
exports('IsChatOpen', function() return isChatOpen end)
