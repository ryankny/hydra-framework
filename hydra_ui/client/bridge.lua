--[[
    Hydra UI - Client Bridge Integration

    Intercepts legacy framework notification/UI events and routes
    them through Hydra's UI system.
]]

Hydra = Hydra or {}

--- Wait for framework to be ready
CreateThread(function()
    while not Hydra.IsReady() do Wait(100) end

    -- ========================================
    -- ESX Notification Intercepts
    -- ========================================
    RegisterNetEvent('esx:showNotification')
    AddEventHandler('esx:showNotification', function(msg, notifyType, duration)
        local nType = 'info'
        if notifyType == 'error' then nType = 'error'
        elseif notifyType == 'success' then nType = 'success'
        elseif notifyType == 'warning' then nType = 'warning'
        end
        Hydra.UI.Send('notify', 'show', {
            title = 'Notification',
            message = msg,
            type = nType,
            duration = duration or 5000,
        })
    end)

    RegisterNetEvent('esx:showHelpNotification')
    AddEventHandler('esx:showHelpNotification', function(msg)
        Hydra.UI.Send('notify', 'show', {
            title = 'Help',
            message = msg,
            type = 'info',
            duration = 7000,
        })
    end)

    RegisterNetEvent('esx:showAdvancedNotification')
    AddEventHandler('esx:showAdvancedNotification', function(sender, subject, msg, textureDict, iconType, flash, saveToBrief, hudColorIndex)
        Hydra.UI.Send('notify', 'show', {
            title = sender or 'Notification',
            message = (subject and subject .. ': ' or '') .. (msg or ''),
            type = 'info',
            duration = 5000,
        })
    end)

    -- ========================================
    -- QBCore Notification Intercepts
    -- ========================================
    RegisterNetEvent('QBCore:Notify')
    AddEventHandler('QBCore:Notify', function(text, notifyType, duration, subTitle, notifyPosition, style, icon)
        local nType = 'info'
        if notifyType == 'error' or notifyType == 'danger' then nType = 'error'
        elseif notifyType == 'success' then nType = 'success'
        elseif notifyType == 'warning' then nType = 'warning'
        elseif notifyType == 'primary' then nType = 'info'
        end
        Hydra.UI.Send('notify', 'show', {
            title = subTitle or 'Notification',
            message = text,
            type = nType,
            duration = duration or 5000,
        })
    end)

    -- QBox notification intercept
    RegisterNetEvent('qbx_core:client:notify')
    AddEventHandler('qbx_core:client:notify', function(data)
        if type(data) == 'table' then
            local nType = 'info'
            if data.type == 'error' or data.type == 'danger' then nType = 'error'
            elseif data.type == 'success' then nType = 'success'
            elseif data.type == 'warning' then nType = 'warning'
            end
            Hydra.UI.Send('notify', 'show', {
                title = data.title or 'Notification',
                message = data.description or data.text or '',
                type = nType,
                duration = data.duration or 5000,
            })
        elseif type(data) == 'string' then
            Hydra.UI.Send('notify', 'show', {
                title = 'Notification',
                message = data,
                type = 'info',
                duration = 5000,
            })
        end
    end)

    -- ox_lib notification intercept
    RegisterNetEvent('ox_lib:notify')
    AddEventHandler('ox_lib:notify', function(data)
        if type(data) == 'table' then
            Hydra.UI.Send('notify', 'show', {
                title = data.title or 'Notification',
                message = data.description or data.message or '',
                type = data.type or 'info',
                duration = data.duration or 5000,
            })
        end
    end)

    -- ========================================
    -- TMC Notification Intercepts
    -- ========================================
    RegisterNetEvent('tmc:notify')
    AddEventHandler('tmc:notify', function(msg, notifyType, duration)
        Hydra.UI.Send('notify', 'show', {
            title = 'Notification',
            message = msg,
            type = notifyType or 'info',
            duration = duration or 5000,
        })
    end)

    Hydra.Utils.Log('debug', 'UI bridge intercepts registered')
end)
