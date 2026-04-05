--[[
    Hydra Anims - Configuration

    Animation engine settings: dict caching, blend defaults,
    queue limits, prop cleanup, and NPC caps.
]]

HydraConfig = HydraConfig or {}

HydraConfig.Anims = {
    -- Master toggle
    enabled = true,

    -- Dict cache: max cached animation dictionaries before LRU eviction
    dict_cache_size = 64,

    -- Timeout (ms) waiting for a dict to load
    dict_timeout = 3000,

    -- Default blend speeds
    default_blend_in = 4.0,
    default_blend_out = -4.0,

    -- Default animation flag (see reference below)
    default_flag = 0,

    -- Maximum queued animations per ped
    max_queue_size = 8,

    -- Interval (ms) between cache cleanup cycles
    cleanup_interval = 30000,

    -- Delay (ms) before deleting props after an animation ends
    prop_cleanup_delay = 100,

    -- Maximum NPCs with managed animations simultaneously
    npc_anim_cap = 30,

    -- Sync animation state to server for visibility by other resources
    sync_to_server = false,

    -- Debug logging
    debug = false,

    --[[
        Animation Flag Reference:
        0   = Normal (plays once, ped cannot move)
        1   = Loop (repeats indefinitely)
        2   = Stop on last frame (holds final pose)
        4   = Upper body only (sync with movement on upper body)
        16  = Upper body only (secondary slot)
        32  = Enable player control (ped can move)
        48  = Upper body + player control (16 + 32)
        49  = Loop + Upper body + player control (1 + 16 + 32)
        120 = Hold last frame + upper body + control (2 + 16 + 32 + ... composite)
    ]]
}
