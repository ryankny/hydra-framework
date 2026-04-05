--[[
    Hydra Object - Configuration
]]

HydraConfig = HydraConfig or {}

HydraConfig.Object = {
    enabled = true,

    -- Performance limits
    max_objects = 200,              -- Max tracked objects per client
    max_per_owner = 50,             -- Max objects per owner tag
    model_timeout = 5000,           -- ms to wait for model loading
    model_cache_size = 128,         -- Max models kept loaded in memory

    -- Cleanup
    cleanup_interval = 30000,       -- ms between orphan cleanup sweeps
    orphan_timeout = 300000,        -- ms (5 min) before untagged objects auto-delete
    cleanup_on_owner_stop = true,   -- Delete objects when owning resource stops
    validate_interval = 10000,      -- ms between entity validity checks

    -- Object defaults
    default_network = false,        -- Whether objects are networked by default
    default_collision = true,       -- Collision enabled by default
    default_freeze = false,         -- Freeze position by default
    default_lod_distance = 200.0,   -- Draw distance

    -- Placement
    ground_snap_offset = -0.02,     -- Slight offset when snapping to ground
    ground_raycast_distance = 10.0, -- Max raycast distance for ground detection

    debug = false,
}
