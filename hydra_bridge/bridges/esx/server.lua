--[[
    Hydra Bridge - ESX Server Adapter

    Intercepts ESX server-side calls and routes them through Hydra.
    ESX scripts think they're talking to ESX, but Hydra handles everything.

    Supports: es_extended (ESX Legacy and older versions)
]]

Hydra = Hydra or {}

local ESXBridge = {}

--- Initialize the ESX bridge - create the ESX shared object that scripts expect
function ESXBridge.Init()
    -- Create the global ESX object that scripts will access
    local ESX = {}

    -- Player management
    ESX.GetPlayerFromId = function(source)
        local Players = Hydra.Use('players')
        if not Players then return nil end
        local playerData = Players.GetPlayer(source)
        if not playerData then return nil end
        return ESXBridge._WrapPlayer(source, playerData)
    end

    ESX.GetPlayerFromIdentifier = function(identifier)
        local Players = Hydra.Use('players')
        if not Players then return nil end
        local src = Players.GetPlayerByIdentifier(identifier)
        if not src then return nil end
        local playerData = Players.GetPlayer(src)
        if not playerData then return nil end
        return ESXBridge._WrapPlayer(src, playerData)
    end

    ESX.GetPlayers = function()
        local Players = Hydra.Use('players')
        if not Players then return {} end
        return Players.GetAllPlayerIds()
    end

    ESX.GetExtendedPlayers = function(key, value)
        local Players = Hydra.Use('players')
        if not Players then return {} end
        local all = Players.GetAllPlayers()
        local result = {}
        for src, data in pairs(all) do
            if not key or data[key] == value then
                result[#result + 1] = ESXBridge._WrapPlayer(src, data)
            end
        end
        return result
    end

    -- Job functions
    ESX.GetJobs = function()
        local Players = Hydra.Use('players')
        return Players and Players.GetJobs() or {}
    end

    -- Usable items
    ESX.RegisterUsableItem = function(name, cb)
        local Players = Hydra.Use('players')
        if Players and Players.RegisterUsableItem then
            Players.RegisterUsableItem(name, cb)
        end
    end

    ESX.UseItem = function(source, name, ...)
        local Players = Hydra.Use('players')
        if Players and Players.UseItem then
            Players.UseItem(source, name, ...)
        end
    end

    -- Shared object
    ESX.GetSharedObject = function()
        return ESX
    end

    -- Register the ESX shared object event that scripts use to get ESX
    -- This is the classic: TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    RegisterNetEvent('esx:getSharedObject')
    AddEventHandler('esx:getSharedObject', function(cb)
        if cb and type(cb) == 'function' then
            cb(ESX)
        end
    end)

    -- Modern ESX uses exports
    -- Scripts do: local ESX = exports['es_extended']:getSharedObject()
    -- We override this by providing the export from hydra_bridge
    exports('getSharedObject', function()
        return ESX
    end)

    -- ESX server events that scripts listen to
    -- We emit these when Hydra player events fire
    Hydra.Data.Store.Watch('bridge', 'esx_ready', function()
        TriggerEvent('esx:onReady')
    end)

    Hydra.Utils.Log('info', 'ESX bridge adapter initialized')
end

--- Wrap a Hydra player object to look like an ESX xPlayer
--- @param source number
--- @param data table Hydra player data
--- @return table xPlayer-like object
function ESXBridge._WrapPlayer(source, data)
    local xPlayer = {}

    xPlayer.source = source
    xPlayer.identifier = data.identifier
    xPlayer.name = data.name or GetPlayerName(source) or 'Unknown'
    xPlayer.group = data.group or 'user'

    -- Accounts (money)
    xPlayer.getAccount = function(accountName)
        local accounts = data.accounts or {}
        return accounts[accountName] or { name = accountName, money = 0, label = accountName }
    end

    xPlayer.getAccounts = function()
        local result = {}
        local accounts = data.accounts or { bank = { money = 0 }, money = { money = 0 }, black_money = { money = 0 } }
        for name, acc in pairs(accounts) do
            result[#result + 1] = { name = name, money = acc.money or acc, label = name }
        end
        return result
    end

    xPlayer.getMoney = function()
        return data.money or 0
    end

    xPlayer.setMoney = function(amount)
        local Players = Hydra.Use('players')
        if Players then Players.SetMoney(source, 'cash', amount) end
    end

    xPlayer.addMoney = function(amount)
        local Players = Hydra.Use('players')
        if Players then Players.AddMoney(source, 'cash', amount) end
    end

    xPlayer.removeMoney = function(amount)
        local Players = Hydra.Use('players')
        if Players then Players.RemoveMoney(source, 'cash', amount) end
    end

    xPlayer.addAccountMoney = function(accountName, amount)
        local Players = Hydra.Use('players')
        if Players then Players.AddMoney(source, accountName, amount) end
    end

    xPlayer.removeAccountMoney = function(accountName, amount)
        local Players = Hydra.Use('players')
        if Players then Players.RemoveMoney(source, accountName, amount) end
    end

    -- Job
    xPlayer.getJob = function()
        return data.job or { name = 'unemployed', label = 'Unemployed', grade = 0, grade_name = 'Unemployed', grade_label = 'Unemployed' }
    end

    xPlayer.setJob = function(jobName, grade)
        local Players = Hydra.Use('players')
        if Players then Players.SetJob(source, jobName, grade) end
    end

    -- Group / Admin
    xPlayer.getGroup = function()
        return data.group or 'user'
    end

    xPlayer.setGroup = function(group)
        local Players = Hydra.Use('players')
        if Players then Players.SetGroup(source, group) end
    end

    -- Coords
    xPlayer.getCoords = function(useVector)
        local ped = GetPlayerPed(source)
        local coords = GetEntityCoords(ped)
        if useVector then
            return coords
        end
        return { x = coords.x, y = coords.y, z = coords.z }
    end

    xPlayer.setCoords = function(coords)
        local ped = GetPlayerPed(source)
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    end

    -- Misc
    xPlayer.kick = function(reason)
        DropPlayer(source, reason or 'Kicked')
    end

    xPlayer.getName = function()
        return xPlayer.name
    end

    xPlayer.getIdentifier = function()
        return xPlayer.identifier
    end

    xPlayer.showNotification = function(msg, notifyType)
        -- Route through Hydra notification system
        local Notify = Hydra.Use('notify')
        if Notify then
            local nType = 'info'
            if notifyType == 'error' then nType = 'error'
            elseif notifyType == 'success' then nType = 'success'
            elseif notifyType == 'warning' then nType = 'warning' end
            Notify.Send(source, { message = msg, type = nType })
        else
            TriggerClientEvent('esx:showNotification', source, msg, notifyType)
        end
    end

    xPlayer.showHelpNotification = function(msg, thisFrame, beep, duration)
        local Notify = Hydra.Use('notify')
        if Notify then
            Notify.Send(source, { title = 'Help', message = msg, type = 'info', duration = duration or 7000 })
        else
            TriggerClientEvent('esx:showHelpNotification', source, msg, thisFrame, beep, duration)
        end
    end

    return xPlayer
end

-- Register adapter
Hydra.Bridge.RegisterAdapter('esx', ESXBridge)
