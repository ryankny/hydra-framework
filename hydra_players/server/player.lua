--[[
    Hydra Players - Player Object & Management

    Core player management: loading, saving, caching player data.
    This is the central player state system.
]]

Hydra = Hydra or {}
Hydra.Players = Hydra.Players or {}

-- Active player cache: { [source] = playerData }
local activePlayers = {}
-- Identifier -> source mapping for fast lookups
local identifierMap = {}

--- Get primary identifier for a player
--- @param source number
--- @return string|nil
function Hydra.Players.GetIdentifier(source)
    local idType = HydraPlayersConfig.identifier_type or 'license'
    local prefix = idType .. ':'

    local identifiers = GetPlayerIdentifiers(source)
    for _, id in ipairs(identifiers) do
        if id:find('^' .. prefix) then
            return id
        end
    end

    -- Fallback: try license
    if idType ~= 'license' then
        for _, id in ipairs(identifiers) do
            if id:find('^license:') then
                return id
            end
        end
    end

    return nil
end

--- Load player data from database
--- @param source number
--- @return table|nil playerData
function Hydra.Players.Load(source)
    local identifier = Hydra.Players.GetIdentifier(source)
    if not identifier then
        Hydra.Utils.Log('error', 'Could not get identifier for player %d', source)
        return nil
    end

    local name = GetPlayerName(source) or 'Unknown'

    -- Check if player exists in database
    local existing = Hydra.Data.FindOne('players', { identifier = identifier })

    local playerData
    if existing then
        -- Existing player - load data
        playerData = {
            source = source,
            identifier = identifier,
            name = name,
            group = existing.permission_group or HydraPlayersConfig.new_player.group,
            accounts = Hydra.Utils.JsonDecode(existing.accounts) or HydraPlayersConfig.new_player.accounts,
            job = Hydra.Utils.JsonDecode(existing.job) or HydraPlayersConfig.new_player.job,
            position = Hydra.Utils.JsonDecode(existing.position) or HydraPlayersConfig.new_player.position,
            metadata = Hydra.Utils.JsonDecode(existing.metadata) or {},
            charinfo = Hydra.Utils.JsonDecode(existing.charinfo) or {},
            inventory = Hydra.Utils.JsonDecode(existing.inventory) or {},
            db_id = existing.id,
            lastLogin = os.time(),
        }

        -- Update last login
        Hydra.Data.Update('players', { id = existing.id }, {
            last_login = os.date('%Y-%m-%d %H:%M:%S'),
            last_name = name,
        })

        Hydra.Utils.Log('debug', 'Loaded existing player: %s (%s)', name, identifier)
    else
        -- New player - create record
        playerData = {
            source = source,
            identifier = identifier,
            name = name,
            group = HydraPlayersConfig.new_player.group,
            accounts = Hydra.Utils.DeepCopy(HydraPlayersConfig.new_player.accounts),
            job = Hydra.Utils.DeepCopy(HydraPlayersConfig.new_player.job),
            position = Hydra.Utils.DeepCopy(HydraPlayersConfig.new_player.position),
            metadata = {},
            charinfo = {},
            inventory = {},
            lastLogin = os.time(),
        }

        local id = Hydra.Data.Create('players', {
            identifier = identifier,
            last_name = name,
            permission_group = playerData.group,
            accounts = Hydra.Utils.JsonEncode(playerData.accounts),
            job = Hydra.Utils.JsonEncode(playerData.job),
            position = Hydra.Utils.JsonEncode(playerData.position),
            metadata = '{}',
            charinfo = '{}',
            inventory = '{}',
            last_login = os.date('%Y-%m-%d %H:%M:%S'),
        })

        playerData.db_id = id
        Hydra.Utils.Log('info', 'Created new player: %s (%s)', name, identifier)
    end

    -- Cache player
    activePlayers[source] = playerData
    identifierMap[identifier] = source

    -- Sync to client via store
    Hydra.Players._SyncToClient(source, playerData)

    return playerData
end

--- Save player data to database
--- @param source number
--- @return boolean success
function Hydra.Players.Save(source)
    local data = activePlayers[source]
    if not data or not data.db_id then return false end

    -- Get current position from client
    local ped = GetPlayerPed(source)
    if ped and ped > 0 then
        local coords = GetEntityCoords(ped)
        data.position = {
            x = coords.x,
            y = coords.y,
            z = coords.z,
            heading = GetEntityHeading(ped),
        }
    end

    local affected = Hydra.Data.Update('players', { id = data.db_id }, {
        last_name = data.name,
        permission_group = data.group,
        accounts = Hydra.Utils.JsonEncode(data.accounts),
        job = Hydra.Utils.JsonEncode(data.job),
        position = Hydra.Utils.JsonEncode(data.position),
        metadata = Hydra.Utils.JsonEncode(data.metadata),
        charinfo = Hydra.Utils.JsonEncode(data.charinfo),
        inventory = Hydra.Utils.JsonEncode(data.inventory),
    })

    return affected > 0
end

--- Unload player (on disconnect)
--- @param source number
function Hydra.Players.Unload(source)
    local data = activePlayers[source]
    if not data then return end

    -- Save before unloading
    Hydra.Players.Save(source)

    -- Clean up maps
    if data.identifier then
        identifierMap[data.identifier] = nil
    end
    activePlayers[source] = nil

    Hydra.Utils.Log('debug', 'Unloaded player %d (%s)', source, data.name or 'Unknown')
end

--- Get player data
--- @param source number
--- @return table|nil
function Hydra.Players.GetPlayer(source)
    return activePlayers[source]
end

--- Get all active players
--- @return table { [source] = playerData }
function Hydra.Players.GetAllPlayers()
    return activePlayers
end

--- Get all active player source IDs
--- @return table
function Hydra.Players.GetAllPlayerIds()
    local ids = {}
    for src in pairs(activePlayers) do
        ids[#ids + 1] = src
    end
    return ids
end

--- Get player by identifier
--- @param identifier string
--- @return number|nil source
function Hydra.Players.GetPlayerByIdentifier(identifier)
    return identifierMap[identifier]
end

--- Sync player data to client
--- @param source number
--- @param data table
function Hydra.Players._SyncToClient(source, data)
    -- Send a filtered version of player data to client
    local clientData = {
        identifier = data.identifier,
        name = data.name,
        group = data.group,
        accounts = data.accounts,
        job = data.job,
        position = data.position,
        metadata = data.metadata,
        charinfo = data.charinfo,
    }

    TriggerClientEvent('hydra:store:syncBulk', source, 'playerData', clientData)
end

--- Save all active players
function Hydra.Players.SaveAll()
    local count = 0
    for src in pairs(activePlayers) do
        if Hydra.Players.Save(src) then
            count = count + 1
        end
    end
    Hydra.Utils.Log('debug', 'Auto-saved %d players', count)
end
