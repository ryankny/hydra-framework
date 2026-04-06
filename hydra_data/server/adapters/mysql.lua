--[[
    Hydra Data - MySQL Adapter

    Database adapter for MySQL/MariaDB via oxmysql.
    Provides a clean abstraction over raw SQL for the data layer.
]]

Hydra = Hydra or {}
Hydra.Data = Hydra.Data or {}
Hydra.Data.Adapters = Hydra.Data.Adapters or {}

local MySQL = Hydra.Data.Adapters

--- Execute a raw query
--- @param query string SQL query
--- @param params table|nil query parameters
--- @return table|nil results
function MySQL.Execute(query, params)
    local ok, result = pcall(exports.oxmysql.query_async, query, params or {})
    if not ok then
        Hydra.Utils.Log('error', 'MySQL Execute error: %s\nQuery: %s', tostring(result), query)
        return nil
    end
    return result
end

--- Execute a scalar query (single value)
--- @param query string
--- @param params table|nil
--- @return any
function MySQL.Scalar(query, params)
    local ok, result = pcall(exports.oxmysql.scalar_async, query, params or {})
    if not ok then
        Hydra.Utils.Log('error', 'MySQL Scalar error: %s', tostring(result))
        return nil
    end
    return result
end

--- Execute a single-row query
--- @param query string
--- @param params table|nil
--- @return table|nil
function MySQL.Single(query, params)
    local ok, result = pcall(exports.oxmysql.single_async, query, params or {})
    if not ok then
        Hydra.Utils.Log('error', 'MySQL Single error: %s', tostring(result))
        return nil
    end
    return result
end

--- Insert a row and return the insert ID
--- @param query string
--- @param params table|nil
--- @return number|nil insertId
function MySQL.Insert(query, params)
    local ok, result = pcall(exports.oxmysql.insert_async, query, params or {})
    if not ok then
        Hydra.Utils.Log('error', 'MySQL Insert error: %s', tostring(result))
        return nil
    end
    return result
end

--- Update rows and return affected count
--- @param query string
--- @param params table|nil
--- @return number affected rows
function MySQL.Update(query, params)
    local ok, result = pcall(exports.oxmysql.update_async, query, params or {})
    if not ok then
        Hydra.Utils.Log('error', 'MySQL Update error: %s', tostring(result))
        return 0
    end
    return result or 0
end

--- Execute a prepared statement
--- @param query string
--- @param params table|nil
--- @return boolean success
function MySQL.Prepare(query, params)
    local ok, result = pcall(exports.oxmysql.prepare_async, query, params or {})
    if not ok then
        Hydra.Utils.Log('error', 'MySQL Prepare error: %s', tostring(result))
        return false
    end
    return true
end

--- Transaction support
--- @param queries table array of { query = string, params = table }
--- @return boolean success
function MySQL.Transaction(queries)
    local statements = {}
    for _, q in ipairs(queries) do
        statements[#statements + 1] = { query = q.query, values = q.params or {} }
    end

    local ok, result = pcall(exports.oxmysql.transaction_async, statements)
    if not ok then
        Hydra.Utils.Log('error', 'MySQL Transaction error: %s', tostring(result))
        return false
    end
    return result ~= false
end

--- Check if a table exists
--- @param tableName string
--- @return boolean
function MySQL.TableExists(tableName)
    -- Sanitize table name (allow only alphanumeric and underscores)
    if not tableName:match('^[%w_]+$') then
        Hydra.Utils.Log('error', 'Invalid table name: %s', tableName)
        return false
    end

    local result = MySQL.Scalar(
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?",
        { tableName }
    )
    return result and result > 0
end

--- Create a table from a schema definition
--- @param tableName string
--- @param columns table { { name, type, nullable, default, primary } }
--- @param options table|nil { engine, charset, indexes }
--- @return boolean success
function MySQL.CreateTable(tableName, columns, options)
    if not tableName:match('^[%w_]+$') then
        Hydra.Utils.Log('error', 'Invalid table name: %s', tableName)
        return false
    end

    options = options or {}
    local parts = {}
    local primaryKeys = {}

    for _, col in ipairs(columns) do
        if not col.name:match('^[%w_]+$') then
            Hydra.Utils.Log('error', 'Invalid column name: %s', col.name)
            return false
        end

        local def = string.format('`%s` %s', col.name, col.type)
        if not col.nullable then
            def = def .. ' NOT NULL'
        end
        if col.default ~= nil then
            if type(col.default) == 'string' then
                def = def .. string.format(" DEFAULT '%s'", col.default)
            else
                def = def .. string.format(' DEFAULT %s', tostring(col.default))
            end
        end
        if col.auto_increment then
            def = def .. ' AUTO_INCREMENT'
        end
        if col.primary then
            primaryKeys[#primaryKeys + 1] = string.format('`%s`', col.name)
        end
        parts[#parts + 1] = def
    end

    if #primaryKeys > 0 then
        parts[#parts + 1] = string.format('PRIMARY KEY (%s)', table.concat(primaryKeys, ', '))
    end

    -- Add indexes
    if options.indexes then
        for _, idx in ipairs(options.indexes) do
            local idxCols = {}
            for _, c in ipairs(idx.columns) do
                idxCols[#idxCols + 1] = string.format('`%s`', c)
            end
            local idxType = idx.unique and 'UNIQUE INDEX' or 'INDEX'
            parts[#parts + 1] = string.format('%s `%s` (%s)', idxType, idx.name, table.concat(idxCols, ', '))
        end
    end

    local engine = options.engine or 'InnoDB'
    local charset = options.charset or 'utf8mb4'

    local sql = string.format(
        'CREATE TABLE IF NOT EXISTS `%s` (\n  %s\n) ENGINE=%s DEFAULT CHARSET=%s',
        tableName, table.concat(parts, ',\n  '), engine, charset
    )

    local result = MySQL.Execute(sql)
    if result ~= nil then
        Hydra.Utils.Log('debug', 'Created table: %s', tableName)
        return true
    end
    return false
end

Hydra.Utils.Log('debug', 'MySQL adapter loaded')
