--[[
    Hydra Camera - Configuration

    Centralized camera settings for transitions, orbit behaviour,
    screen shake, cinematic bars, and cleanup policies.
]]

HydraConfig = HydraConfig or {}

HydraConfig.Camera = {
    -- Master toggle
    enabled = true,

    -- Default field-of-view for new cameras
    default_fov = 50.0,

    -- Default easing mode: smooth, linear, ease_in, ease_out, ease_in_out
    default_ease = 'smooth',

    -- Default transition duration in milliseconds
    default_transition_ms = 1000,

    -- Maximum number of cameras that can exist simultaneously
    max_active_cameras = 8,

    -- Orbit camera: rotation speed (degrees per frame)
    orbit_speed = 2.0,

    -- Orbit camera: vertical pitch clamps (degrees)
    orbit_min_pitch = -80.0,
    orbit_max_pitch = 80.0,

    -- Orbit camera: zoom distance range
    orbit_zoom_min = 1.0,
    orbit_zoom_max = 20.0,

    -- Orbit camera: zoom speed multiplier (per scroll tick)
    orbit_zoom_speed = 0.5,

    -- Screen shake: decay factor per frame (0-1, higher = slower decay)
    shake_decay = 0.95,

    -- Cinematic letterbox: bar height as fraction of screen
    cinematic_bar_size = 0.12,

    -- Cinematic letterbox: fade duration in milliseconds
    cinematic_fade_ms = 500,

    -- Automatically destroy custom cameras when player dies
    cleanup_on_death = true,

    -- Debug logging
    debug = false,
}

return HydraConfig.Camera
