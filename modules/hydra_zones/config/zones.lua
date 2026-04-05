--[[
    Hydra Zones - Configuration
]]

HydraZonesConfig = {
    -- How often to check player position against zones (ms)
    -- Higher = better performance, lower = more responsive
    tick_rate = 250,

    -- Debug mode (draw zone boundaries)
    debug = false,

    -- Maximum zones that can be active at once (safety limit)
    max_zones = 500,
}

return HydraZonesConfig
