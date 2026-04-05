--[[
    Hydra Target - Configuration
]]

HydraTargetConfig = {
    -- Enable/disable the targeting system
    enabled = true,

    -- Keybind to activate targeting mode
    -- Uses FiveM RegisterKeyMapping for user-rebindable keys
    key = 'LMENU',  -- Left Alt
    key_description = 'Toggle Target Mode',

    -- Maximum raycast distance (performance: lower = better)
    max_distance = 7.0,

    -- How often the raycast runs in target mode (ms)
    -- Lower = smoother but more CPU. 0 = every frame
    tick_rate = 0,

    -- Outline/highlight when targeting an entity
    highlight = {
        enabled = true,
        color = { r = 108, g = 92, b = 231, a = 180 }, -- Hydra purple
    },

    -- Indicator icon at center of screen when target mode active
    draw_sprite = true,

    -- Debug mode (draw raycast lines)
    debug = false,
}

return HydraTargetConfig
