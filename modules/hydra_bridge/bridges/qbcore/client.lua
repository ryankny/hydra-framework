--[[
    Hydra Bridge - QBCore Client Adapter

    Provides QBCore client-side compatibility.
]]

Hydra = Hydra or {}

local QBClientBridge = {}

function QBClientBridge.Init()
    local QBCore = {}
    QBCore.Functions = {}
    QBCore.PlayerData = {}

    QBCore.Functions.GetPlayerData = function()
        return QBCore.PlayerData
    end

    QBCore.Functions.TriggerCallback = function(name, cb, ...)
        Hydra.ClientCallbacks.Trigger(name, cb, ...)
    end

    QBCore.Functions.Notify = function(text, notifyType, duration)
        if Hydra.Use and Hydra.Use('notifications') then
            Hydra.Use('notifications').Show(text, notifyType, duration)
        else
            SetNotificationTextEntry('STRING')
            AddTextComponentString(text)
            DrawNotification(false, true)
        end
    end

    QBCore.Functions.Progressbar = function(name, label, duration, useWhileDead, canCancel, options, animDict, anim, propObj, onFinish, onCancel)
        -- Route through Hydra progress system if available
        if Hydra.Use and Hydra.Use('progress') then
            Hydra.Use('progress').Start({
                label = label,
                duration = duration,
                canCancel = canCancel,
                anim = animDict and { dict = animDict, clip = anim } or nil,
            }, onFinish, onCancel)
        else
            -- Fallback: simple wait
            Wait(duration)
            if onFinish then onFinish() end
        end
    end

    QBCore.Functions.GetVehicles = function()
        return GetGamePool('CVehicle')
    end

    QBCore.Functions.GetPeds = function()
        return GetGamePool('CPed')
    end

    QBCore.Functions.GetObjects = function()
        return GetGamePool('CObject')
    end

    QBCore.Functions.GetClosestVehicle = function(coords)
        coords = coords or GetEntityCoords(PlayerPedId())
        local vehicles = GetGamePool('CVehicle')
        local closest, closestDist = nil, math.huge
        for _, veh in ipairs(vehicles) do
            local dist = #(coords - GetEntityCoords(veh))
            if dist < closestDist then
                closest = veh
                closestDist = dist
            end
        end
        return closest, closestDist
    end

    QBCore.Functions.GetClosestPed = function(coords)
        coords = coords or GetEntityCoords(PlayerPedId())
        local peds = GetGamePool('CPed')
        local closest, closestDist = nil, math.huge
        local myPed = PlayerPedId()
        for _, ped in ipairs(peds) do
            if ped ~= myPed then
                local dist = #(coords - GetEntityCoords(ped))
                if dist < closestDist then
                    closest = ped
                    closestDist = dist
                end
            end
        end
        return closest, closestDist
    end

    -- QBCore event compatibility
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
    RegisterNetEvent('QBCore:Client:OnPlayerUnload')
    RegisterNetEvent('QBCore:Client:OnJobUpdate')
    RegisterNetEvent('QBCore:Notify')

    AddEventHandler('QBCore:Notify', function(text, notifyType, duration)
        QBCore.Functions.Notify(text, notifyType, duration)
    end)

    -- Sync player data from Hydra
    RegisterNetEvent('hydra:store:syncBulk')
    AddEventHandler('hydra:store:syncBulk', function(storeName, data)
        if storeName == 'playerData' then
            for k, v in pairs(data) do
                QBCore.PlayerData[k] = v
            end
            TriggerEvent('QBCore:Client:OnPlayerLoaded')
        end
    end)

    -- Export for QBCore access
    RegisterNetEvent('QBCore:GetObject')
    AddEventHandler('QBCore:GetObject', function(cb)
        if cb then cb(QBCore) end
    end)

    Hydra.Utils.Log('debug', 'QBCore client bridge initialized')
end

Hydra.Bridge.RegisterAdapter('qbcore', QBClientBridge)
