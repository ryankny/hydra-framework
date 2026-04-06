--[[
    Hydra Bridge - TMC Client Adapter

    TMC Framework client-side compatibility.
]]

Hydra = Hydra or {}

local TMCClientBridge = {}

function TMCClientBridge.Init()
    local TMC = {}
    TMC.Functions = {}

    TMC.Functions.GetPlayerData = function()
        return Hydra.Data.Store.GetAll('playerData')
    end

    TMC.Functions.Notify = function(msg, notifyType)
        if Hydra.Use and Hydra.Use('notifications') then
            Hydra.Use('notifications').Show(msg, notifyType)
        else
            SetNotificationTextEntry('STRING')
            AddTextComponentString(msg)
            DrawNotification(false, true)
        end
    end

    RegisterNetEvent('tmc:getSharedObject')
    AddEventHandler('tmc:getSharedObject', function(cb)
        if cb then cb(TMC) end
    end)

    Hydra.Utils.Log('debug', 'TMC client bridge initialized')
end

Hydra.Bridge.RegisterAdapter('tmc', TMCClientBridge)
