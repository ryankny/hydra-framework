--[[
    Hydra Notify - Server Main

    Server-side notification dispatch.
    Allows any server script to send notifications to players.
]]

Hydra = Hydra or {}
Hydra.Notify = Hydra.Notify or {}

--- Send a notification to a specific player
--- @param source number player server ID
--- @param data table { title, message, type, duration, position }
function Hydra.Notify.Send(source, data)
    if type(data) == 'string' then
        data = { message = data, type = 'info' }
    end
    TriggerClientEvent('hydra:notify:show', source, data)
end

--- Send a notification to all players
--- @param data table { title, message, type, duration }
function Hydra.Notify.SendAll(data)
    if type(data) == 'string' then
        data = { message = data, type = 'info' }
    end
    TriggerClientEvent('hydra:notify:show', -1, data)
end

--- Register as module
Hydra.Modules.Register('notify', {
    label = 'Hydra Notifications',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 75,

    onLoad = function()
        Hydra.Utils.Log('info', 'Notification system loaded')
    end,

    api = {
        Send = Hydra.Notify.Send,
        SendAll = Hydra.Notify.SendAll,
        Show = function(source, msg, notifyType, duration)
            Hydra.Notify.Send(source, {
                message = msg,
                type = notifyType or 'info',
                duration = duration or 5000,
            })
        end,
    },
})

-- Listen for server-side notification requests
RegisterNetEvent('hydra:notify:server')
AddEventHandler('hydra:notify:server', function(target, data)
    if source ~= 0 then return end -- Server only
    Hydra.Notify.Send(target, data)
end)

-- Exports
exports('Notify', function(source, data) Hydra.Notify.Send(source, data) end)
exports('NotifyAll', function(data) Hydra.Notify.SendAll(data) end)
