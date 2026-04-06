--[[
    Hydra AntiCheat - Configuration

    Master configuration for all detection modules.
    Each detection can be independently enabled, tuned, and assigned an action.

    Actions: 'log', 'warn', 'kick', 'ban'
    Severity: 1 (low) to 5 (critical)
]]

HydraConfig = HydraConfig or {}

HydraConfig.AntiCheat = {
    enabled = true,
    debug = false,

    -- -----------------------------------------------------------------------
    -- Ban / punishment settings
    -- -----------------------------------------------------------------------
    ban = {
        enabled = true,
        default_duration = 0,           -- 0 = permanent, otherwise seconds
        message = 'You have been banned for cheating. Appeal at discord.gg/yourserver',
        screenshot_on_ban = true,       -- Attempt screenshot capture via exports
    },

    -- -----------------------------------------------------------------------
    -- Strike system — accumulate strikes before hard action
    -- -----------------------------------------------------------------------
    strikes = {
        enabled = true,
        threshold = 5,                  -- Strikes before auto-ban
        decay_time = 300,               -- Seconds before a strike decays
        reset_on_kick = false,          -- Reset strikes when kicked
    },

    -- -----------------------------------------------------------------------
    -- Event security
    -- -----------------------------------------------------------------------
    events = {
        enabled = true,
        rate_limit = {
            enabled = true,
            window = 1000,              -- Time window in ms
            max_events = 30,            -- Max events per window per player
            action = 'kick',
            severity = 4,
        },
        blocked_events = {              -- Events that should never come from clients
            -- Add framework-specific events that must be server-only
        },
        -- Validated events: event name -> validator function name
        -- Validators defined in server/events.lua
    },

    -- -----------------------------------------------------------------------
    -- Resource protection
    -- -----------------------------------------------------------------------
    resources = {
        enabled = true,
        -- Resources that must be running (stops execution tampering)
        required = { 'hydra_core' },
        -- Block clients from starting/stopping resources
        block_resource_commands = true,
        -- Detect injected resources (resources not in server config)
        detect_injection = true,
        injection_action = 'ban',
        injection_severity = 5,
        -- Check interval in ms
        check_interval = 30000,
    },

    -- -----------------------------------------------------------------------
    -- Movement / teleport detection (server-authoritative)
    -- -----------------------------------------------------------------------
    movement = {
        enabled = true,
        -- Position snapshot interval (ms) - client reports, server validates
        report_interval = 2000,
        -- Maximum allowed speed on foot (m/s) — sprinting is ~7.2 m/s
        max_foot_speed = 12.0,
        -- Maximum allowed vehicle speed (m/s) — ~300 km/h = 83.3 m/s
        max_vehicle_speed = 100.0,
        -- Teleport: max distance between snapshots (adjusted by time delta)
        teleport_threshold = 150.0,
        -- Ignore teleport checks for this long after spawn/respawn (ms)
        spawn_grace_period = 10000,
        -- Noclip: consecutive airborne+moving frames before flag
        noclip_threshold = 15,
        -- Actions
        speed_action = 'kick',
        speed_severity = 3,
        teleport_action = 'kick',
        teleport_severity = 4,
        noclip_action = 'ban',
        noclip_severity = 5,
    },

    -- -----------------------------------------------------------------------
    -- God mode detection
    -- -----------------------------------------------------------------------
    godmode = {
        enabled = true,
        -- How often the server requests a health check (ms)
        check_interval = 10000,
        -- If a player takes damage but health doesn't change X times
        tolerance = 3,
        -- Max health allowed (above this = modified)
        max_health = 200,
        max_armour = 100,
        action = 'kick',
        severity = 4,
    },

    -- -----------------------------------------------------------------------
    -- Weapon validation
    -- -----------------------------------------------------------------------
    weapons = {
        enabled = true,
        -- Blacklisted weapon hashes (e.g., minigun, railgun if not allowed)
        blacklist = {},
        -- Max damage multiplier tolerance vs native weapon data
        max_damage_modifier = 1.5,
        -- Detect rapid fire beyond weapon RPM
        rapid_fire_tolerance = 1.3,     -- 30% tolerance over native RPM
        -- Actions
        blacklist_action = 'ban',
        blacklist_severity = 5,
        damage_action = 'kick',
        damage_severity = 4,
        rapid_fire_action = 'kick',
        rapid_fire_severity = 3,
    },

    -- -----------------------------------------------------------------------
    -- Entity / object spawn protection
    -- -----------------------------------------------------------------------
    entities = {
        enabled = true,
        -- Max entities a single player can own
        max_per_player = 30,
        -- Blacklisted models (hash or name)
        blacklisted_models = {},
        -- Max peds a player can spawn
        max_peds = 5,
        -- Max vehicles a player can spawn
        max_vehicles = 3,
        -- Actions
        excess_action = 'kick',
        excess_severity = 3,
        blacklist_action = 'ban',
        blacklist_severity = 5,
    },

    -- -----------------------------------------------------------------------
    -- Explosion filtering
    -- -----------------------------------------------------------------------
    explosions = {
        enabled = true,
        -- Blocked explosion types (by GTA explosion type ID)
        blocked_types = { 82, 83, 84 },    -- Orbital cannon, etc.
        -- Max explosions per player per minute
        max_per_minute = 10,
        -- Actions
        blocked_action = 'ban',
        blocked_severity = 5,
        flood_action = 'kick',
        flood_severity = 4,
    },

    -- -----------------------------------------------------------------------
    -- Spectate / freecam detection
    -- -----------------------------------------------------------------------
    spectate = {
        enabled = true,
        -- If player position diverges from ped position
        max_camera_distance = 200.0,
        action = 'kick',
        severity = 3,
    },

    -- -----------------------------------------------------------------------
    -- Particle / visual spam
    -- -----------------------------------------------------------------------
    particles = {
        enabled = true,
        max_per_second = 15,
        action = 'kick',
        severity = 3,
    },

    -- -----------------------------------------------------------------------
    -- Clear ped tasks / modification detection
    -- -----------------------------------------------------------------------
    ped_flags = {
        enabled = true,
        -- Monitor for impossible ped config flags
        check_interval = 5000,
        -- Detect super jump
        super_jump = true,
        -- Detect infinite stamina (when not allowed)
        infinite_stamina = false,
        action = 'kick',
        severity = 3,
    },

    -- -----------------------------------------------------------------------
    -- Logging
    -- -----------------------------------------------------------------------
    logging = {
        enabled = true,
        -- Log channel name for hydra_logs integration
        channel = 'anticheat',
        -- Log to server console
        console = true,
        -- Store detection history per player (in-memory)
        history_limit = 50,
    },

    -- -----------------------------------------------------------------------
    -- Exempt players (by ace permission)
    -- -----------------------------------------------------------------------
    exemptions = {
        ace_permission = 'hydra.anticheat.exempt',
        -- Exempt from specific modules (or 'all')
        admin_exempt = { 'movement', 'spectate', 'godmode' },
    },

    -- -----------------------------------------------------------------------
    -- Whitelist: trusted server-side scripts that trigger events
    -- -----------------------------------------------------------------------
    trusted_resources = {
        'hydra_core', 'hydra_bridge', 'hydra_players', 'hydra_identity',
        'hydra_commands', 'hydra_admin', 'hydra_anticheat',
    },
}
