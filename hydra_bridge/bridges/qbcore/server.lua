--[[
    Hydra Bridge - QBCore Server Adapter

    Intercepts QBCore server-side calls and routes through Hydra.
    QBCore scripts use QBCore.Functions.* and event patterns.
]]

Hydra = Hydra or {}

local QBBridge = {}

function QBBridge.Init()
    local QBCore = {}
    QBCore.Functions = {}
    QBCore.Players = {}
    QBCore.Shared = {}
    QBCore.Config = {}

    --- Get a player object
    QBCore.Functions.GetPlayer = function(source)
        local Players = Hydra.Use('players')
        if not Players then return nil end
        local data = Players.GetPlayer(source)
        if not data then return nil end
        return QBBridge._WrapPlayer(source, data)
    end

    --- Get player by citizen ID
    QBCore.Functions.GetPlayerByCitizenId = function(citizenId)
        local Players = Hydra.Use('players')
        if not Players then return nil end
        local src = Players.GetPlayerByIdentifier(citizenId)
        if not src then return nil end
        local data = Players.GetPlayer(src)
        return data and QBBridge._WrapPlayer(src, data) or nil
    end

    --- Get all players
    QBCore.Functions.GetPlayers = function()
        local Players = Hydra.Use('players')
        return Players and Players.GetAllPlayerIds() or {}
    end

    QBCore.Functions.GetQBPlayers = function()
        local Players = Hydra.Use('players')
        if not Players then return {} end
        local result = {}
        for src, data in pairs(Players.GetAllPlayers()) do
            result[src] = QBBridge._WrapPlayer(src, data)
        end
        return result
    end

    --- Create callback
    QBCore.Functions.CreateCallback = function(name, handler)
        Hydra.Callbacks.Register(name, handler)
    end

    --- Usable items
    QBCore.Functions.CreateUseableItem = function(name, cb)
        local Players = Hydra.Use('players')
        if Players and Players.RegisterUsableItem then
            Players.RegisterUsableItem(name, cb)
        end
    end

    --- Kick player
    QBCore.Functions.Kick = function(source, reason)
        DropPlayer(source, reason or 'Kicked by server')
    end

    --- Notify
    QBCore.Functions.Notify = function(source, text, notifyType, duration)
        TriggerClientEvent('QBCore:Notify', source, text, notifyType, duration)
    end

    -- Shared data (jobs, items, vehicles, etc.)
    QBCore.Shared.Jobs = {}
    QBCore.Shared.Items = {}
    QBCore.Shared.Vehicles = {}
    QBCore.Shared.Gangs = {}

    -- Register the QBCore shared object
    QBCore.Functions.GetCoreObject = function()
        return QBCore
    end

    -- QBCore event patterns
    RegisterNetEvent('QBCore:GetObject')
    AddEventHandler('QBCore:GetObject', function(cb)
        if cb then cb(QBCore) end
    end)

    -- Export for modern QBCore access
    exports('GetCoreObject', function()
        return QBCore
    end)

    -- Store reference for server events
    _G.QBCore = QBCore

    Hydra.Utils.Log('info', 'QBCore bridge adapter initialized')
end

--- Wrap Hydra player as QBCore Player object
function QBBridge._WrapPlayer(source, data)
    local Player = {}

    Player.PlayerData = {
        source = source,
        citizenid = data.identifier,
        name = data.name or GetPlayerName(source),
        money = data.accounts or { cash = 0, bank = 0, crypto = 0 },
        job = data.job or { name = 'unemployed', label = 'Unemployed', grade = { name = 'Freelancer', level = 0 } },
        gang = data.gang or { name = 'none', label = 'None', grade = { name = 'None', level = 0 } },
        charinfo = data.charinfo or {},
        metadata = data.metadata or {},
        items = data.inventory or {},
    }

    Player.Functions = {}

    Player.Functions.GetMoney = function(moneyType)
        local Players = Hydra.Use('players')
        return Players and Players.GetMoney(source, moneyType) or 0
    end

    Player.Functions.AddMoney = function(moneyType, amount, reason)
        local Players = Hydra.Use('players')
        if Players then Players.AddMoney(source, moneyType, amount) end
    end

    Player.Functions.RemoveMoney = function(moneyType, amount, reason)
        local Players = Hydra.Use('players')
        if Players then Players.RemoveMoney(source, moneyType, amount) end
    end

    Player.Functions.SetMoney = function(moneyType, amount, reason)
        local Players = Hydra.Use('players')
        if Players then Players.SetMoney(source, moneyType, amount) end
    end

    Player.Functions.SetJob = function(jobName, grade)
        local Players = Hydra.Use('players')
        if Players then Players.SetJob(source, jobName, grade) end
    end

    Player.Functions.GetName = function()
        return Player.PlayerData.name
    end

    Player.Functions.GetCitizenId = function()
        return Player.PlayerData.citizenid
    end

    Player.Functions.Notify = function(text, notifyType, duration)
        TriggerClientEvent('QBCore:Notify', source, text, notifyType, duration)
    end

    Player.Functions.SetMetaData = function(key, value)
        Player.PlayerData.metadata[key] = value
        local Players = Hydra.Use('players')
        if Players then Players.SetMetadata(source, key, value) end
    end

    Player.Functions.GetMetaData = function(key)
        return Player.PlayerData.metadata[key]
    end

    Player.Functions.Save = function()
        local Players = Hydra.Use('players')
        if Players then Players.Save(source) end
    end

    return Player
end

Hydra.Bridge.RegisterAdapter('qbcore', QBBridge)
