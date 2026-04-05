--[[
    Hydra Chat - Built-in Commands

    Common server commands registered through the chat system.
]]

Hydra = Hydra or {}

-- Wait for module system to be ready
CreateThread(function()
    Wait(3000)

    -- /players - show online player count
    Hydra.Chat.RegisterCommand('players', function(src)
        local count = #GetPlayers()
        Hydra.Chat.SystemMessage(src, ('There are %d players online.'):format(count), '#74B9FF')
    end, {
        description = 'Show online player count',
    })

    -- /id - show your server ID
    Hydra.Chat.RegisterCommand('id', function(src)
        if src <= 0 then return end
        Hydra.Chat.SystemMessage(src, ('Your server ID is: %d'):format(src), '#74B9FF')
    end, {
        description = 'Show your server ID',
    })

    -- /report - send a report to admins
    Hydra.Chat.RegisterCommand('report', function(src, args)
        if src <= 0 then return end
        if #args == 0 then
            Hydra.Chat.SystemMessage(src, 'Usage: /report [message]', '#A0A0B8')
            return
        end

        local message = table.concat(args, ' ')
        local name = GetPlayerName(src) or 'Unknown'

        -- Send to all admins
        local players = GetPlayers()
        for _, pSrc in ipairs(players) do
            local p = tonumber(pSrc)
            if p and IsPlayerAceAllowed(p, 'hydra.admin') then
                TriggerClientEvent('hydra:chat:systemMessage', p, {
                    message = ('[REPORT] %s (ID: %d): %s'):format(name, src, message),
                    color = '#FDCB6E',
                })
            end
        end

        Hydra.Chat.SystemMessage(src, 'Report sent to online staff.', '#00B894')

        -- Log
        if Hydra.Logs then
            Hydra.Logs.Quick('admin', 'Player Report', message, src)
        end
    end, {
        description = 'Send a report to online staff',
    })

    -- /pm [id] [message] - private message
    Hydra.Chat.RegisterCommand('pm', function(src, args)
        if src <= 0 then return end
        if #args < 2 then
            Hydra.Chat.SystemMessage(src, 'Usage: /pm [id] [message]', '#A0A0B8')
            return
        end

        local targetId = tonumber(args[1])
        if not targetId or not GetPlayerName(targetId) then
            Hydra.Chat.SystemMessage(src, 'Player not found.', '#FF7675')
            return
        end

        table.remove(args, 1)
        local message = table.concat(args, ' ')
        local senderName = GetPlayerName(src) or 'Unknown'
        local targetName = GetPlayerName(targetId) or 'Unknown'

        -- Send to target
        TriggerClientEvent('hydra:chat:receiveMessage', targetId, {
            channel = 'PM',
            channelColor = '#DDA0DD',
            name = senderName,
            playerId = src,
            message = message,
            tags = {},
            format = '[PM from {name}]: {message}',
            timestamp = os.date('%H:%M'),
        })

        -- Confirm to sender
        TriggerClientEvent('hydra:chat:receiveMessage', src, {
            channel = 'PM',
            channelColor = '#DDA0DD',
            name = targetName,
            playerId = targetId,
            message = message,
            tags = {},
            format = '[PM to {name}]: {message}',
            timestamp = os.date('%H:%M'),
        })
    end, {
        description = 'Send a private message',
        suggestion_args = { { name = 'id', help = 'Player ID' }, { name = 'message', help = 'Message' } },
    })
end)
