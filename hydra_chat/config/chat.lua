--[[
    Hydra Chat - Configuration

    Chat channels, commands, formatting, and permissions.
]]

HydraChatConfig = {
    -- Maximum message length
    max_message_length = 256,

    -- Maximum messages displayed in chat window
    max_messages = 100,

    -- Chat fade timeout (seconds, 0 = never fade)
    fade_timeout = 10,

    -- Show timestamps in chat
    show_timestamps = false,

    -- Default chat channel
    default_channel = 'global',

    -- Command prefix
    command_prefix = '/',

    -- =============================================
    -- CHANNELS
    -- =============================================
    -- Each channel defines how messages are routed.
    -- proximity: only players within range can see it
    -- range: distance for proximity channels (in game units)
    -- color: hex color for the channel tag
    -- permission: ACE permission needed to use this channel (nil = everyone)
    -- =============================================

    channels = {
        global = {
            label = 'Global',
            color = '#6C5CE7',
            proximity = false,
            permission = nil,
            format = '{tag} {name}: {message}',
        },
        local_ = {  -- 'local' is a Lua keyword, using local_
            label = 'Local',
            color = '#FDCB6E',
            proximity = true,
            range = 30.0,
            permission = nil,
            format = '{tag} {name}: {message}',
        },
        ooc = {
            label = 'OOC',
            color = '#A0A0B8',
            proximity = false,
            permission = nil,
            format = '[OOC] {name}: {message}',
        },
        me = {
            label = 'ME',
            color = '#DDA0DD',
            proximity = true,
            range = 20.0,
            permission = nil,
            format = '* {name} {message}',
        },
        tweet = {
            label = 'Tweet',
            color = '#74B9FF',
            proximity = false,
            permission = nil,
            format = '[Tweet] @{name}: {message}',
        },
        admin = {
            label = 'Admin',
            color = '#FF7675',
            proximity = false,
            permission = 'hydra.admin',
            format = '[ADMIN] {name}: {message}',
        },
        announce = {
            label = 'Announce',
            color = '#FF7675',
            proximity = false,
            permission = 'hydra.admin',
            format = '[ANNOUNCEMENT] {message}',
        },
    },

    -- =============================================
    -- CHANNEL COMMANDS
    -- =============================================
    -- Shortcut commands to switch/send to a channel.
    -- /ooc hello  -> sends "hello" to OOC channel
    -- =============================================

    channel_commands = {
        ooc     = 'ooc',
        me      = 'me',
        tweet   = 'tweet',
        local_  = 'local',
        admin   = 'admin',
        announce = 'announce',
    },

    -- =============================================
    -- FORMATTING
    -- =============================================

    -- Job tag display (shows job name before player name)
    show_job_tag = true,

    -- Admin tag display
    show_admin_tag = true,
    admin_tag = 'ADMIN',
    admin_tag_color = '#FF7675',

    -- =============================================
    -- MODERATION
    -- =============================================

    -- Mute permission (players with this ACE can mute others)
    mute_permission = 'hydra.admin',

    -- Spam protection
    spam_protection = {
        enabled = true,
        max_messages = 5,    -- Max messages within window
        window = 10,         -- Window in seconds
        cooldown = 30,       -- Mute duration in seconds when triggered
    },

    -- Word filter
    word_filter = {
        enabled = false,
        -- Add words to filter (replaced with ***)
        words = {},
        -- Action on filter: 'censor' or 'block'
        action = 'censor',
    },

    -- Log chat to hydra_logs
    log_to_discord = true,
}

return HydraChatConfig
