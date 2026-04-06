--[[
    Hydra Framework - Shared Utilities

    High-performance utility functions available everywhere.
    Designed for zero-allocation hot paths where possible.
]]

Hydra = Hydra or {}
Hydra.Utils = Hydra.Utils or {}

-- Localize frequently used globals for performance
local type = type
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber
local string_format = string.format
local string_lower = string.lower
local string_gsub = string.gsub
local table_insert = table.insert
local table_remove = table.remove
local math_random = math.random
local math_floor = math.floor
local os_time = os and os.time or function() return 0 end
local GetGameTimer = GetGameTimer

--- Generate a unique ID (server-safe, no crypto dependency)
--- @return string
function Hydra.Utils.GenerateId()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string_gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math_random(0, 15) or math_random(8, 11)
        return string_format('%x', v)
    end)
end

--- Deep copy a table
--- @param tbl table
--- @return table
function Hydra.Utils.DeepCopy(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = type(v) == 'table' and Hydra.Utils.DeepCopy(v) or v
    end
    return setmetatable(copy, getmetatable(tbl))
end

--- Shallow copy a table
--- @param tbl table
--- @return table
function Hydra.Utils.ShallowCopy(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

--- Safely get a nested table value
--- @param tbl table
--- @param path string dot-notation path
--- @param default any
--- @return any
function Hydra.Utils.GetNested(tbl, path, default)
    local current = tbl
    for key in path:gmatch('[^%.]+') do
        if type(current) ~= 'table' then return default end
        current = current[key]
        if current == nil then return default end
    end
    return current
end

--- Sanitize a string to prevent injection
--- @param str string
--- @return string
function Hydra.Utils.Sanitize(str)
    if type(str) ~= 'string' then return '' end
    -- Remove null bytes and control characters
    str = string_gsub(str, '[%z\x01-\x08\x0B\x0C\x0E-\x1F\x7F]', '')
    -- Escape common injection characters
    str = string_gsub(str, '[\'\"\\;]', function(c)
        return '\\' .. c
    end)
    return str
end

--- Sanitize HTML-unsafe characters (for NUI display)
--- @param str string
--- @return string
function Hydra.Utils.SanitizeHTML(str)
    if type(str) ~= 'string' then return '' end
    str = string_gsub(str, '&', '&amp;')
    str = string_gsub(str, '<', '&lt;')
    str = string_gsub(str, '>', '&gt;')
    str = string_gsub(str, '"', '&quot;')
    str = string_gsub(str, "'", '&#39;')
    return str
end

--- Validate and clamp a number
--- @param value any
--- @param min number
--- @param max number
--- @param default number
--- @return number
function Hydra.Utils.ClampNumber(value, min, max, default)
    local n = tonumber(value)
    if not n then return default or min end
    if n < min then return min end
    if n > max then return max end
    return n
end

--- Check if a table is an array (sequential integer keys)
--- @param tbl table
--- @return boolean
function Hydra.Utils.IsArray(tbl)
    if type(tbl) ~= 'table' then return false end
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count == #tbl
end

--- Table contains value
--- @param tbl table
--- @param value any
--- @return boolean
function Hydra.Utils.Contains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

--- Get table keys
--- @param tbl table
--- @return table
function Hydra.Utils.Keys(tbl)
    local keys = {}
    for k in pairs(tbl) do
        keys[#keys + 1] = k
    end
    return keys
end

--- Map over table values
--- @param tbl table
--- @param fn function
--- @return table
function Hydra.Utils.Map(tbl, fn)
    local result = {}
    for k, v in pairs(tbl) do
        result[k] = fn(v, k)
    end
    return result
end

--- Filter table values
--- @param tbl table
--- @param fn function
--- @return table
function Hydra.Utils.Filter(tbl, fn)
    local result = {}
    for k, v in pairs(tbl) do
        if fn(v, k) then
            if type(k) == 'number' then
                result[#result + 1] = v
            else
                result[k] = v
            end
        end
    end
    return result
end

--- Debounce a function (prevent rapid repeated calls)
--- @param fn function
--- @param delay number milliseconds
--- @return function
function Hydra.Utils.Debounce(fn, delay)
    local lastCall = 0
    return function(...)
        local now = GetGameTimer()
        if now - lastCall >= delay then
            lastCall = now
            return fn(...)
        end
    end
end

--- Throttle a function (limit call frequency, ensures trailing call fires)
--- @param fn function
--- @param interval number milliseconds
--- @return function
function Hydra.Utils.Throttle(fn, interval)
    local lastCall = 0
    local pendingArgs = nil
    local scheduled = false
    return function(...)
        local now = GetGameTimer()
        if now - lastCall >= interval then
            lastCall = now
            pendingArgs = nil
            return fn(...)
        else
            -- Store latest args; schedule trailing call
            pendingArgs = { ... }
            if not scheduled then
                scheduled = true
                CreateThread(function()
                    local remaining = interval - (GetGameTimer() - lastCall)
                    if remaining > 0 then Wait(remaining) end
                    scheduled = false
                    if pendingArgs then
                        lastCall = GetGameTimer()
                        local args = pendingArgs
                        pendingArgs = nil
                        fn(table.unpack(args))
                    end
                end)
            end
        end
    end
end

--- High-resolution timer for performance measurement
--- @return function call to get elapsed ms
function Hydra.Utils.Timer()
    local start = GetGameTimer()
    return function()
        return GetGameTimer() - start
    end
end

--- Format number with commas (e.g., 1000000 -> "1,000,000")
--- @param n number
--- @return string
function Hydra.Utils.FormatNumber(n)
    local formatted = tostring(math_floor(n))
    local k
    while true do
        formatted, k = string_gsub(formatted, '^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

--- Create a promise-like object for async operations
--- @return table { resolve, reject, await }
function Hydra.Utils.Promise()
    local p = { _done = false, _success = nil, _value = nil }

    function p.resolve(...)
        if p._done then return end
        p._done = true
        p._success = true
        p._value = { ... }
    end

    function p.reject(reason)
        if p._done then return end
        p._done = true
        p._success = false
        p._value = { reason }
    end

    --- Block current thread until resolved (use inside CreateThread)
    --- @param timeout number|nil ms (default 10000)
    --- @return any values from resolve, or nil on timeout/reject
    function p.await(timeout)
        timeout = timeout or 10000
        local deadline = GetGameTimer() + timeout
        while not p._done and GetGameTimer() < deadline do
            Wait(0)
        end
        if p._done and p._success then
            return table.unpack(p._value)
        end
        return nil
    end

    return p
end

--- Safe JSON encode with error handling
--- @param data any
--- @return string|nil
function Hydra.Utils.JsonEncode(data)
    local ok, result = pcall(json.encode, data)
    return ok and result or nil
end

--- Safe JSON decode with error handling
--- @param str string
--- @return any
function Hydra.Utils.JsonDecode(str)
    if type(str) ~= 'string' then return nil end
    local ok, result = pcall(json.decode, str)
    return ok and result or nil
end

--- Print with Hydra prefix and log level
--- @param level string
--- @param msg string
--- @vararg any
function Hydra.Utils.Log(level, msg, ...)
    local levels = { error = 1, warn = 2, info = 3, debug = 4, trace = 5 }
    local configLevel = Hydra.Config and Hydra.Config.Get('debug.log_level', 'info') or 'info'

    if (levels[level] or 0) > (levels[configLevel] or 3) then return end

    local prefix = string_format('[^5HYDRA^0][^3%s^0]', string.upper(level))
    if select('#', ...) > 0 then
        print(prefix .. ' ' .. string_format(msg, ...))
    else
        print(prefix .. ' ' .. msg)
    end
end
