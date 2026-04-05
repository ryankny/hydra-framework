--[[
    Hydra Framework - Default Configuration

    Override these values in your server.cfg or by editing this file.
    All values here serve as sensible defaults for a plug-and-play experience.
]]

HydraConfig = HydraConfig or {}

HydraConfig.Default = {
    -- Framework identity
    framework_name = 'Hydra',
    version = '1.0.0',

    -- Locale / Language
    locale = 'en',

    -- Server settings
    server = {
        max_players = 64,
        queue_enabled = false,
        maintenance_mode = false,
        maintenance_message = 'Server is under maintenance. Please try again later.',
    },

    -- Security settings
    security = {
        -- Token-based event validation
        event_tokens = true,
        -- Rate limiting for events (max events per second per player)
        rate_limit = 50,
        -- Block known exploit events
        exploit_protection = true,
        -- Log suspicious activity
        security_logging = true,
        -- Anti-injection for string params
        sanitize_inputs = true,
        -- Max payload size in bytes for events
        max_event_payload = 65536,
    },

    -- Performance settings
    performance = {
        -- Tick rate for scheduled tasks (ms)
        tick_rate = 100,
        -- Enable server-side entity pooling
        entity_pooling = true,
        -- Cache TTL for player data (seconds)
        player_cache_ttl = 300,
        -- Max concurrent database operations
        max_db_concurrent = 10,
        -- Enable lazy loading of modules
        lazy_load_modules = true,
    },

    -- Debug settings
    debug = {
        enabled = false,
        -- Log level: 'error', 'warn', 'info', 'debug', 'trace'
        log_level = 'info',
        -- Print performance metrics
        print_metrics = false,
    },

    -- Database settings (adapter is configured in hydra_data)
    database = {
        adapter = 'mysql',          -- 'mysql', 'postgresql', 'sqlite', 'mongodb'
        connection_string = nil,    -- If nil, uses oxmysql connection
    },
}

return HydraConfig.Default
