--[[
    Hydra Data - Default Configuration
]]

return {
    -- Database adapter: 'mysql' (more adapters can be added)
    adapter = 'mysql',

    -- Connection pooling
    pool = {
        max_connections = 10,
        idle_timeout = 30000,   -- ms
    },

    -- Cache settings
    cache = {
        enabled = true,
        -- Default TTL in seconds (0 = no expiry)
        default_ttl = 300,
        -- Max entries in memory cache
        max_entries = 10000,
        -- Eviction strategy: 'lru' (least recently used)
        eviction = 'lru',
    },

    -- Real-time subscription settings
    subscriptions = {
        enabled = true,
        -- Max subscriptions per player
        max_per_player = 50,
        -- Debounce notifications (ms)
        debounce = 100,
    },

    -- Query settings
    query = {
        -- Max results per query
        max_results = 1000,
        -- Default page size
        default_page_size = 50,
        -- Query timeout (ms)
        timeout = 5000,
    },

    -- Auto-create tables for collections
    auto_migrate = true,
}
