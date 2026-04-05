--[[
    Hydra Notify - Client Main

    Receives notifications and sends them to the NUI for rendering.
]]

Hydra = Hydra or {}
Hydra.Notify = Hydra.Notify or {}

--- Show a notification on the local client
--- @param data table|string { title, message, type, duration, position }
function Hydra.Notify.Show(data)
    if type(data) == 'string' then
        data = { message = data, type = 'info' }
    end

    SendNUIMessage({
        module = 'notify',
        action = 'show',
        data = {
            id = Hydra.Utils.GenerateId(),
            title = data.title or nil,
            message = data.message or data.text or '',
            type = data.type or 'info',
            duration = data.duration or 5000,
            position = data.position or 'top-right',
            icon = data.icon or nil,
        },
    })
end

--- Clear all notifications
function Hydra.Notify.Clear()
    SendNUIMessage({
        module = 'notify',
        action = 'clearAll',
        data = {},
    })
end

--- Receive notification from server
RegisterNetEvent('hydra:notify:show')
AddEventHandler('hydra:notify:show', function(data)
    Hydra.Notify.Show(data)
end)

-- NUI ready
RegisterNUICallback('hydra:notify:ready', function(_, cb)
    cb({ success = true })
end)
