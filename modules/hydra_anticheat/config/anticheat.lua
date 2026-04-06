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
        default_duration = 0,               -- 0 = permanent, otherwise seconds
        message = 'You have been banned for cheating. Appeal at discord.gg/yourserver',
        screenshot_on_ban = true,           -- Screenshot capture via exports
        webhook_url = '',                   -- Discord webhook for ban notifications
        save_evidence = true,               -- Persist detection data with ban record
        global_ban_sync = false,            -- Sync bans across linked servers (requires hydra_data)
    },

    -- -----------------------------------------------------------------------
    -- Strike system — accumulate strikes before hard action
    -- -----------------------------------------------------------------------
    strikes = {
        enabled = true,
        threshold = 5,                      -- Strikes before auto-ban
        decay_time = 300,                   -- Seconds before a strike decays
        reset_on_kick = false,              -- Reset strikes when kicked
        escalation = {                      -- Progressive punishment at strike milestones
            [3] = 'warn',                   -- At 3 strikes: warn
            [5] = 'kick',                   -- At 5 strikes: kick
            [8] = 'ban',                    -- At 8 strikes: ban
        },
    },

    -- -----------------------------------------------------------------------
    -- Connection security — pre-join validation
    -- -----------------------------------------------------------------------
    connection = {
        enabled = true,
        -- VPN/Proxy detection (requires external API)
        vpn_detection = false,
        vpn_api_url = '',                   -- IP check API endpoint
        vpn_action = 'kick',
        -- Require identifiers
        require_steam = false,
        require_discord = false,
        require_license = true,
        missing_id_message = 'Please ensure Steam/Discord is running.',
        -- Duplicate identifier detection (ban evasion)
        detect_duplicate_hwid = true,
        hwid_action = 'log',
        hwid_severity = 3,
        -- Connection spam protection
        max_connections_per_minute = 3,
        connection_flood_action = 'kick',
    },

    -- -----------------------------------------------------------------------
    -- Event security
    -- -----------------------------------------------------------------------
    events = {
        enabled = true,
        rate_limit = {
            enabled = true,
            window = 1000,                  -- Time window in ms
            max_events = 30,                -- Max events per window per player
            action = 'kick',
            severity = 4,
        },
        -- Per-event rate limits (event name -> max per second)
        per_event_limits = {},
        -- Events that should never come from clients
        blocked_events = {},
        -- Automatically block server-only events (detected at runtime)
        auto_block_server_events = true,
        -- Payload size limit (bytes) to prevent memory attacks
        max_payload_size = 32768,           -- 32KB
        payload_action = 'kick',
        payload_severity = 4,
    },

    -- -----------------------------------------------------------------------
    -- Resource protection
    -- -----------------------------------------------------------------------
    resources = {
        enabled = true,
        required = { 'hydra_core' },
        block_resource_commands = true,
        detect_injection = true,
        injection_action = 'ban',
        injection_severity = 5,
        check_interval = 30000,
        -- File integrity checking (hash validation)
        integrity_check = false,
        integrity_hashes = {},              -- [resource] = expected_hash
        -- Detect resource stopping mid-session
        detect_stop = true,
        stop_action = 'log',
        stop_severity = 3,
    },

    -- -----------------------------------------------------------------------
    -- Movement / teleport detection (server-authoritative)
    -- -----------------------------------------------------------------------
    movement = {
        enabled = true,
        report_interval = 2000,
        max_foot_speed = 12.0,              -- m/s — sprinting ~7.2
        max_vehicle_speed = 100.0,          -- m/s — ~360 km/h
        max_swim_speed = 5.0,               -- m/s — swimming ~2.0
        max_fall_speed = 80.0,              -- m/s — terminal velocity ~55
        teleport_threshold = 150.0,
        spawn_grace_period = 10000,
        noclip_threshold = 15,
        -- Consecutive violations required before flagging
        speed_consecutive = 3,
        teleport_consecutive = 1,
        noclip_consecutive = 15,
        -- Vehicle fly detection (vehicle in air moving horizontally)
        vehicle_fly = true,
        vehicle_fly_threshold = 10,         -- Consecutive airborne + speed frames
        -- Coordinate bounds (outside GTA map)
        bounds_check = true,
        map_min = vector3(-4500.0, -5000.0, -200.0),
        map_max = vector3(5500.0, 8500.0, 2500.0),
        -- Underground detection (below terrain)
        underground_check = true,
        underground_tolerance = -10.0,      -- metres below ground level
        -- Actions
        speed_action = 'kick',
        speed_severity = 3,
        teleport_action = 'kick',
        teleport_severity = 4,
        noclip_action = 'ban',
        noclip_severity = 5,
        vehicle_fly_action = 'kick',
        vehicle_fly_severity = 4,
        bounds_action = 'ban',
        bounds_severity = 5,
    },

    -- -----------------------------------------------------------------------
    -- God mode detection
    -- -----------------------------------------------------------------------
    godmode = {
        enabled = true,
        check_interval = 10000,
        tolerance = 3,
        max_health = 200,
        max_armour = 100,
        -- Health regeneration tracking (detect impossibly fast regen)
        max_regen_per_second = 5,
        -- Vehicle god mode detection
        vehicle_godmode = true,
        vehicle_check_interval = 15000,
        vehicle_tolerance = 3,
        -- Detect SetEntityInvincible
        invincible_check = true,
        action = 'kick',
        severity = 4,
    },

    -- -----------------------------------------------------------------------
    -- Weapon & combat validation
    -- -----------------------------------------------------------------------
    weapons = {
        enabled = true,
        blacklist = {},
        max_damage_modifier = 1.5,
        rapid_fire_tolerance = 1.3,
        -- One-hit kill detection
        one_hit_kill = true,
        one_hit_tolerance = 3,              -- Consecutive one-shots before flag
        -- Aimbot detection (accuracy analysis)
        aimbot = {
            enabled = true,
            -- Headshot ratio threshold (e.g., 0.9 = 90%+ headshots is suspicious)
            headshot_ratio_threshold = 0.85,
            -- Minimum kills before analysis kicks in
            min_kills_for_analysis = 8,
            -- Snap angle detection: max angle change between frames (degrees)
            snap_angle_threshold = 120.0,
            -- Tracking: hits on same target in rapid succession
            lock_on_threshold = 5,
            lock_on_window = 2000,          -- ms
            action = 'ban',
            severity = 5,
        },
        -- No recoil detection (camera stability during rapid fire)
        no_recoil = {
            enabled = true,
            -- Max camera pitch variance during sustained fire (lower = no recoil)
            min_variance_threshold = 0.5,   -- degrees
            sample_count = 15,              -- Shots to sample before checking
            action = 'kick',
            severity = 4,
        },
        -- Infinite ammo detection
        infinite_ammo = {
            enabled = true,
            check_interval = 10000,
            tolerance = 3,                  -- Consecutive checks with no ammo decrease
            action = 'kick',
            severity = 4,
        },
        -- No reload detection
        no_reload = {
            enabled = true,
            -- Max shots without reload (per weapon class)
            max_continuous_shots = 500,
            action = 'kick',
            severity = 3,
        },
        -- Weapon spawn/give detection (weapons appearing from nowhere)
        give_detection = {
            enabled = true,
            -- Whitelisted sources: hydra_commands, admin, shops, etc.
            whitelisted_sources = {},
            action = 'kick',
            severity = 4,
        },
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
        max_per_player = 30,
        blacklisted_models = {},
        max_peds = 5,
        max_vehicles = 3,
        max_objects = 25,
        -- Entity creation rate limiting
        max_spawn_rate = 10,                -- Max entities created per minute
        -- Detect entity deletion of other players' entities
        protect_other_entities = true,
        -- Vehicle blacklist (specific vehicle models)
        blacklisted_vehicles = {},
        -- Ped blacklist (specific ped models)
        blacklisted_peds = {},
        -- Detect attached objects (attaching props to other players)
        detect_attached_objects = true,
        attached_action = 'kick',
        attached_severity = 4,
        -- Entity ownership validation
        ownership_check = true,
        excess_action = 'kick',
        excess_severity = 3,
        blacklist_action = 'ban',
        blacklist_severity = 5,
        rate_action = 'kick',
        rate_severity = 3,
    },

    -- -----------------------------------------------------------------------
    -- Explosion filtering
    -- -----------------------------------------------------------------------
    explosions = {
        enabled = true,
        blocked_types = { 82, 83, 84 },
        max_per_minute = 10,
        -- Detect explosions at impossible distances
        max_distance = 200.0,               -- Max distance from player to explosion
        -- Detect invisible explosions (no visual but damage)
        detect_invisible = true,
        blocked_action = 'ban',
        blocked_severity = 5,
        flood_action = 'kick',
        flood_severity = 4,
        distance_action = 'kick',
        distance_severity = 4,
    },

    -- -----------------------------------------------------------------------
    -- Spectate / freecam detection
    -- -----------------------------------------------------------------------
    spectate = {
        enabled = true,
        max_camera_distance = 200.0,
        -- Consecutive violations before flag
        consecutive = 3,
        check_interval = 5000,
        action = 'kick',
        severity = 3,
    },

    -- -----------------------------------------------------------------------
    -- Particle / visual spam
    -- -----------------------------------------------------------------------
    particles = {
        enabled = true,
        max_per_second = 15,
        -- Blacklisted particle effects
        blacklisted_effects = {},
        action = 'kick',
        severity = 3,
    },

    -- -----------------------------------------------------------------------
    -- Ped modification detection
    -- -----------------------------------------------------------------------
    ped_flags = {
        enabled = true,
        check_interval = 5000,
        super_jump = true,
        infinite_stamina = false,
        -- Additional ped checks
        detect_invisible = true,
        detect_no_ragdoll = true,
        detect_model_change = true,         -- Non-freemode model changes
        allowed_models = {},                -- Additional allowed ped models
        -- Detect ped task manipulation (ClearPedTasks abuse)
        detect_task_clear = true,
        task_clear_rate = 5,                -- Max clears per 10 seconds
        action = 'kick',
        severity = 3,
    },

    -- -----------------------------------------------------------------------
    -- Vehicle abuse detection
    -- -----------------------------------------------------------------------
    vehicles = {
        enabled = true,
        -- Handling modification detection
        handling_check = true,
        handling_tolerance = 0.3,           -- 30% deviation from stock
        handling_check_interval = 30000,
        -- Vehicle speed modifier detection
        speed_modifier = true,
        max_speed_multiplier = 1.5,
        -- Vehicle fly detection (separate from movement)
        fly_detection = true,
        fly_threshold = 8,                  -- Consecutive airborne frames
        -- Vehicle torpedo (ramming at impossible speed)
        torpedo_detection = true,
        torpedo_speed = 80.0,               -- m/s threshold
        -- Vehicle spawn validation
        spawn_validation = true,
        max_vehicle_spawns_per_minute = 5,
        -- Horn boost detection
        horn_boost = true,
        horn_boost_tolerance = 2.0,         -- Speed increase per horn (m/s)
        -- Actions
        handling_action = 'kick',
        handling_severity = 3,
        fly_action = 'kick',
        fly_severity = 4,
        torpedo_action = 'kick',
        torpedo_severity = 4,
        spawn_action = 'kick',
        spawn_severity = 3,
    },

    -- -----------------------------------------------------------------------
    -- Damage event filtering (server-side)
    -- -----------------------------------------------------------------------
    damage = {
        enabled = true,
        -- Max damage per single hit
        max_single_damage = 500,
        -- Max damage per second (total from one player)
        max_dps = 2000,
        -- Detect damage from impossible distances
        max_damage_distance = 500.0,
        -- Detect self-heal (health increasing without legitimate source)
        detect_self_heal = true,
        self_heal_tolerance = 10,           -- HP per check cycle
        -- Actions
        excess_damage_action = 'kick',
        excess_damage_severity = 4,
        distance_action = 'kick',
        distance_severity = 4,
    },

    -- -----------------------------------------------------------------------
    -- Vision / thermal / night vision abuse
    -- -----------------------------------------------------------------------
    vision = {
        enabled = true,
        -- Detect unauthorised thermal/night vision
        block_thermal = true,
        block_night_vision = true,
        -- Whitelist jobs that can use (e.g., police, military)
        allowed_jobs = { 'police', 'sheriff', 'military' },
        check_interval = 5000,
        action = 'warn',
        severity = 2,
    },

    -- -----------------------------------------------------------------------
    -- Menu / executor detection (client-side heuristics)
    -- -----------------------------------------------------------------------
    menu_detection = {
        enabled = true,
        -- Detect known global variables injected by menus
        check_globals = true,
        -- Detect suspicious native calls
        check_natives = true,
        -- Blacklisted global table names (common executor signatures)
        blacklisted_globals = {
            'ExecutorName', 'CitizenHack', 'HamMafia', 'Dopamine',
            'eulen', 'RedEngine', 'skid', 'LynxMenu', 'brutan',
            '_EXECUTOR', '_ENV_INJECTED', 'CHEAT_ENGINE',
        },
        -- Blacklisted resource names (known cheat resources)
        blacklisted_resources = {
            'menyoo', 'lambda', 'brutan', 'dopamine', 'lynx',
            'redengine', 'skidlauncher', 'hammafia', 'eulen',
        },
        -- Detect NUI devtools (F8 console abuse)
        detect_devtools = true,
        -- Check interval
        check_interval = 15000,
        action = 'ban',
        severity = 5,
    },

    -- -----------------------------------------------------------------------
    -- Chat / command abuse
    -- -----------------------------------------------------------------------
    chat_protection = {
        enabled = true,
        -- Max messages per minute
        max_messages_per_minute = 20,
        -- Max command executions per minute
        max_commands_per_minute = 15,
        -- Detect command injection attempts
        detect_injection = true,
        -- Blocked patterns in chat (regex)
        blocked_patterns = {},
        action = 'kick',
        severity = 3,
    },

    -- -----------------------------------------------------------------------
    -- Desync / lag exploitation
    -- -----------------------------------------------------------------------
    desync = {
        enabled = true,
        -- Detect artificial ping spikes
        max_ping = 800,                     -- ms
        ping_check_interval = 10000,
        -- Consecutive high ping before flag (allow genuine lag spikes)
        ping_tolerance = 5,
        -- Detect position desync (client reports vs server knowledge)
        position_desync_threshold = 50.0,   -- metres difference
        -- Detect animation desync (playing impossible anims)
        anim_desync = true,
        action = 'kick',
        severity = 3,
    },

    -- -----------------------------------------------------------------------
    -- Pickup / collectible manipulation
    -- -----------------------------------------------------------------------
    pickups = {
        enabled = true,
        -- Max pickups collected per minute
        max_per_minute = 30,
        -- Detect collecting pickups at impossible distances
        max_collect_distance = 10.0,
        action = 'kick',
        severity = 3,
    },

    -- -----------------------------------------------------------------------
    -- Teleport whitelist (legitimate teleport sources)
    -- -----------------------------------------------------------------------
    teleport_whitelist = {
        -- Events that legitimately teleport players (bypasses teleport detection)
        events = {
            'hydra:players:teleport',
            'hydra:admin:teleport',
        },
        -- Grace period after whitelisted teleport (ms)
        grace_period = 5000,
    },

    -- -----------------------------------------------------------------------
    -- Logging
    -- -----------------------------------------------------------------------
    logging = {
        enabled = true,
        channel = 'anticheat',
        console = true,
        history_limit = 50,
        -- Discord webhook logging
        webhook = {
            enabled = false,
            url = '',
            -- Minimum severity to send to webhook (1-5)
            min_severity = 3,
            -- Include player identifiers in webhook
            include_identifiers = true,
            -- Include screenshot in webhook
            include_screenshot = true,
            -- Rate limit webhook posts (ms between posts)
            rate_limit = 5000,
        },
        -- File logging
        file_logging = false,
    },

    -- -----------------------------------------------------------------------
    -- Exempt players
    -- -----------------------------------------------------------------------
    exemptions = {
        ace_permission = 'hydra.anticheat.exempt',
        admin_exempt = { 'movement', 'spectate', 'godmode' },
        -- Per-player exemptions (identifier -> modules)
        player_exemptions = {},
    },

    -- -----------------------------------------------------------------------
    -- Trusted resources
    -- -----------------------------------------------------------------------
    trusted_resources = {
        'hydra_core', 'hydra_bridge', 'hydra_players', 'hydra_identity',
        'hydra_commands', 'hydra_admin', 'hydra_anticheat',
    },

    -- -----------------------------------------------------------------------
    -- Honeypot events — fake events that only cheaters would trigger
    -- -----------------------------------------------------------------------
    honeypots = {
        enabled = true,
        -- Fake events registered that legitimate clients never call
        events = {
            'server:GiveWeapon',
            'server:GiveMoney',
            'server:SetAdmin',
            'server:GodMode',
            'server:SpawnVehicle',
            'admin:addMoney',
            'admin:setJob',
            'esx:setJob',
            'esx_addonaccount:getSharedAccount',
            'QBCore:Server:SetMoney',
        },
        action = 'ban',
        severity = 5,
    },

    -- -----------------------------------------------------------------------
    -- Heartbeat system — detect client-side AC bypass
    -- -----------------------------------------------------------------------
    heartbeat = {
        enabled = true,
        -- Expected heartbeat interval (ms)
        interval = 30000,
        -- Tolerance before flagging missed heartbeat
        tolerance = 3,                      -- Missed heartbeats
        -- Challenge-response: server sends random token, client must echo
        challenge_response = true,
        action = 'kick',
        severity = 4,
    },

    -- -----------------------------------------------------------------------
    -- Screenshot evidence system
    -- -----------------------------------------------------------------------
    screenshots = {
        enabled = true,
        -- Auto-screenshot on detection above this severity
        auto_severity = 3,
        -- Max screenshots per player per session
        max_per_session = 10,
        -- Screenshot cooldown (ms)
        cooldown = 30000,
        -- Random periodic screenshots for monitoring
        random_enabled = false,
        random_interval_min = 300000,       -- 5 min
        random_interval_max = 900000,       -- 15 min
    },
}
