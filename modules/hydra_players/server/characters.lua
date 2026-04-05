--[[
    Hydra Players - Character Info

    Manages character biographical data (name, DOB, gender, etc.)
    Supports multi-character if enabled.
]]

Hydra = Hydra or {}
Hydra.Players = Hydra.Players or {}

--- Get character info
--- @param source number
--- @return table
function Hydra.Players.GetCharInfo(source)
    local player = Hydra.Players.GetPlayer(source)
    if not player then return {} end
    return player.charinfo or {}
end

--- Set character info field
--- @param source number
--- @param key string
--- @param value any
function Hydra.Players.SetCharInfo(source, key, value)
    local player = Hydra.Players.GetPlayer(source)
    if not player then return end

    if not player.charinfo then
        player.charinfo = {}
    end

    player.charinfo[key] = value
    TriggerClientEvent('hydra:store:sync', source, 'playerData', 'charinfo', player.charinfo)
end

--- Set full character info
--- @param source number
--- @param data table { firstname, lastname, dob, gender, nationality, phone }
function Hydra.Players.SetCharInfoBulk(source, data)
    local player = Hydra.Players.GetPlayer(source)
    if not player then return end

    player.charinfo = data or {}
    TriggerClientEvent('hydra:store:sync', source, 'playerData', 'charinfo', player.charinfo)
end

--- Get player metadata
--- @param source number
--- @param key string|nil specific key, or nil for all
--- @return any
function Hydra.Players.GetMetadata(source, key)
    local player = Hydra.Players.GetPlayer(source)
    if not player then return nil end

    if key then
        return player.metadata and player.metadata[key]
    end
    return player.metadata or {}
end

--- Set player metadata
--- @param source number
--- @param key string
--- @param value any
function Hydra.Players.SetMetadata(source, key, value)
    local player = Hydra.Players.GetPlayer(source)
    if not player then return end

    if not player.metadata then
        player.metadata = {}
    end

    player.metadata[key] = value
    TriggerClientEvent('hydra:store:sync', source, 'playerData', 'metadata', player.metadata)
end
