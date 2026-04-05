--[[
    Hydra Bridge - ESX Client Adapter

    Provides ESX client-side compatibility.
    Scripts using ESX client events/functions will work through Hydra.
]]

Hydra = Hydra or {}

local ESXClientBridge = {}

function ESXClientBridge.Init()
    local ESX = {}

    ESX.PlayerData = {}
    ESX.PlayerLoaded = false

    ESX.IsPlayerLoaded = function()
        return Hydra.IsPlayerLoaded()
    end

    ESX.GetPlayerData = function()
        return ESX.PlayerData
    end

    ESX.SetPlayerData = function(key, value)
        ESX.PlayerData[key] = value
    end

    ESX.ShowNotification = function(msg, notifyType, length)
        -- Route through Hydra notification system
        if Hydra.Use and Hydra.Use('notifications') then
            Hydra.Use('notifications').Show(msg, notifyType)
        else
            SetNotificationTextEntry('STRING')
            AddTextComponentString(msg)
            DrawNotification(false, true)
        end
    end

    ESX.ShowHelpNotification = function(msg, thisFrame, beep, duration)
        AddTextEntry('hydra_help', msg)
        DisplayHelpTextThisFrame('hydra_help', false)
    end

    ESX.TriggerServerCallback = function(name, cb, ...)
        Hydra.ClientCallbacks.Trigger(name, cb, ...)
    end

    ESX.UI = ESX.UI or {}
    ESX.UI.Menu = ESX.UI.Menu or {}
    ESX.UI.Menu.Open = function(...) end
    ESX.UI.Menu.Close = function(...) end

    ESX.Game = ESX.Game or {}
    ESX.Game.GetPedMugshot = function(ped, transparent)
        if transparent then
            return RegisterPedheadshot_3(ped)
        else
            return RegisterPedheadshot(ped)
        end
    end

    ESX.Game.Teleport = function(entity, coords, cb)
        SetEntityCoords(entity, coords.x, coords.y, coords.z, false, false, false, true)
        if cb then cb() end
    end

    ESX.Game.SpawnVehicle = function(modelName, coords, heading, cb)
        local model = GetHashKey(modelName)
        RequestModel(model)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(model) and GetGameTimer() < timeout do
            Wait(0)
        end
        if HasModelLoaded(model) then
            local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, false)
            SetModelAsNoLongerNeeded(model)
            if cb then cb(vehicle) end
        end
    end

    ESX.Game.DeleteVehicle = function(vehicle)
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
    end

    ESX.Game.GetClosestVehicle = function(coords)
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

    -- Handle ESX shared object request pattern
    RegisterNetEvent('esx:getSharedObject')
    AddEventHandler('esx:getSharedObject', function(cb)
        if cb then cb(ESX) end
    end)

    -- Update player data when Hydra syncs
    RegisterNetEvent('hydra:store:syncBulk')
    AddEventHandler('hydra:store:syncBulk', function(storeName, data)
        if storeName == 'playerData' then
            for k, v in pairs(data) do
                ESX.PlayerData[k] = v
            end
            ESX.PlayerLoaded = true
            TriggerEvent('esx:playerLoaded', ESX.PlayerData)
        end
    end)

    -- ESX events that scripts listen to
    RegisterNetEvent('esx:playerLoaded')
    RegisterNetEvent('esx:setJob')
    RegisterNetEvent('esx:showNotification')
    RegisterNetEvent('esx:showHelpNotification')

    AddEventHandler('esx:showNotification', function(msg, notifyType)
        ESX.ShowNotification(msg, notifyType)
    end)

    AddEventHandler('esx:showHelpNotification', function(msg, thisFrame, beep, duration)
        ESX.ShowHelpNotification(msg, thisFrame, beep, duration)
    end)

    Hydra.Utils.Log('debug', 'ESX client bridge initialized')
end

Hydra.Bridge.RegisterAdapter('esx', ESXClientBridge)
