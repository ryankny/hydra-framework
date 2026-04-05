--[[
    Hydra Logs - Configuration

    Discord webhook URLs and log channel routing.
    Each log category can have its own webhook URL, color, and toggle.
]]

HydraLogsConfig = {
    -- Master toggle
    enabled = true,

    -- Server name shown in embed footer
    server_name = 'Hydra RP',

    -- Server icon URL for embed thumbnails (optional)
    server_icon = '',

    -- Timestamp format
    timestamp = true,

    -- Include player identifiers in embeds (license, steam, discord, etc.)
    include_identifiers = true,

    -- Rate limit: max webhooks per second (Discord rate limit is ~30/min)
    rate_limit = 5,

    -- Queue: buffer logs and send in batches
    batch_interval = 2, -- seconds between batch sends
    max_batch_size = 10, -- max embeds per batch request

    -- =============================================
    -- LOG CHANNELS
    -- =============================================
    -- Each channel maps to a Discord webhook URL.
    -- Set url = '' to disable a channel.
    -- color: Discord embed color (decimal, not hex)
    --   Green: 3066993, Red: 15158332, Orange: 15105570,
    --   Blue: 3447003, Purple: 7419530, Yellow: 16776960,
    --   White: 16777215, Grey: 9807270
    -- =============================================

    channels = {
        -- Player connections
        connections = {
            enabled = true,
            url = '',  -- Set your Discord webhook URL here
            color = 3066993, -- Green
            label = 'Connections',
        },

        -- Player disconnections
        disconnections = {
            enabled = true,
            url = '',
            color = 15158332, -- Red
            label = 'Disconnections',
        },

        -- Chat messages
        chat = {
            enabled = true,
            url = '',
            color = 3447003, -- Blue
            label = 'Chat',
        },

        -- Deaths & kills
        deaths = {
            enabled = true,
            url = '',
            color = 15158332, -- Red
            label = 'Deaths',
        },

        -- Money transactions (add, remove, transfer)
        money = {
            enabled = true,
            url = '',
            color = 3066993, -- Green
            label = 'Money',
        },

        -- Admin actions (kick, ban, teleport, revive, etc.)
        admin = {
            enabled = true,
            url = '',
            color = 15105570, -- Orange
            label = 'Admin',
        },

        -- Job changes
        jobs = {
            enabled = true,
            url = '',
            color = 7419530, -- Purple
            label = 'Jobs',
        },

        -- Inventory / items
        inventory = {
            enabled = true,
            url = '',
            color = 16776960, -- Yellow
            label = 'Inventory',
        },

        -- Vehicle actions (spawn, store, impound)
        vehicles = {
            enabled = true,
            url = '',
            color = 3447003, -- Blue
            label = 'Vehicles',
        },

        -- Exploit / anti-cheat detections
        anticheat = {
            enabled = true,
            url = '',
            color = 15158332, -- Red
            label = 'Anti-Cheat',
        },

        -- General / miscellaneous
        general = {
            enabled = true,
            url = '',
            color = 9807270, -- Grey
            label = 'General',
        },

        -- Custom channel for developer use
        custom = {
            enabled = true,
            url = '',
            color = 16777215, -- White
            label = 'Custom',
        },
    },

    -- =============================================
    -- DEFAULT WEBHOOK URL
    -- =============================================
    -- If a channel has no URL set, it falls back to this.
    -- Set this to send all logs to one channel.
    -- Leave empty to disable channels without URLs.
    default_url = '',
}

return HydraLogsConfig
