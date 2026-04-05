--[[
    Hydra Data - Query Builder

    Fluent query API for CRUD operations on collections.
    Handles cache integration, input validation, and query construction.

    Usage:
        -- Create
        Hydra.Data.Create('players', { name = 'John', money = 5000 })

        -- Read
        local player = Hydra.Data.FindOne('players', { identifier = 'steam:xxx' })
        local rich = Hydra.Data.Find('players', { money = { ['$gte'] = 10000 } }, { limit = 10 })

        -- Update
        Hydra.Data.Update('players', { identifier = 'steam:xxx' }, { money = 10000 })

        -- Delete
        Hydra.Data.Delete('players', { identifier = 'steam:xxx' })
]]

Hydra = Hydra or {}
Hydra.Data = Hydra.Data or {}

local DB = Hydra.Data.Adapters
local Cache = Hydra.Data.Cache
local Collections = Hydra.Data.Collections

-- Operator mapping for query filters
local OPERATORS = {
    ['$eq']   = '=',
    ['$ne']   = '!=',
    ['$gt']   = '>',
    ['$gte']  = '>=',
    ['$lt']   = '<',
    ['$lte']  = '<=',
    ['$like'] = 'LIKE',
    ['$in']   = 'IN',
    ['$nin']  = 'NOT IN',
}

--- Build WHERE clause from filter object
--- @param filter table
--- @return string whereClause
--- @return table params
local function buildWhere(filter)
    if not filter or not next(filter) then
        return '', {}
    end

    local conditions = {}
    local params = {}

    for field, value in pairs(filter) do
        -- Validate field name
        if not field:match('^[%w_]+$') then
            Hydra.Utils.Log('error', 'Invalid field name in query: %s', field)
            goto continue
        end

        if type(value) == 'table' then
            for op, val in pairs(value) do
                local sqlOp = OPERATORS[op]
                if sqlOp then
                    if op == '$in' or op == '$nin' then
                        -- Handle IN/NOT IN with array
                        local placeholders = {}
                        for _, v in ipairs(val) do
                            placeholders[#placeholders + 1] = '?'
                            params[#params + 1] = v
                        end
                        conditions[#conditions + 1] = string.format('`%s` %s (%s)', field, sqlOp, table.concat(placeholders, ','))
                    else
                        conditions[#conditions + 1] = string.format('`%s` %s ?', field, sqlOp)
                        params[#params + 1] = val
                    end
                end
            end
        else
            conditions[#conditions + 1] = string.format('`%s` = ?', field)
            params[#params + 1] = value
        end

        ::continue::
    end

    if #conditions == 0 then
        return '', {}
    end

    return ' WHERE ' .. table.concat(conditions, ' AND '), params
end

--- Build ORDER BY clause
--- @param sort table|nil { field = 'ASC'|'DESC' }
--- @return string
local function buildOrderBy(sort)
    if not sort then return '' end
    local parts = {}
    for field, dir in pairs(sort) do
        if field:match('^[%w_]+$') then
            dir = (dir == 'DESC' or dir == -1) and 'DESC' or 'ASC'
            parts[#parts + 1] = string.format('`%s` %s', field, dir)
        end
    end
    if #parts == 0 then return '' end
    return ' ORDER BY ' .. table.concat(parts, ', ')
end

--- Build LIMIT/OFFSET clause
--- @param options table|nil
--- @return string
local function buildLimit(options)
    if not options then return '' end
    local parts = ''
    if options.limit then
        parts = string.format(' LIMIT %d', math.min(options.limit, 1000))
    end
    if options.offset then
        parts = parts .. string.format(' OFFSET %d', options.offset)
    end
    return parts
end

--- Generate a cache key for a query
--- @param collection string
--- @param filter table|nil
--- @return string
local function cacheKey(collection, filter)
    local key = collection .. ':'
    if filter then
        -- Simple deterministic key from filter
        local parts = {}
        for k, v in pairs(filter) do
            parts[#parts + 1] = k .. '=' .. tostring(v)
        end
        table.sort(parts)
        key = key .. table.concat(parts, '&')
    end
    return key
end

-----------------------------------------------------------------------
-- PUBLIC CRUD API
-----------------------------------------------------------------------

--- Create a document in a collection
--- @param collection string
--- @param data table
--- @return number|nil insertId
function Hydra.Data.Create(collection, data)
    local tableName = Collections.GetTableName(collection)
    if not tableName then
        Hydra.Utils.Log('error', 'Collection not found: %s', collection)
        return nil
    end

    local fields = {}
    local placeholders = {}
    local values = {}

    for field, value in pairs(data) do
        if field:match('^[%w_]+$') then
            fields[#fields + 1] = string.format('`%s`', field)
            placeholders[#placeholders + 1] = '?'
            values[#values + 1] = value
        end
    end

    local sql = string.format('INSERT INTO `%s` (%s) VALUES (%s)',
        tableName, table.concat(fields, ', '), table.concat(placeholders, ', '))

    local id = DB.Insert(sql, values)

    -- Invalidate related cache
    if id then
        Cache.Invalidate(collection .. ':')
        -- Notify subscribers
        if Hydra.Data.Subscriptions then
            Hydra.Data.Subscriptions.Notify(collection, 'create', { id = id, data = data })
        end
    end

    return id
end

--- Find multiple documents
--- @param collection string
--- @param filter table|nil
--- @param options table|nil { sort, limit, offset, fields, cache }
--- @return table results
function Hydra.Data.Find(collection, filter, options)
    local tableName = Collections.GetTableName(collection)
    if not tableName then
        Hydra.Utils.Log('error', 'Collection not found: %s', collection)
        return {}
    end

    options = options or {}

    -- Check cache first
    if options.cache ~= false then
        local key = cacheKey(collection, filter)
        local cached, hit = Cache.Get(key)
        if hit then return cached end
    end

    -- Build query
    local selectFields = '*'
    if options.fields then
        local safeFields = {}
        for _, f in ipairs(options.fields) do
            if f:match('^[%w_]+$') then
                safeFields[#safeFields + 1] = string.format('`%s`', f)
            end
        end
        if #safeFields > 0 then
            selectFields = table.concat(safeFields, ', ')
        end
    end

    local where, params = buildWhere(filter)
    local orderBy = buildOrderBy(options.sort)
    local limit = buildLimit(options)

    local sql = string.format('SELECT %s FROM `%s`%s%s%s', selectFields, tableName, where, orderBy, limit)
    local results = DB.Execute(sql, params) or {}

    -- Cache results
    if options.cache ~= false and #results > 0 then
        local key = cacheKey(collection, filter)
        Cache.Set(key, results, options.cacheTTL)
    end

    return results
end

--- Find a single document
--- @param collection string
--- @param filter table
--- @param options table|nil
--- @return table|nil
function Hydra.Data.FindOne(collection, filter, options)
    options = options or {}
    options.limit = 1
    local results = Hydra.Data.Find(collection, filter, options)
    return results[1] or nil
end

--- Count documents matching filter
--- @param collection string
--- @param filter table|nil
--- @return number
function Hydra.Data.Count(collection, filter)
    local tableName = Collections.GetTableName(collection)
    if not tableName then return 0 end

    local where, params = buildWhere(filter)
    local sql = string.format('SELECT COUNT(*) FROM `%s`%s', tableName, where)
    return DB.Scalar(sql, params) or 0
end

--- Update documents matching filter
--- @param collection string
--- @param filter table
--- @param data table fields to update
--- @return number affected rows
function Hydra.Data.Update(collection, filter, data)
    local tableName = Collections.GetTableName(collection)
    if not tableName then
        Hydra.Utils.Log('error', 'Collection not found: %s', collection)
        return 0
    end

    local setParts = {}
    local params = {}

    for field, value in pairs(data) do
        if field:match('^[%w_]+$') then
            setParts[#setParts + 1] = string.format('`%s` = ?', field)
            params[#params + 1] = value
        end
    end

    if #setParts == 0 then return 0 end

    local where, whereParams = buildWhere(filter)
    for _, p in ipairs(whereParams) do
        params[#params + 1] = p
    end

    local sql = string.format('UPDATE `%s` SET %s%s', tableName, table.concat(setParts, ', '), where)
    local affected = DB.Update(sql, params)

    if affected > 0 then
        Cache.Invalidate(collection .. ':')
        if Hydra.Data.Subscriptions then
            Hydra.Data.Subscriptions.Notify(collection, 'update', { filter = filter, data = data })
        end
    end

    return affected
end

--- Delete documents matching filter
--- @param collection string
--- @param filter table
--- @return number affected rows
function Hydra.Data.Delete(collection, filter)
    local tableName = Collections.GetTableName(collection)
    if not tableName then return 0 end

    -- Safety: require a filter to prevent accidental full table delete
    if not filter or not next(filter) then
        Hydra.Utils.Log('error', 'Delete requires a filter (use Drop to delete all)')
        return 0
    end

    local where, params = buildWhere(filter)
    local sql = string.format('DELETE FROM `%s`%s', tableName, where)
    local affected = DB.Update(sql, params)

    if affected > 0 then
        Cache.Invalidate(collection .. ':')
        if Hydra.Data.Subscriptions then
            Hydra.Data.Subscriptions.Notify(collection, 'delete', { filter = filter })
        end
    end

    return affected
end

--- Bulk create documents
--- @param collection string
--- @param documents table array of data tables
--- @return boolean success
function Hydra.Data.BulkCreate(collection, documents)
    if not documents or #documents == 0 then return false end

    local tableName = Collections.GetTableName(collection)
    if not tableName then return false end

    -- Get fields from first document
    local fields = {}
    local fieldNames = {}
    for field in pairs(documents[1]) do
        if field:match('^[%w_]+$') then
            fields[#fields + 1] = field
            fieldNames[#fieldNames + 1] = string.format('`%s`', field)
        end
    end

    local queries = {}
    for _, doc in ipairs(documents) do
        local placeholders = {}
        local values = {}
        for _, field in ipairs(fields) do
            placeholders[#placeholders + 1] = '?'
            values[#values + 1] = doc[field]
        end
        queries[#queries + 1] = {
            query = string.format('INSERT INTO `%s` (%s) VALUES (%s)',
                tableName, table.concat(fieldNames, ', '), table.concat(placeholders, ', ')),
            params = values,
        }
    end

    local ok = DB.Transaction(queries)
    if ok then
        Cache.Invalidate(collection .. ':')
    end
    return ok
end

--- Bulk update documents
--- @param collection string
--- @param operations table array of { filter, data }
--- @return boolean success
function Hydra.Data.BulkUpdate(collection, operations)
    if not operations or #operations == 0 then return false end

    local tableName = Collections.GetTableName(collection)
    if not tableName then return false end

    local queries = {}
    for _, op in ipairs(operations) do
        local setParts = {}
        local params = {}
        for field, value in pairs(op.data) do
            if field:match('^[%w_]+$') then
                setParts[#setParts + 1] = string.format('`%s` = ?', field)
                params[#params + 1] = value
            end
        end

        local where, whereParams = buildWhere(op.filter)
        for _, p in ipairs(whereParams) do
            params[#params + 1] = p
        end

        queries[#queries + 1] = {
            query = string.format('UPDATE `%s` SET %s%s', tableName, table.concat(setParts, ', '), where),
            params = params,
        }
    end

    local ok = DB.Transaction(queries)
    if ok then
        Cache.Invalidate(collection .. ':')
    end
    return ok
end
