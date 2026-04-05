--[[
    Hydra Bridge - QBox Client Adapter

    QBox client-side compatibility. Extends QBCore client bridge.
]]

Hydra = Hydra or {}

local QBoxClientBridge = {}

function QBoxClientBridge.Init()
    -- Initialize QBCore client bridge as base
    local qbAdapter = Hydra.Bridge.GetAdapter('qbcore')
    if qbAdapter and qbAdapter.Init then
        qbAdapter.Init()
    end

    -- QBox-specific client events
    RegisterNetEvent('qbx_core:client:playerLoaded')
    RegisterNetEvent('qbx_core:client:playerLoggedOut')

    -- QBox uses slightly different notification pattern
    RegisterNetEvent('qbx_core:client:notify')
    AddEventHandler('qbx_core:client:notify', function(text, notifyType, duration)
        if Hydra.Use and Hydra.Use('notifications') then
            Hydra.Use('notifications').Show(text, notifyType, duration)
        else
            SetNotificationTextEntry('STRING')
            AddTextComponentString(text)
            DrawNotification(false, true)
        end
    end)

    Hydra.Utils.Log('debug', 'QBox client bridge initialized')
end

Hydra.Bridge.RegisterAdapter('qbox', QBoxClientBridge)
