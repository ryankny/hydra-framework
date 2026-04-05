--[[
    Hydra Interact - Configuration
]]

HydraConfig = HydraConfig or {}

HydraConfig.Interact = {
    -- Enable/disable the interaction system
    enabled = true,

    -- Default interaction distance (units)
    default_distance = 2.5,

    -- Absolute maximum interaction distance
    max_distance = 10.0,

    -- Cooldown between interactions (ms)
    cooldown = 500,

    -- Use hydra_target for 3D eye targeting when available
    use_target = true,

    -- Use hydra_zones for proximity detection when available
    use_zones = true,

    -- Show floating interaction prompts near points
    show_prompts = true,

    -- Default key displayed in prompts
    prompt_key = 'E',

    -- GTA-style prompt format string (%s replaced with label)
    prompt_format = '[~INPUT_CONTEXT~] %s',

    -- Highlight interactable entities with outline
    outline_entities = true,

    -- Outline color for interactable entities
    outline_color = { r = 66, g = 135, b = 245, a = 255 },

    -- Maximum number of active interaction points (performance cap)
    max_active_points = 500,

    -- How often proximity checks run (ms)
    tick_rate = 200,

    -- Debug mode (logs, draw markers at interaction points)
    debug = false,
}

return HydraConfig.Interact
