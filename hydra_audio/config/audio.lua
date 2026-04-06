--[[
    Hydra Audio - Configuration

    Centralized audio settings for volume, categories, spatial audio,
    soundbanks, and ambient zones.
]]

HydraConfig = HydraConfig or {}

HydraConfig.Audio = {
    -- Master toggle
    enabled = true,

    -- Master volume multiplier (0.0 to 1.0)
    master_volume = 1.0,

    -- Per-category volume multipliers
    categories = {
        ui      = 0.8,
        ambient = 0.5,
        sfx     = 1.0,
        music   = 0.6,
        voice   = 1.0,
    },

    -- Performance caps
    max_concurrent_sounds  = 32,
    max_concurrent_ambient = 4,

    -- 3D spatial audio settings (metres)
    spatial_falloff            = 30.0,
    spatial_reference_distance = 5.0,

    -- Maintenance
    cleanup_interval     = 10000, -- ms between stale-entry sweeps
    fade_default_duration = 1000, -- ms default fade length

    -- Pre-registered soundbanks (server owners populate)
    -- Example: { name = 'custom_ui', sounds = { click = 'click.ogg', hover = 'hover.ogg' } }
    soundbanks = {},

    -- Ambient zones (server owners populate)
    -- Example: { name = 'beach', coords = vec3(x,y,z), radius = 50.0, sound = 'waves.ogg', volume = 0.3, category = 'ambient' }
    ambient_zones = {},

    -- Debug logging
    debug = false,
}

return HydraConfig.Audio
