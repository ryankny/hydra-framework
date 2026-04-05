--[[
    Hydra Identity - Server Character Management

    CRUD operations for characters, tied to the hydra_data layer.
]]

Hydra = Hydra or {}
Hydra.Identity = Hydra.Identity or {}

--- Create the characters collection
function Hydra.Identity.CreateCollection()
    Hydra.Data.Collections.Create('characters', {
        { name = 'identifier',   type = 'VARCHAR(64)',  nullable = false },
        { name = 'char_slot',    type = 'TINYINT UNSIGNED', default = 1 },
        { name = 'firstname',    type = 'VARCHAR(32)',  nullable = false },
        { name = 'lastname',     type = 'VARCHAR(32)',  nullable = false },
        { name = 'sex',          type = 'VARCHAR(10)',  default = 'male' },
        { name = 'dob',          type = 'VARCHAR(10)',  default = '1990-01-01' },
        { name = 'nationality',  type = 'VARCHAR(32)',  default = 'American' },
        { name = 'appearance',   type = 'LONGTEXT',     default = '{}' },
        { name = 'clothing',     type = 'LONGTEXT',     default = '{}' },
        { name = 'accounts',     type = 'LONGTEXT',     default = '{}' },
        { name = 'job',          type = 'TEXT',          default = '{}' },
        { name = 'position',     type = 'TEXT',          default = '{}' },
        { name = 'metadata',     type = 'LONGTEXT',     default = '{}' },
        { name = 'inventory',    type = 'LONGTEXT',     default = '{}' },
        { name = 'permission_group', type = 'VARCHAR(32)', default = 'user' },
        { name = 'last_played',  type = 'DATETIME',     nullable = true },
        { name = 'playtime',     type = 'INT UNSIGNED',  default = 0 },
        { name = 'is_deleted',   type = 'TINYINT',      default = 0 },
    }, {
        indexes = {
            { name = 'idx_char_identifier', columns = { 'identifier', 'char_slot' }, unique = true },
            { name = 'idx_char_deleted', columns = { 'is_deleted' } },
        },
    })
end

--- Get all characters for an identifier
--- @param identifier string
--- @return table characters
function Hydra.Identity.GetCharacters(identifier)
    local results = Hydra.Data.Find('characters', {
        identifier = identifier,
        is_deleted = 0,
    }, {
        sort = { char_slot = 'ASC' },
        cache = false,
    })

    local characters = {}
    for _, row in ipairs(results) do
        characters[#characters + 1] = {
            id = row.id,
            slot = row.char_slot,
            firstname = row.firstname,
            lastname = row.lastname,
            sex = row.sex,
            dob = row.dob,
            nationality = row.nationality,
            appearance = Hydra.Utils.JsonDecode(row.appearance) or {},
            clothing = Hydra.Utils.JsonDecode(row.clothing) or {},
            accounts = Hydra.Utils.JsonDecode(row.accounts) or {},
            job = Hydra.Utils.JsonDecode(row.job) or {},
            position = Hydra.Utils.JsonDecode(row.position) or {},
            metadata = Hydra.Utils.JsonDecode(row.metadata) or {},
            last_played = row.last_played,
            playtime = row.playtime or 0,
        }
    end

    return characters
end

--- Get next available slot for a player
--- @param identifier string
--- @return number|nil slot
function Hydra.Identity.GetNextSlot(identifier)
    local maxSlots = HydraIdentityConfig.multichar.max_characters or 5
    local chars = Hydra.Identity.GetCharacters(identifier)

    local usedSlots = {}
    for _, char in ipairs(chars) do
        usedSlots[char.slot] = true
    end

    for i = 1, maxSlots do
        if not usedSlots[i] then
            return i
        end
    end

    return nil -- All slots full
end

--- Create a new character
--- @param identifier string
--- @param data table { firstname, lastname, sex, dob, nationality, appearance, clothing }
--- @return number|nil character db id
function Hydra.Identity.CreateCharacter(identifier, data)
    local slot = Hydra.Identity.GetNextSlot(identifier)
    if not slot then
        Hydra.Utils.Log('warn', 'No available character slots for %s', identifier)
        return nil
    end

    local cfg = HydraIdentityConfig.creation
    local playerCfg = HydraPlayersConfig.new_player

    -- Validate names
    local firstname = data.firstname and data.firstname:gsub('[^%a%-]', '') or 'John'
    local lastname = data.lastname and data.lastname:gsub('[^%a%-]', '') or 'Doe'

    if #firstname < (cfg.min_name_length or 2) then firstname = 'John' end
    if #lastname < (cfg.min_name_length or 2) then lastname = 'Doe' end

    -- Capitalise first letter
    firstname = firstname:sub(1, 1):upper() .. firstname:sub(2):lower()
    lastname = lastname:sub(1, 1):upper() .. lastname:sub(2):lower()

    local id = Hydra.Data.Create('characters', {
        identifier = identifier,
        char_slot = slot,
        firstname = firstname,
        lastname = lastname,
        sex = data.sex == 'female' and 'female' or 'male',
        dob = data.dob or cfg.default_dob or '1990-01-01',
        nationality = data.nationality or 'American',
        appearance = Hydra.Utils.JsonEncode(data.appearance or {}),
        clothing = Hydra.Utils.JsonEncode(data.clothing or {}),
        accounts = Hydra.Utils.JsonEncode(playerCfg.accounts or { cash = 5000, bank = 10000 }),
        job = Hydra.Utils.JsonEncode(playerCfg.job or {}),
        position = Hydra.Utils.JsonEncode(playerCfg.position or {}),
        metadata = Hydra.Utils.JsonEncode({}),
        inventory = '{}',
        permission_group = playerCfg.group or 'user',
        last_played = os.date('%Y-%m-%d %H:%M:%S'),
        playtime = 0,
    })

    if id then
        Hydra.Utils.Log('info', 'Character created: %s %s (slot %d) for %s', firstname, lastname, slot, identifier)
    end

    return id
end

--- Load a specific character into the player system
--- @param source number
--- @param characterId number
--- @return table|nil playerData
function Hydra.Identity.LoadCharacter(source, characterId)
    local identifier = Hydra.Players.GetIdentifier(source)
    if not identifier then return nil end

    local row = Hydra.Data.FindOne('characters', { id = characterId, identifier = identifier, is_deleted = 0 }, { cache = false })
    if not row then
        Hydra.Utils.Log('warn', 'Character %d not found for %s', characterId, identifier)
        return nil
    end

    -- Update last played
    Hydra.Data.Update('characters', { id = characterId }, {
        last_played = os.date('%Y-%m-%d %H:%M:%S'),
    })

    -- Build player data compatible with hydra_players
    local playerData = {
        source = source,
        identifier = identifier,
        name = GetPlayerName(source) or 'Unknown',
        group = row.permission_group or 'user',
        accounts = Hydra.Utils.JsonDecode(row.accounts) or HydraPlayersConfig.new_player.accounts,
        job = Hydra.Utils.JsonDecode(row.job) or HydraPlayersConfig.new_player.job,
        position = Hydra.Utils.JsonDecode(row.position) or HydraPlayersConfig.new_player.position,
        metadata = Hydra.Utils.JsonDecode(row.metadata) or {},
        inventory = Hydra.Utils.JsonDecode(row.inventory) or {},
        charinfo = {
            firstname = row.firstname,
            lastname = row.lastname,
            sex = row.sex,
            dob = row.dob,
            nationality = row.nationality,
        },
        appearance = Hydra.Utils.JsonDecode(row.appearance) or {},
        clothing = Hydra.Utils.JsonDecode(row.clothing) or {},
        db_id = characterId,
        char_slot = row.char_slot,
        lastLogin = os.time(),
    }

    return playerData
end

--- Save character-specific data (appearance, clothing, charinfo)
--- @param characterId number
--- @param data table
--- @return boolean
function Hydra.Identity.SaveCharacter(characterId, data)
    local updates = {}

    if data.appearance then updates.appearance = Hydra.Utils.JsonEncode(data.appearance) end
    if data.clothing then updates.clothing = Hydra.Utils.JsonEncode(data.clothing) end
    if data.accounts then updates.accounts = Hydra.Utils.JsonEncode(data.accounts) end
    if data.job then updates.job = Hydra.Utils.JsonEncode(data.job) end
    if data.position then updates.position = Hydra.Utils.JsonEncode(data.position) end
    if data.metadata then updates.metadata = Hydra.Utils.JsonEncode(data.metadata) end
    if data.inventory then updates.inventory = Hydra.Utils.JsonEncode(data.inventory) end
    if data.charinfo then
        if data.charinfo.firstname then updates.firstname = data.charinfo.firstname end
        if data.charinfo.lastname then updates.lastname = data.charinfo.lastname end
    end
    if data.playtime then updates.playtime = data.playtime end

    if not next(updates) then return true end

    return Hydra.Data.Update('characters', { id = characterId }, updates) > 0
end

--- Soft-delete a character
--- @param identifier string
--- @param characterId number
--- @return boolean
function Hydra.Identity.DeleteCharacter(identifier, characterId)
    if not HydraIdentityConfig.multichar.allow_delete then
        return false
    end

    local affected = Hydra.Data.Update('characters', {
        id = characterId,
        identifier = identifier,
    }, {
        is_deleted = 1,
    })

    if affected > 0 then
        Hydra.Utils.Log('info', 'Character %d soft-deleted for %s', characterId, identifier)
    end

    return affected > 0
end

--- Get character count for a player
--- @param identifier string
--- @return number
function Hydra.Identity.GetCharacterCount(identifier)
    return Hydra.Data.Count('characters', { identifier = identifier, is_deleted = 0 })
end
