--[[
    Hydra Bridge - Shared Bridge Interface

    Defines the standard interface that all bridge adapters must implement.
    The bridge intercepts calls from legacy framework scripts and routes
    them through Hydra's systems.
]]

Hydra = Hydra or {}
Hydra.Bridge = Hydra.Bridge or {}

local activeBridge = nil
local bridgeMode = 'native' -- 'native', 'esx', 'qbcore', 'qbox', 'tmc'
local isServer = IsDuplicityVersion()

--- Set the active bridge mode
--- @param mode string
function Hydra.Bridge.SetMode(mode)
    bridgeMode = mode
    Hydra.Utils.Log('info', 'Bridge mode set to: %s', mode)
end

--- Get current bridge mode
--- @return string
function Hydra.Bridge.GetMode()
    return bridgeMode
end

--- Check if bridge is active (non-native mode)
--- @return boolean
function Hydra.Bridge.IsActive()
    return bridgeMode ~= 'native'
end

--- Register a bridge adapter
--- @param name string adapter name ('esx', 'qbcore', etc.)
--- @param adapter table adapter implementation
function Hydra.Bridge.RegisterAdapter(name, adapter)
    if not Hydra.Bridge._adapters then
        Hydra.Bridge._adapters = {}
    end
    Hydra.Bridge._adapters[name] = adapter
    Hydra.Utils.Log('debug', 'Bridge adapter registered: %s', name)
end

--- Get an adapter
--- @param name string
--- @return table|nil
function Hydra.Bridge.GetAdapter(name)
    return Hydra.Bridge._adapters and Hydra.Bridge._adapters[name] or nil
end

--- Get the currently active adapter
--- @return table|nil
function Hydra.Bridge.GetActiveAdapter()
    return Hydra.Bridge.GetAdapter(bridgeMode)
end

--- Standard bridge interface that adapters must implement:
--[[
    Server:
        adapter.GetPlayer(source) -> playerData
        adapter.GetPlayers() -> { source = playerData }
        adapter.GetIdentifier(source) -> string
        adapter.GetPlayerMoney(source, moneyType) -> number
        adapter.SetPlayerMoney(source, moneyType, amount)
        adapter.AddPlayerMoney(source, moneyType, amount)
        adapter.RemovePlayerMoney(source, moneyType, amount)
        adapter.GetPlayerJob(source) -> { name, label, grade }
        adapter.SetPlayerJob(source, jobName, grade)
        adapter.GetPlayerGroup(source) -> string
        adapter.SavePlayer(source)
        adapter.RegisterUsableItem(name, callback)
        adapter.ShowNotification(source, msg, type)

    Client:
        adapter.GetPlayerData() -> playerData
        adapter.ShowNotification(msg, type)
        adapter.ShowHelpNotification(msg)
        adapter.ProgressBar(options, cb)
]]
