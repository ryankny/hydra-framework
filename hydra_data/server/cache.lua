--[[
    Hydra Data - In-Memory Cache

    High-performance LRU cache with TTL support.
    Reduces database load by caching frequently accessed data.
]]

Hydra = Hydra or {}
Hydra.Data = Hydra.Data or {}
Hydra.Data.Cache = Hydra.Data.Cache or {}

local cache = {}          -- { [key] = { value, expires, lastAccess } }
local cacheSize = 0
local cacheHits = 0
local cacheMisses = 0

local maxEntries = 10000
local defaultTTL = 300

--- Initialize cache with config
function Hydra.Data.Cache.Init(config)
    config = config or {}
    maxEntries = config.max_entries or 10000
    defaultTTL = config.default_ttl or 300

    -- Start cleanup loop
    CreateThread(function()
        while true do
            Wait(30000) -- Clean every 30s
            Hydra.Data.Cache.Cleanup()
        end
    end)

    Hydra.Utils.Log('debug', 'Cache initialized (max=%d, ttl=%ds)', maxEntries, defaultTTL)
end

--- Get a cached value
--- @param key string
--- @return any|nil value
--- @return boolean hit
function Hydra.Data.Cache.Get(key)
    local entry = cache[key]
    if not entry then
        cacheMisses = cacheMisses + 1
        return nil, false
    end

    -- Check expiry
    if entry.expires > 0 and os.time() > entry.expires then
        cache[key] = nil
        cacheSize = cacheSize - 1
        cacheMisses = cacheMisses + 1
        return nil, false
    end

    entry.lastAccess = os.time()
    cacheHits = cacheHits + 1
    return entry.value, true
end

--- Set a cached value
--- @param key string
--- @param value any
--- @param ttl number|nil seconds (0 = no expiry, nil = default)
function Hydra.Data.Cache.Set(key, value, ttl)
    ttl = ttl or defaultTTL

    -- Evict if at capacity
    if not cache[key] and cacheSize >= maxEntries then
        Hydra.Data.Cache._EvictLRU()
    end

    if not cache[key] then
        cacheSize = cacheSize + 1
    end

    cache[key] = {
        value = value,
        expires = ttl > 0 and (os.time() + ttl) or 0,
        lastAccess = os.time(),
    }
end

--- Delete a cached value
--- @param key string
function Hydra.Data.Cache.Delete(key)
    if cache[key] then
        cache[key] = nil
        cacheSize = cacheSize - 1
    end
end

--- Invalidate cache entries matching a pattern
--- @param pattern string lua pattern to match keys
function Hydra.Data.Cache.Invalidate(pattern)
    local toRemove = {}
    for key in pairs(cache) do
        if key:find(pattern) then
            toRemove[#toRemove + 1] = key
        end
    end
    for _, key in ipairs(toRemove) do
        cache[key] = nil
        cacheSize = cacheSize - 1
    end
end

--- Clear all cache
function Hydra.Data.Cache.Flush()
    cache = {}
    cacheSize = 0
end

--- Remove expired entries
function Hydra.Data.Cache.Cleanup()
    local now = os.time()
    local removed = 0
    for key, entry in pairs(cache) do
        if entry.expires > 0 and now > entry.expires then
            cache[key] = nil
            cacheSize = cacheSize - 1
            removed = removed + 1
        end
    end
    if removed > 0 then
        Hydra.Utils.Log('debug', 'Cache cleanup: removed %d expired entries', removed)
    end
end

--- Evict least recently used entries (batch evict 10% to amortize O(n) scan)
function Hydra.Data.Cache._EvictLRU()
    local evictCount = math.max(1, math.floor(maxEntries * 0.1))
    local entries = {}

    for key, entry in pairs(cache) do
        entries[#entries + 1] = { key = key, lastAccess = entry.lastAccess }
    end

    table.sort(entries, function(a, b)
        return a.lastAccess < b.lastAccess
    end)

    for i = 1, math.min(evictCount, #entries) do
        cache[entries[i].key] = nil
        cacheSize = cacheSize - 1
    end
end

--- Get cache statistics
--- @return table
function Hydra.Data.Cache.GetStats()
    return {
        size = cacheSize,
        maxEntries = maxEntries,
        hits = cacheHits,
        misses = cacheMisses,
        hitRate = (cacheHits + cacheMisses) > 0
            and math.floor((cacheHits / (cacheHits + cacheMisses)) * 100) or 0,
    }
end

--- Check if a key exists and is not expired
--- @param key string
--- @return boolean
function Hydra.Data.Cache.Has(key)
    local entry = cache[key]
    if not entry then return false end
    if entry.expires > 0 and os.time() > entry.expires then
        cache[key] = nil
        cacheSize = cacheSize - 1
        return false
    end
    return true
end

exports('CacheStats', Hydra.Data.Cache.GetStats)
