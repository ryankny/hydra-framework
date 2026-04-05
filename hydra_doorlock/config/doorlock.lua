--[[
    Hydra Doorlock - Configuration

    Lock types, default settings, admin permissions,
    and pre-configured doors. Doors can also be added
    in-game via admin tool and are persisted to database.
]]

HydraDoorlockConfig = {
    -- =============================================
    -- GENERAL
    -- =============================================

    -- Default interaction distance for locks
    interact_distance = 2.0,

    -- Cooldown between lock/unlock actions (ms)
    action_cooldown = 1000,

    -- Draw 3D text indicators near doors
    draw_indicators = true,
    indicator_distance = 5.0,

    -- Sound effects
    sounds = {
        lock   = { name = 'DOOR_LOCK',   set = 'dlc_heist_door_sounds' },
        unlock = { name = 'DOOR_UNLOCK', set = 'dlc_heist_door_sounds' },
        denied = { name = 'Pin_Bad',     set = 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS' },
    },

    -- =============================================
    -- LOCK TYPES
    -- =============================================
    -- Each lock type defines how access is determined.
    --
    -- Types:
    --   'job'       - Requires specific job(s) and optional min grade
    --   'keypad'    - Requires entering a numeric code
    --   'item'      - Requires holding a specific item (key/keycard)
    --   'gang'      - Requires gang membership
    --   'permission'- Requires ACE permission
    --   'public'    - Anyone can lock/unlock
    --   'owner'     - Only the configured owner identifier
    -- =============================================

    lock_types = {
        job = {
            label = 'Job Lock',
            description = 'Restricted to specific jobs',
        },
        keypad = {
            label = 'Keypad Lock',
            description = 'Requires numeric code',
        },
        item = {
            label = 'Item Lock',
            description = 'Requires a key item',
        },
        permission = {
            label = 'Permission Lock',
            description = 'Requires ACE permission',
        },
        public = {
            label = 'Public Lock',
            description = 'Anyone can toggle',
        },
        owner = {
            label = 'Owner Lock',
            description = 'Only the owner can toggle',
        },
    },

    -- =============================================
    -- ADMIN SETTINGS
    -- =============================================

    -- Permission to create/edit/delete doors in-game
    admin_permission = 'hydra.admin',

    -- Command to enter door creation mode
    admin_command = 'doorlock',

    -- Max doors total (safety limit)
    max_doors = 2000,

    -- =============================================
    -- PRE-CONFIGURED DOORS
    -- =============================================
    -- These are loaded on startup alongside any
    -- database-stored doors. Config doors cannot be
    -- deleted in-game (only toggled/edited).
    --
    -- id: unique string identifier
    -- coords: door position (used for interaction)
    -- model: door model hash (optional, for anim)
    -- heading: door closed heading
    -- locked: default locked state
    -- lock_type: one of the lock types above
    -- lock_data: type-specific configuration
    --   job:        { jobs = { 'police', 'ambulance' }, min_grade = 0 }
    --   keypad:     { code = '1234' }
    --   item:       { item = 'police_key' }
    --   permission: { permission = 'hydra.pd_access' }
    --   public:     {}
    --   owner:      { identifier = 'license:xxxx' }
    -- label: display name
    -- auto_lock: seconds to auto-lock (0 = disabled)
    -- double: paired door model hash (for double doors)
    -- =============================================

    doors = {
        -- Example: Mission Row PD Front Door
        -- {
        --     id = 'mrpd_front',
        --     label = 'MRPD Front Door',
        --     coords = vector3(434.7, -982.2, 30.7),
        --     model = -1215222675,
        --     heading = 90.0,
        --     locked = true,
        --     lock_type = 'job',
        --     lock_data = { jobs = { 'police' }, min_grade = 0 },
        --     auto_lock = 10,
        -- },
    },
}

return HydraDoorlockConfig
