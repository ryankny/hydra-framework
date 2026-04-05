--[[
    Hydra Data - Collections

    Collections are the primary data organization unit (like tables/collections in Kuzzle).
    Each collection maps to a database table with automatic schema management.
]]

Hydra = Hydra or {}
Hydra.Data = Hydra.Data or {}
Hydra.Data.Collections = Hydra.Data.Collections or {}

local collections = {}  -- { [name] = { schema, options } }
local DB = Hydra.Data.Adapters

--- Register a collection (creates table if auto_migrate is on)
--- @param name string collection name
--- @param schema table column definitions
--- @param options table|nil { indexes, engine, charset }
--- @return boolean success
function Hydra.Data.Collections.Create(name, schema, options)
    if collections[name] then
        Hydra.Utils.Log('debug', 'Collection "%s" already registered', name)
        return true
    end

    options = options or {}

    -- Always include id, created_at, updated_at
    local fullSchema = {
        { name = 'id', type = 'INT UNSIGNED', auto_increment = true, primary = true },
    }

    -- Add user-defined columns
    for _, col in ipairs(schema) do
        fullSchema[#fullSchema + 1] = col
    end

    -- Add timestamps
    fullSchema[#fullSchema + 1] = { name = 'created_at', type = 'TIMESTAMP', default = 'CURRENT_TIMESTAMP' }
    fullSchema[#fullSchema + 1] = { name = 'updated_at', type = 'TIMESTAMP', default = 'CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP' }

    collections[name] = {
        schema = fullSchema,
        options = options,
        tableName = 'hydra_' .. name,
    }

    -- Auto-create table
    local dataConfig = Hydra.Config.Get('modules.data', {})
    if dataConfig.auto_migrate ~= false then
        if not DB.TableExists(collections[name].tableName) then
            local ok = DB.CreateTable(collections[name].tableName, fullSchema, options)
            if ok then
                Hydra.Utils.Log('info', 'Created collection table: %s', collections[name].tableName)
            else
                Hydra.Utils.Log('error', 'Failed to create collection table: %s', collections[name].tableName)
                return false
            end
        end
    end

    return true
end

--- Check if a collection exists
--- @param name string
--- @return boolean
function Hydra.Data.Collections.Exists(name)
    return collections[name] ~= nil
end

--- Get the table name for a collection
--- @param name string
--- @return string|nil
function Hydra.Data.Collections.GetTableName(name)
    local col = collections[name]
    return col and col.tableName or nil
end

--- Get collection schema
--- @param name string
--- @return table|nil
function Hydra.Data.Collections.GetSchema(name)
    local col = collections[name]
    return col and col.schema or nil
end

--- Get all registered collections
--- @return table
function Hydra.Data.Collections.GetAll()
    local list = {}
    for name, col in pairs(collections) do
        list[name] = {
            tableName = col.tableName,
            columnCount = #col.schema,
        }
    end
    return list
end

--- Drop a collection (DANGEROUS - requires confirmation)
--- @param name string
--- @return boolean
function Hydra.Data.Collections.Drop(name)
    local col = collections[name]
    if not col then return false end

    DB.Execute(string.format('DROP TABLE IF EXISTS `%s`', col.tableName))
    collections[name] = nil
    Hydra.Data.Cache.Invalidate(name .. ':')

    Hydra.Utils.Log('warn', 'Collection dropped: %s', name)
    return true
end
