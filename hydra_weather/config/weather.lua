--[[
    Hydra Weather - Configuration

    Controls weather types, day/night cycle length,
    transition behaviour, and admin permissions.
]]

HydraWeatherConfig = {
    -- =============================================
    -- TIME SETTINGS
    -- =============================================

    -- Real-time minutes per in-game hour
    -- Lower = faster day/night cycle, Higher = slower
    -- Default 2.0 = 48 real minutes for a full 24h cycle
    -- Set to 60.0 for real-time (1:1)
    minutes_per_hour = 2.0,

    -- Starting time when server boots (24h format)
    default_hour = 8,
    default_minute = 0,

    -- Freeze time (stops time progression)
    freeze_time = false,

    -- Day/Night duration multipliers (relative to minutes_per_hour)
    -- Allows making daytime longer and nighttime shorter, or vice versa
    -- 1.0 = use minutes_per_hour as-is for that period
    day_multiplier = 1.0,    -- Applies during hours 6:00 - 20:00
    night_multiplier = 1.0,  -- Applies during hours 20:00 - 6:00

    -- =============================================
    -- WEATHER SETTINGS
    -- =============================================

    -- Default weather on server start
    default_weather = 'CLEAR',

    -- Freeze weather (stops automatic weather changes)
    freeze_weather = false,

    -- Minutes between automatic weather changes (real minutes)
    -- Set to 0 to disable automatic changes
    weather_change_interval = 15,

    -- Transition duration in seconds when weather changes
    weather_transition_duration = 30.0,

    -- Available weather types and their properties
    -- weight: likelihood of being chosen (higher = more common)
    -- allowed_next: which weather types can follow this one (natural transitions)
    -- blackout: force lights off during this weather
    weather_types = {
        CLEAR = {
            label = 'Clear',
            weight = 30,
            allowed_next = { 'CLEAR', 'CLOUDS', 'OVERCAST', 'SMOG', 'FOGGY' },
            blackout = false,
        },
        EXTRASUNNY = {
            label = 'Extra Sunny',
            weight = 20,
            allowed_next = { 'CLEAR', 'CLOUDS', 'SMOG' },
            blackout = false,
        },
        CLOUDS = {
            label = 'Cloudy',
            weight = 20,
            allowed_next = { 'CLEAR', 'OVERCAST', 'RAIN', 'FOGGY' },
            blackout = false,
        },
        OVERCAST = {
            label = 'Overcast',
            weight = 10,
            allowed_next = { 'CLOUDS', 'RAIN', 'THUNDER', 'CLEARING' },
            blackout = false,
        },
        RAIN = {
            label = 'Rain',
            weight = 8,
            allowed_next = { 'OVERCAST', 'THUNDER', 'CLEARING', 'CLOUDS' },
            blackout = false,
        },
        THUNDER = {
            label = 'Thunder',
            weight = 3,
            allowed_next = { 'RAIN', 'OVERCAST', 'CLEARING' },
            blackout = false,
        },
        CLEARING = {
            label = 'Clearing',
            weight = 8,
            allowed_next = { 'CLEAR', 'CLOUDS', 'EXTRASUNNY' },
            blackout = false,
        },
        SMOG = {
            label = 'Smog',
            weight = 5,
            allowed_next = { 'CLEAR', 'CLOUDS', 'FOGGY' },
            blackout = false,
        },
        FOGGY = {
            label = 'Foggy',
            weight = 5,
            allowed_next = { 'CLEAR', 'CLOUDS', 'SMOG' },
            blackout = false,
        },
        NEUTRAL = {
            label = 'Neutral',
            weight = 3,
            allowed_next = { 'CLEAR', 'CLOUDS' },
            blackout = false,
        },
        SNOWLIGHT = {
            label = 'Light Snow',
            weight = 0, -- Disabled by default, admin only
            allowed_next = { 'SNOW', 'SNOWLIGHT', 'CLOUDS' },
            blackout = false,
        },
        SNOW = {
            label = 'Snow',
            weight = 0,
            allowed_next = { 'SNOWLIGHT', 'BLIZZARD', 'CLOUDS' },
            blackout = false,
        },
        BLIZZARD = {
            label = 'Blizzard',
            weight = 0,
            allowed_next = { 'SNOW', 'SNOWLIGHT' },
            blackout = false,
        },
        XMAS = {
            label = 'Christmas',
            weight = 0,
            allowed_next = { 'SNOWLIGHT', 'SNOW', 'XMAS' },
            blackout = false,
        },
        HALLOWEEN = {
            label = 'Halloween',
            weight = 0,
            allowed_next = { 'FOGGY', 'OVERCAST', 'THUNDER' },
            blackout = false,
        },
    },

    -- Wind speed range (0.0 - 12.0)
    wind = {
        min = 0.0,
        max = 5.0,
    },

    -- =============================================
    -- ADMIN SETTINGS
    -- =============================================

    -- ACE permission required for weather/time commands
    admin_permission = 'hydra.admin',

    -- Commands
    commands = {
        weather    = 'weather',       -- /weather [type]
        time       = 'time',          -- /time [hour] [minute]
        freezetime = 'freezetime',    -- /freezetime
        freezeweather = 'freezeweather', -- /freezeweather
        blackout   = 'blackout',      -- /blackout
    },
}

return HydraWeatherConfig
