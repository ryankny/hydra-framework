--[[
    Hydra Players - Account/Money System

    Manages player financial accounts (cash, bank, etc.).
    All money operations go through this for audit trail and validation.
]]

Hydra = Hydra or {}
Hydra.Players = Hydra.Players or {}

--- Get player money for an account type
--- @param source number
--- @param accountType string 'cash', 'bank', etc.
--- @return number
function Hydra.Players.GetMoney(source, accountType)
    local player = Hydra.Players.GetPlayer(source)
    if not player then return 0 end

    -- Map common aliases
    if accountType == 'money' then accountType = 'cash' end

    return player.accounts[accountType] or 0
end

--- Set player money for an account type
--- @param source number
--- @param accountType string
--- @param amount number
--- @return boolean success
function Hydra.Players.SetMoney(source, accountType, amount)
    local player = Hydra.Players.GetPlayer(source)
    if not player then return false end
    if accountType == 'money' then accountType = 'cash' end

    amount = tonumber(amount)
    if not amount or amount < 0 then return false end

    player.accounts[accountType] = math.floor(amount)

    -- Sync to client
    TriggerClientEvent('hydra:store:sync', source, 'playerData', 'accounts', player.accounts)

    -- Emit event for other systems
    TriggerEvent('hydra:players:moneyChanged', source, accountType, player.accounts[accountType], 'set')

    return true
end

--- Add money to a player account
--- @param source number
--- @param accountType string
--- @param amount number
--- @return boolean success
function Hydra.Players.AddMoney(source, accountType, amount)
    local player = Hydra.Players.GetPlayer(source)
    if not player then return false end
    if accountType == 'money' then accountType = 'cash' end

    amount = tonumber(amount)
    if not amount or amount <= 0 then return false end

    player.accounts[accountType] = (player.accounts[accountType] or 0) + math.floor(amount)

    TriggerClientEvent('hydra:store:sync', source, 'playerData', 'accounts', player.accounts)
    TriggerEvent('hydra:players:moneyChanged', source, accountType, player.accounts[accountType], 'add')

    Hydra.Utils.Log('debug', 'Player %d: +$%s %s (total: $%s)',
        source, Hydra.Utils.FormatNumber(amount), accountType,
        Hydra.Utils.FormatNumber(player.accounts[accountType]))

    return true
end

--- Remove money from a player account
--- @param source number
--- @param accountType string
--- @param amount number
--- @return boolean success (false if insufficient funds)
function Hydra.Players.RemoveMoney(source, accountType, amount)
    local player = Hydra.Players.GetPlayer(source)
    if not player then return false end
    if accountType == 'money' then accountType = 'cash' end

    amount = tonumber(amount)
    if not amount or amount <= 0 then return false end

    local current = player.accounts[accountType] or 0
    if current < amount then
        Hydra.Utils.Log('debug', 'Player %d: insufficient %s ($%s < $%s)',
            source, accountType, Hydra.Utils.FormatNumber(current), Hydra.Utils.FormatNumber(amount))
        return false
    end

    player.accounts[accountType] = current - math.floor(amount)

    TriggerClientEvent('hydra:store:sync', source, 'playerData', 'accounts', player.accounts)
    TriggerEvent('hydra:players:moneyChanged', source, accountType, player.accounts[accountType], 'remove')

    return true
end

--- Get all account balances for a player
--- @param source number
--- @return table { [accountType] = amount }
function Hydra.Players.GetAccounts(source)
    local player = Hydra.Players.GetPlayer(source)
    if not player then return {} end
    return player.accounts or {}
end
