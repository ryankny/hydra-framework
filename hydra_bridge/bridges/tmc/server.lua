--[[
    Hydra Bridge - TMC Server Adapter

    TMC Framework compatibility layer.
    TMC used Kuzzle for data and had its own module system.
]]

Hydra = Hydra or {}

local TMCBridge = {}

function TMCBridge.Init()
    local TMC = {}
    TMC.Functions = {}

    -- TMC player functions
    TMC.Functions.GetPlayer = function(source)
        local Players = Hydra.Use('players')
        if not Players then return nil end
        return Players.GetPlayer(source)
    end

    TMC.Functions.GetPlayers = function()
        local Players = Hydra.Use('players')
        return Players and Players.GetAllPlayers() or {}
    end

    -- TMC used Kuzzle for data - route to Hydra.Data
    TMC.Data = {}

    TMC.Data.Get = function(collection, id)
        return Hydra.Data.FindOne(collection, { id = id })
    end

    TMC.Data.Set = function(collection, id, data)
        local existing = Hydra.Data.FindOne(collection, { id = id })
        if existing then
            return Hydra.Data.Update(collection, { id = id }, data)
        else
            data.id = id
            return Hydra.Data.Create(collection, data)
        end
    end

    TMC.Data.Delete = function(collection, id)
        return Hydra.Data.Delete(collection, { id = id })
    end

    TMC.Data.Search = function(collection, filter, options)
        return Hydra.Data.Find(collection, filter, options)
    end

    TMC.Data.Subscribe = function(collection, filter, handler)
        return Hydra.Data.Subscriptions.Subscribe(collection, filter, handler)
    end

    -- TMC event compatibility
    RegisterNetEvent('tmc:getSharedObject')
    AddEventHandler('tmc:getSharedObject', function(cb)
        if cb then cb(TMC) end
    end)

    exports('getSharedObject', function()
        return TMC
    end)

    _G.TMC = TMC

    Hydra.Utils.Log('info', 'TMC bridge adapter initialized')
end

Hydra.Bridge.RegisterAdapter('tmc', TMCBridge)
