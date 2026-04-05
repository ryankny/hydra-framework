--[[
    Hydra Identity - Server Main

    Registers module, handles character selection flow,
    and integrates with hydra_players for loading.
]]

Hydra = Hydra or {}
Hydra.Identity = Hydra.Identity or {}

-- Track which players are in character selection
local playersSelecting = {}

--- Register as Hydra module
Hydra.Modules.Register('identity', {
    label = 'Hydra Identity',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 78,
    dependencies = { 'data', 'players' },

    onLoad = function()
        Hydra.Identity.CreateCollection()
        Hydra.Utils.Log('info', 'Identity module loaded')
    end,

    onPlayerJoin = function(src)
        -- Override default player load - show character selection instead
        playersSelecting[src] = true

        local identifier = Hydra.Players.GetIdentifier(src)
        if not identifier then return end

        local characters = Hydra.Identity.GetCharacters(identifier)
        local maxChars = HydraIdentityConfig.multichar.max_characters or 5

        -- Send character data to client for selection UI
        TriggerClientEvent('hydra:identity:showSelection', src, {
            characters = characters,
            maxCharacters = maxChars,
            spawnLocations = HydraIdentityConfig.spawn_locations,
            canDelete = HydraIdentityConfig.multichar.allow_delete,
        })
    end,

    onPlayerDrop = function(src, reason)
        -- Save character data on disconnect
        local playerData = Hydra.Players.GetPlayer(src)
        if playerData and playerData.db_id then
            -- Update playtime
            local sessionTime = playerData.lastLogin and (os.time() - playerData.lastLogin) or 0

            Hydra.Identity.SaveCharacter(playerData.db_id, {
                accounts = playerData.accounts,
                job = playerData.job,
                position = playerData.position,
                metadata = playerData.metadata,
                inventory = playerData.inventory,
                appearance = playerData.appearance,
                clothing = playerData.clothing,
                playtime = (playerData.playtime or 0) + sessionTime,
            })
        end

        playersSelecting[src] = nil
    end,

    api = {
        GetCharacters = Hydra.Identity.GetCharacters,
        CreateCharacter = Hydra.Identity.CreateCharacter,
        LoadCharacter = Hydra.Identity.LoadCharacter,
        SaveCharacter = Hydra.Identity.SaveCharacter,
        DeleteCharacter = Hydra.Identity.DeleteCharacter,
        GetCharacterCount = Hydra.Identity.GetCharacterCount,
    },
})

--- Callback: Get characters for the requesting player
Hydra.OnReady(function()
    Hydra.Callbacks.Register('hydra:identity:getCharacters', function(src, cb)
        local identifier = Hydra.Players.GetIdentifier(src)
        if not identifier then cb(false) return end

        local characters = Hydra.Identity.GetCharacters(identifier)
        local maxChars = HydraIdentityConfig.multichar.max_characters or 5

        cb(true, characters, maxChars)
    end)
end)

--- Event: Player selects a character
RegisterNetEvent('hydra:identity:selectCharacter')
AddEventHandler('hydra:identity:selectCharacter', function(characterId, spawnLocation)
    local src = source
    if not Hydra.Security.ValidateSource(src) then return end
    if not playersSelecting[src] then return end

    local playerData = Hydra.Identity.LoadCharacter(src, characterId)
    if not playerData then
        TriggerClientEvent('hydra:identity:error', src, 'Failed to load character.')
        return
    end

    -- Override spawn position if player picked a spawn location
    if spawnLocation and type(spawnLocation) == 'table' and spawnLocation.x then
        playerData.position = {
            x = spawnLocation.x,
            y = spawnLocation.y,
            z = spawnLocation.z,
            heading = spawnLocation.heading or 0.0,
        }
    end

    -- Inject into hydra_players system
    -- We need to directly set the player in the active players cache
    Hydra.Players._InjectPlayer(src, playerData)

    playersSelecting[src] = nil

    -- Notify client to spawn
    TriggerClientEvent('hydra:identity:characterLoaded', src, {
        charinfo = playerData.charinfo,
        appearance = playerData.appearance,
        clothing = playerData.clothing,
        accounts = playerData.accounts,
        job = playerData.job,
        position = playerData.position,
        group = playerData.group,
    })

    -- Fire standard player loaded events
    TriggerEvent('hydra:players:playerLoaded', src, playerData)

    -- Bridge compatibility
    local bridge = Hydra.Bridge and Hydra.Bridge.GetMode() or 'native'
    if bridge == 'esx' then
        TriggerClientEvent('esx:playerLoaded', src, playerData)
    elseif bridge == 'qbcore' or bridge == 'qbox' then
        TriggerClientEvent('QBCore:Client:OnPlayerLoaded', src)
    end

    Hydra.Utils.Log('info', 'Player %d loaded character: %s %s',
        src, playerData.charinfo.firstname, playerData.charinfo.lastname)
end)

--- Event: Player creates a new character
RegisterNetEvent('hydra:identity:createCharacter')
AddEventHandler('hydra:identity:createCharacter', function(data)
    local src = source
    if not Hydra.Security.ValidateSource(src) then return end
    if not playersSelecting[src] then return end

    local identifier = Hydra.Players.GetIdentifier(src)
    if not identifier then
        TriggerClientEvent('hydra:identity:error', src, 'Could not verify your identity.')
        return
    end

    -- Check slot availability
    local count = Hydra.Identity.GetCharacterCount(identifier)
    local maxChars = HydraIdentityConfig.multichar.max_characters or 5
    if count >= maxChars then
        TriggerClientEvent('hydra:identity:error', src, 'Maximum characters reached.')
        return
    end

    -- Create character
    local charId = Hydra.Identity.CreateCharacter(identifier, data)
    if not charId then
        TriggerClientEvent('hydra:identity:error', src, 'Failed to create character.')
        return
    end

    -- Send updated character list
    local characters = Hydra.Identity.GetCharacters(identifier)
    TriggerClientEvent('hydra:identity:characterCreated', src, {
        characters = characters,
        newCharId = charId,
    })
end)

--- Event: Player deletes a character
RegisterNetEvent('hydra:identity:deleteCharacter')
AddEventHandler('hydra:identity:deleteCharacter', function(characterId)
    local src = source
    if not Hydra.Security.ValidateSource(src) then return end

    local identifier = Hydra.Players.GetIdentifier(src)
    if not identifier then return end

    local success = Hydra.Identity.DeleteCharacter(identifier, characterId)

    if success then
        local characters = Hydra.Identity.GetCharacters(identifier)
        TriggerClientEvent('hydra:identity:characterDeleted', src, {
            characters = characters,
        })
    else
        TriggerClientEvent('hydra:identity:error', src, 'Failed to delete character.')
    end
end)

--- Event: Save appearance update from creation screen
RegisterNetEvent('hydra:identity:saveAppearance')
AddEventHandler('hydra:identity:saveAppearance', function(characterId, appearance, clothing)
    local src = source
    if not Hydra.Security.ValidateSource(src) then return end

    local identifier = Hydra.Players.GetIdentifier(src)
    if not identifier then return end

    Hydra.Identity.SaveCharacter(characterId, {
        appearance = appearance,
        clothing = clothing,
    })
end)
