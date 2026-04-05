--[[
    Hydra Scenes - Configuration
]]

HydraConfig = HydraConfig or {}
HydraConfig.Scenes = {
    enabled = true,
    max_concurrent = 1,              -- Max scenes playing simultaneously
    default_skip_key = 'BACKSPACE',  -- Key to skip scene
    allow_skip = true,               -- Allow skipping by default
    hide_hud = true,                 -- Hide HUD during scenes
    show_bars = true,                -- Show cinematic bars during scenes
    disable_controls = true,         -- Disable player controls during scenes
    cleanup_on_disconnect = true,    -- Clean up if player disconnects mid-scene
    debug = false,
}
