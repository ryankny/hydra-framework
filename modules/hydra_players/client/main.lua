--[[
    Hydra Players - Client Main

    Client-side player state management.
    Receives synced data from server and provides local access.
]]

Hydra = Hydra or {}
Hydra.PlayerState = Hydra.PlayerState or {}

local playerLoaded = false
local playerData = {}

--- Receive player data from server
RegisterNetEvent('hydra:players:loaded')
AddEventHandler('hydra:players:loaded', function(data)
    playerData = data
    playerLoaded = true

    Hydra.Utils.Log('info', 'Player loaded: %s', data.name or 'Unknown')
    TriggerEvent('hydra:players:ready', data)
end)

--- Get local player data
--- @return table
function Hydra.PlayerState.Get()
    return playerData
end

--- Get a specific field from player data
--- @param key string
--- @return any
function Hydra.PlayerState.GetField(key)
    return playerData[key]
end

--- Check if player is loaded
--- @return boolean
function Hydra.PlayerState.IsLoaded()
    return playerLoaded
end

--- Get player money
--- @param accountType string
--- @return number
function Hydra.PlayerState.GetMoney(accountType)
    accountType = accountType or 'cash'
    if accountType == 'money' then accountType = 'cash' end
    local accounts = playerData.accounts or {}
    return accounts[accountType] or 0
end

--- Get player job
--- @return table
function Hydra.PlayerState.GetJob()
    return playerData.job or { name = 'unemployed', label = 'Unemployed', grade = 0 }
end

--- Get player group
--- @return string
function Hydra.PlayerState.GetGroup()
    return playerData.group or 'user'
end

--- Watch for store updates and merge into local data
Hydra.Data.Store.Watch('playerData', 'accounts', function(newValue)
    playerData.accounts = newValue
    TriggerEvent('hydra:players:accountsUpdated', newValue)
end)

Hydra.Data.Store.Watch('playerData', 'job', function(newValue)
    playerData.job = newValue
    TriggerEvent('hydra:players:jobUpdated', newValue)
end)

Hydra.Data.Store.Watch('playerData', 'group', function(newValue)
    playerData.group = newValue
end)

Hydra.Data.Store.Watch('playerData', 'metadata', function(newValue)
    playerData.metadata = newValue
end)
