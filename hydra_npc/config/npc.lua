--[[
    Hydra NPC - Configuration
]]

HydraConfig = HydraConfig or {}
HydraConfig.NPC = {
    enabled = true,
    max_npcs = 100,                  -- Max managed NPCs client-side
    spawn_distance = 50.0,           -- Distance to spawn NPCs
    despawn_distance = 80.0,         -- Distance to despawn NPCs
    model_timeout = 5000,            -- ms for model loading
    default_blocking = false,        -- Whether NPCs block player by default
    default_invincible = true,       -- NPCs invincible by default
    default_frozen = true,           -- NPCs frozen in place by default
    cleanup_interval = 15000,        -- ms between cleanup sweeps
    proximity_check_rate = 1000,     -- ms between distance checks
    enable_proximity_spawning = true, -- Auto spawn/despawn based on distance
    network_npcs = false,            -- Whether NPCs are networked by default
    debug = false,

    -- Behavior defaults
    behavior = {
        flee_on_gunshot = false,
        react_to_player = false,
        default_relationship = 'companion', -- 'companion' | 'like' | 'neutral' | 'dislike' | 'hate'
        combat_ability = 0,            -- 0 = poor, 1 = average, 2 = professional
        combat_range = 0,              -- 0 = near, 1 = medium, 2 = far
    },

    -- Pre-defined NPC templates (server owners extend this)
    templates = {
        -- Example:
        -- shopkeeper = { model = 'a_m_m_indian_01', scenario = 'WORLD_HUMAN_STAND_IMPATIENT', invincible = true, frozen = true },
    },
}
