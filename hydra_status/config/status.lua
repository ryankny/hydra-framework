--[[
    Hydra Status - Configuration

    Defines player needs, tick rates, and effect thresholds.
]]

HydraStatusConfig = {
    -- How often statuses tick down on the server (seconds)
    tick_interval = 60,

    -- How often to sync status to clients (seconds)
    sync_interval = 10,

    -- Save statuses to player metadata key
    metadata_key = 'statuses',

    -- Status definitions
    -- rate: amount lost per tick_interval (per minute)
    -- min/max: value range (0-100 default)
    -- effects: thresholds that trigger gameplay effects
    statuses = {
        hunger = {
            label = 'Hunger',
            default = 100.0,
            min = 0.0,
            max = 100.0,
            rate = 0.8,  -- Lose 0.8 per minute
            effects = {
                { threshold = 20, type = 'screen_effect', effect = 'low_hunger' },
                { threshold = 0,  type = 'health_drain', amount = 1 },
            },
        },
        thirst = {
            label = 'Thirst',
            default = 100.0,
            min = 0.0,
            max = 100.0,
            rate = 1.0,  -- Lose 1.0 per minute (thirst drains faster)
            effects = {
                { threshold = 20, type = 'screen_effect', effect = 'low_thirst' },
                { threshold = 0,  type = 'health_drain', amount = 2 },
            },
        },
        stress = {
            label = 'Stress',
            default = 0.0,
            min = 0.0,
            max = 100.0,
            rate = -0.2,  -- Naturally decreases (negative = goes toward 0)
            effects = {
                { threshold = 80, type = 'screen_effect', effect = 'high_stress' },
                { threshold = 100, type = 'screen_effect', effect = 'blackout' },
            },
        },
    },

    -- Stress triggers (client-side detection)
    stress_triggers = {
        shooting = 3.0,      -- Per shot fired
        speeding = 0.1,      -- Per tick above speed_threshold
        speed_threshold = 140.0, -- km/h
    },
}

return HydraStatusConfig
