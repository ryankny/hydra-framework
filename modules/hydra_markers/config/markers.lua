--[[
    Hydra Markers - Configuration
]]

HydraConfig = HydraConfig or {}
HydraConfig.Markers = {
    enabled = true,
    max_markers = 200,               -- Max active markers
    max_draw_distance = 100.0,       -- Max render distance
    default_draw_distance = 30.0,    -- Default render distance
    tick_rate = 0,                   -- Frame-based rendering (0 = every frame when in range)
    proximity_check_rate = 500,      -- ms between distance checks for activation
    default_marker_type = 1,         -- Cylinder
    default_scale = vector3(1.0, 1.0, 1.0),
    default_color = { r = 108, g = 92, b = 231, a = 180 },
    default_bob = false,             -- Bobbing animation
    default_rotate = false,          -- Rotation animation
    float_text_font = 4,
    float_text_scale = 0.35,
    float_text_color = { r = 255, g = 255, b = 255, a = 220 },
    checkpoint_flash = true,         -- Flash checkpoints on enter
    debug = false,
}
