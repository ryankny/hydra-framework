--[[
    Hydra World - Configuration

    Comprehensive world management: population density, law enforcement,
    ambient scenarios, environment controls, restricted areas, and
    performance tuning. Every aspect is configurable per server needs.
]]

HydraWorldConfig = {

    -- =============================================
    -- POPULATION & TRAFFIC DENSITY
    -- =============================================
    -- Controls how many NPC pedestrians and vehicles
    -- the game spawns. Lower values = better performance.
    -- Range: 0.0 (none) to 1.0 (default GTA) to 3.0+ (heavy)

    population = {
        enabled = true,

        -- Global multipliers (applied continuously)
        ped_density = 0.6,           -- Pedestrian density (0.0 - 3.0)
        vehicle_density = 0.6,       -- Vehicle density (0.0 - 3.0)
        parked_vehicle_density = 0.8, -- Parked vehicle multiplier
        random_vehicle_density = 0.6, -- Random traffic density
        scenario_ped_density = 0.5,  -- Scenario/ambient ped density

        -- Per-zone overrides: [zone_name] = { ped, vehicle }
        -- Zone names use GTA zone labels (e.g., 'DOWNT', 'SANDY', 'PALETO')
        -- Omitted zones use global multipliers above
        zone_overrides = {
            -- Example: quieter sandy shores, busier downtown
            -- DOWNT  = { ped = 0.8, vehicle = 0.9 },
            -- SANDY  = { ped = 0.2, vehicle = 0.3 },
            -- PALETO = { ped = 0.2, vehicle = 0.2 },
            -- GRAPES = { ped = 0.1, vehicle = 0.1 },
        },

        -- Time-of-day multiplier: scales density further at night
        -- Applied on top of base density. 1.0 = no change.
        day_multiplier = 1.0,   -- 06:00 - 20:00
        night_multiplier = 0.5, -- 20:00 - 06:00

        -- Tick rate for applying density (ms). Lower = more responsive.
        tick_rate = 2000,
    },

    -- =============================================
    -- LAW ENFORCEMENT & WANTED SYSTEM
    -- =============================================

    law = {
        enabled = true,

        -- Disable wanted levels entirely (RP servers typically disable)
        disable_wanted_level = true,

        -- Disable police dispatch (no cops called on crimes)
        disable_dispatch = true,

        -- Granular dispatch service toggles
        -- Set to false to disable specific dispatch types
        dispatch_services = {
            police = false,     -- DT_PoliceAutomobile, DT_PoliceHelicopter
            fire = false,       -- DT_FireDepartment
            ambulance = false,  -- DT_SwatAutomobile (oddly named in native)
            army = false,       -- DT_ArmyVehicle dispatches
            bias_police = false, -- DT_BiasPoliceAutomobile (pursuit police)
            swat = false,       -- DT_SwatAutomobile
        },

        -- Disable GTA cops spawning in the world entirely
        disable_ambient_cops = true,

        -- Disable cop blips on minimap
        disable_cop_blips = true,

        -- Tick rate for law enforcement suppression (ms)
        tick_rate = 1000,
    },

    -- =============================================
    -- SCENARIO & AMBIENT PEDS
    -- =============================================
    -- GTA has many ambient "scenarios" like people jogging,
    -- buskers playing music, mechanics working, etc.
    -- You can toggle groups on/off to control the vibe.

    scenarios = {
        enabled = true,

        -- Disable ALL scenarios (overrides individual settings below)
        disable_all = false,

        -- Toggle specific scenario groups
        -- true = enabled (GTA default), false = disabled
        groups = {
            -- Gang activity
            YOURTOWN_GANG         = true,
            YOURTOWN_GANG_2       = true,
            YOURTOWN_GANG_AMBIENT = true,
            ALAMO_GANG            = true,
            SOLOMON_GANG          = true,

            -- Workers / ambient life
            DEALERSHIP             = true,
            PRISON                 = true,
            ARMENIAN_GANG          = true,
            LOST_GANG              = true,
            VAGOS_GANG             = true,
            BALLAS_GANG            = true,
            FAMILIES_GANG          = true,
            MARABUNTA_GANG         = true,
            SALT_GANG              = true,

            -- These can tank performance or break RP
            CODE_2                       = false,  -- Emergency response scenarios
            FIB_GROUP                    = false,  -- FIB agents
            ARMY_BASE                    = false,  -- Military base guards
            PRISON_INMATES               = false,  -- Prison population
            POLICE_POUND                 = false,  -- Police impound

            -- Ambient activities
            MP_POLICE_STATION_SCENARIO   = false,  -- Police station peds
            OBSERVATORY_BIKERS           = true,
            BEACH_PARTY                  = true,
            QUARRY                       = true,
            MOVIE_STUDIO                 = true,
            MOVIE_STUDIO_SETUP           = true,
            COUNTRYSIDE_INVADER_SETUP    = true,
        },

        -- Scenario type suppression (individual scenario actions)
        -- These suppress specific ped behaviors, not groups
        suppress_types = {
            -- 'WORLD_HUMAN_COP_IDLES',        -- Cops idling
            -- 'WORLD_HUMAN_GUARD_STAND',       -- Guards standing
            -- 'WORLD_HUMAN_DRINKING',          -- People drinking
            -- 'WORLD_HUMAN_SMOKING',           -- People smoking
            -- 'WORLD_HUMAN_PROSTITUTE_LOW_CLASS', -- Prostitutes
            -- 'WORLD_HUMAN_PROSTITUTE_HIGH_CLASS',
        },
    },

    -- =============================================
    -- ENVIRONMENT & WORLD OBJECTS
    -- =============================================

    environment = {
        enabled = true,

        -- Garbage trucks
        garbage_trucks = false,

        -- Random boats (offshore)
        random_boats = true,

        -- Random trains
        random_trains = true,

        -- Stunt jumps
        stunt_jumps = false,

        -- Distant sirens
        distant_sirens = false,

        -- Auto-generated vehicle noise
        distant_vehicle_noise = true,

        -- Ambient siren sounds (not attached to vehicles)
        ambient_sirens = false,

        -- Plane flybys (ambient jets, blimps, etc.)
        plane_flybys = true,

        -- Helicopter flybys
        helicopter_flybys = true,

        -- GTA Online mission/session music
        gta_online_music = false,
        loading_screen_music = false,

        -- Flight music
        flight_music = false,

        -- VFX: Enable/disable specific screen effects
        disable_screen_effects = {
            -- 'SwitchShortFX',  -- Character switch flash
            -- 'FocusOut',       -- Focus blur effect
        },
    },

    -- =============================================
    -- NPC COMBAT & AI BEHAVIOR
    -- =============================================

    npc_behavior = {
        enabled = true,

        -- NPC relationship toward players
        -- Options: 'default', 'passive', 'hostile'
        -- 'passive' makes all ambient NPCs ignore crimes
        -- 'hostile' makes all NPCs attack (for events/zombies)
        default_attitude = 'default',

        -- Disable NPC fleeing (they stand still when scared)
        disable_flee = false,

        -- Disable NPC phone calls (calling cops)
        disable_phone_calls = true,

        -- Disable NPC combat (won't attack each other or player)
        disable_combat = false,

        -- Disable NPC critical reactions (dramatic death anims)
        disable_critical_hits = false,

        -- NPC accuracy multiplier (0.0 = stormtrooper, 1.0 = default)
        -- Lower values make firefights more forgiving
        npc_accuracy = 0.4,
    },

    -- =============================================
    -- VEHICLE WORLD OPTIONS
    -- =============================================

    vehicles = {
        enabled = true,

        -- Disable auto-engine on entry (require player to start)
        disable_auto_engine = true,

        -- Lock empty vehicles (prevent jacking parked cars)
        lock_empty_vehicles = false,

        -- Default vehicle lock state for spawned NPC vehicles
        -- 1 = unlocked, 2 = locked, 7 = locked (prevents entry)
        npc_vehicle_lock = 1,

        -- Seatbelt system (integrated with HUD)
        seatbelt = {
            enabled = true,
            eject_speed = 70.0,      -- km/h threshold for ejection on crash
            eject_force = 15.0,      -- Force applied on ejection
            eject_damage = 20,       -- Health damage on ejection
        },

        -- Disable NPC vehicle horns
        disable_npc_horns = true,

        -- Headlight toggle (force headlights on at night)
        force_headlights_night = false,
    },

    -- =============================================
    -- RESTRICTED AREAS / SAFE ZONES
    -- =============================================
    -- Define areas where certain actions are restricted.
    -- Uses sphere-based zones with configurable rules.

    restricted_zones = {
        enabled = true,

        zones = {
            -- Example: Hospital safe zone (no weapons)
            -- {
            --     name = 'pillbox_hospital',
            --     label = 'Pillbox Medical Center',
            --     coords = vector3(307.0, -595.0, 43.3),
            --     radius = 50.0,
            --     rules = {
            --         no_weapons = true,      -- Holster weapons on entry
            --         no_vehicles = false,     -- Prevent vehicle entry
            --         no_pvp = true,           -- Disable player damage
            --         no_wanted = true,        -- Clear wanted level
            --         speed_limit = 0,         -- km/h (0 = no limit)
            --     },
            -- },
            -- Example: Airport (speed limit + no weapons)
            -- {
            --     name = 'lsia',
            --     label = 'Los Santos Airport',
            --     coords = vector3(-1037.0, -2963.0, 13.9),
            --     radius = 250.0,
            --     rules = {
            --         no_weapons = true,
            --         speed_limit = 50,
            --     },
            -- },
        },
    },

    -- =============================================
    -- BLACKLISTED WEAPONS & OBJECTS
    -- =============================================

    blacklist = {
        enabled = true,

        -- Weapons that are removed on spawn or pickup
        -- Uses weapon hash names
        weapons = {
            -- 'WEAPON_MINIGUN',
            -- 'WEAPON_RPG',
            -- 'WEAPON_RAILGUN',
            -- 'WEAPON_STICKYBOMB',
            -- 'WEAPON_GRENADELAUNCHER',
        },

        -- Peds (model hashes) to remove if spawned
        ped_models = {
            -- 's_m_y_cop_01',     -- Cop model
            -- 's_m_y_ranger_01',  -- Park ranger
            -- 's_m_y_sheriff_01', -- Sheriff
        },

        -- Remove weapons from players on spawn
        remove_weapons_on_spawn = false,

        -- Tick rate for blacklist enforcement (ms)
        tick_rate = 5000,
    },

    -- =============================================
    -- PERFORMANCE
    -- =============================================

    performance = {
        -- Distance at which zone-specific overrides apply
        zone_check_distance = 200.0,

        -- Clear area of ambient peds/vehicles when player spawns
        clear_area_on_spawn = false,
        clear_area_radius = 50.0,

        -- Entity cleanup: remove distant abandoned vehicles
        cleanup_abandoned_vehicles = false,
        cleanup_distance = 150.0,
        cleanup_interval = 60000, -- ms
    },

    -- =============================================
    -- ADMIN COMMANDS
    -- =============================================

    admin = {
        -- Permission required for world admin commands
        permission = 'hydra.admin',

        -- Command name for world management
        command = 'world',
    },
}

return HydraWorldConfig
