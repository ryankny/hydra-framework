--[[
    Hydra Physics - Configuration

    Hyper-realistic vehicle handling, ragdoll physics, and
    impact system. Every parameter is tunable per vehicle class
    and per impact type. Designed to be extended by future
    vehicle damage and ped damage modules.
]]

HydraPhysicsConfig = {

    -- =============================================
    -- VEHICLE HANDLING
    -- =============================================
    -- Overrides GTA handling values to create more realistic
    -- driving feel. Applied per vehicle class with global
    -- fallback. Uses SetVehicleHandlingFloat under the hood.
    --
    -- All multipliers are relative to the vehicle's default
    -- handling.meta values. 1.0 = stock, <1.0 = reduced, >1.0 = enhanced.

    handling = {
        enabled = true,

        -- Apply handling modifications only when player is driver
        driver_only = true,

        -- How often to check for new vehicles (ms)
        scan_rate = 500,

        -- ---- GLOBAL DEFAULTS ----
        -- Applied to all vehicles unless overridden by class profile

        global = {
            -- Traction
            traction_curve_max = 0.85,       -- Peak lateral grip (lower = more slide)
            traction_curve_min = 0.72,       -- Grip at low speed
            traction_spring_delta_max = 0.12, -- How fast grip recovers
            traction_bias_front = 0.48,      -- Front/rear grip balance (0.5 = equal)
            low_speed_traction_loss = 0.8,   -- Grip loss at low speed turns

            -- Suspension
            suspension_force = 1.8,          -- Spring stiffness (higher = stiffer)
            suspension_comp_damp = 1.2,      -- Compression damping
            suspension_rebound_damp = 1.4,   -- Rebound damping
            suspension_raise = 0.0,          -- Ride height offset
            suspension_bias_front = 0.50,    -- Front/rear suspension bias

            -- Braking
            brake_force = 0.85,              -- Brake power
            brake_bias_front = 0.65,         -- Front brake distribution (realistic front-heavy)
            handbrake_force = 0.7,           -- Handbrake power

            -- Steering
            steering_lock = 0.85,            -- Max steering angle multiplier
            steering_speed = nil,            -- nil = don't override

            -- Drivetrain
            drive_inertia = 0.95,            -- Engine flywheel effect
            clutch_change_rate_up = nil,     -- nil = don't override
            clutch_change_rate_down = nil,

            -- Anti-rollbar
            anti_rollbar_force = 0.85,       -- Roll resistance (higher = less body roll)
            anti_rollbar_bias_front = 0.55,  -- Front/rear ARB balance

            -- Downforce
            downforce_modifier = 1.0,        -- Aerodynamic downforce multiplier

            -- Camber
            camber_stiffness = nil,          -- nil = don't override
        },

        -- ---- PER-CLASS PROFILES ----
        -- Vehicle class IDs: 0=Compacts, 1=Sedans, 2=SUVs, 3=Coupes,
        -- 4=Muscle, 5=Sports Classics, 6=Sports, 7=Super, 8=Motorcycles,
        -- 9=Off-Road, 10=Industrial, 11=Utility, 12=Vans, 13=Cycles,
        -- 14=Boats, 15=Helicopters, 16=Planes, 17=Service,
        -- 18=Emergency, 19=Military, 20=Commercial, 21=Trains, 22=Open Wheel
        --
        -- Only specify values you want to change from global defaults.
        -- Omitted values fall through to global.

        classes = {
            -- Compacts: front-heavy understeer, soft suspension
            [0] = {
                traction_curve_max = 0.78,
                suspension_force = 1.5,
                brake_force = 0.75,
                anti_rollbar_force = 0.65,
            },

            -- Sedans: balanced and predictable
            [1] = {
                traction_curve_max = 0.82,
                suspension_force = 1.6,
                suspension_comp_damp = 1.1,
            },

            -- SUVs: high center of gravity, soft, body roll
            [2] = {
                traction_curve_max = 0.75,
                suspension_force = 2.0,
                suspension_comp_damp = 0.9,
                suspension_rebound_damp = 1.1,
                anti_rollbar_force = 0.55,
                brake_bias_front = 0.60,
            },

            -- Coupes: sporty, responsive
            [3] = {
                traction_curve_max = 0.88,
                suspension_force = 2.0,
                brake_force = 0.90,
                anti_rollbar_force = 0.90,
            },

            -- Muscle: rear-biased, oversteer-prone, torquey
            [4] = {
                traction_curve_max = 0.80,
                traction_bias_front = 0.44,
                low_speed_traction_loss = 1.0,
                suspension_force = 1.6,
                brake_bias_front = 0.62,
                anti_rollbar_force = 0.70,
                drive_inertia = 1.05,
            },

            -- Sports Classics: less grip, more body roll, authentic feel
            [5] = {
                traction_curve_max = 0.76,
                traction_curve_min = 0.65,
                suspension_force = 1.4,
                suspension_comp_damp = 0.9,
                anti_rollbar_force = 0.60,
                brake_force = 0.72,
                brake_bias_front = 0.60,
            },

            -- Sports: sharp, high grip, responsive
            [6] = {
                traction_curve_max = 0.92,
                traction_curve_min = 0.78,
                suspension_force = 2.2,
                suspension_comp_damp = 1.4,
                suspension_rebound_damp = 1.6,
                brake_force = 0.95,
                anti_rollbar_force = 0.95,
                downforce_modifier = 1.3,
            },

            -- Super: race-grade grip and response
            [7] = {
                traction_curve_max = 0.96,
                traction_curve_min = 0.82,
                suspension_force = 2.6,
                suspension_comp_damp = 1.6,
                suspension_rebound_damp = 1.8,
                brake_force = 1.0,
                brake_bias_front = 0.68,
                anti_rollbar_force = 1.0,
                downforce_modifier = 1.8,
            },

            -- Motorcycles: light, twitchy, high lean sensitivity
            [8] = {
                traction_curve_max = 0.82,
                traction_bias_front = 0.46,
                suspension_force = 1.8,
                brake_force = 0.80,
                brake_bias_front = 0.70,
                anti_rollbar_force = 0.0,
            },

            -- Off-Road: soft, absorbing, low traction on road
            [9] = {
                traction_curve_max = 0.70,
                traction_curve_min = 0.60,
                suspension_force = 2.5,
                suspension_comp_damp = 0.8,
                suspension_rebound_damp = 0.9,
                suspension_raise = 0.02,
                anti_rollbar_force = 0.50,
                brake_force = 0.70,
            },

            -- Emergency: tuned for pursuit, stiffer than stock
            [18] = {
                traction_curve_max = 0.88,
                suspension_force = 2.1,
                suspension_comp_damp = 1.3,
                brake_force = 0.92,
                anti_rollbar_force = 0.88,
            },

            -- Open Wheel: F1-style extreme grip and downforce
            [22] = {
                traction_curve_max = 1.0,
                traction_curve_min = 0.88,
                suspension_force = 3.2,
                suspension_comp_damp = 2.0,
                suspension_rebound_damp = 2.2,
                brake_force = 1.0,
                brake_bias_front = 0.58,
                anti_rollbar_force = 1.0,
                downforce_modifier = 3.0,
            },
        },

        -- ---- PER-MODEL OVERRIDES ----
        -- Override handling for specific vehicle models by hash.
        -- Takes highest priority. Specify model name or hash.
        -- Uses same keys as global/class profiles.

        models = {
            -- Example: make the Zentorno more tail-happy
            -- zentorno = {
            --     traction_bias_front = 0.42,
            --     low_speed_traction_loss = 1.2,
            -- },
        },
    },

    -- =============================================
    -- WEIGHT TRANSFER SIMULATION
    -- =============================================
    -- Simulates dynamic weight transfer during acceleration,
    -- braking, and cornering by adjusting grip in real-time.

    weight_transfer = {
        enabled = true,

        -- How aggressively weight shifts affect grip (0.0 - 1.0)
        -- Higher = more dramatic weight transfer effects
        intensity = 0.6,

        -- Braking weight transfer: front gains grip, rear loses
        brake_transfer = 0.15,

        -- Acceleration weight transfer: rear gains grip, front loses
        accel_transfer = 0.10,

        -- Cornering load transfer factor
        lateral_transfer = 0.12,

        -- How quickly weight settles back (lower = more lingering)
        recovery_rate = 0.08,

        -- Update rate for weight calculations (ms)
        tick_rate = 50,
    },

    -- =============================================
    -- SURFACE TRACTION
    -- =============================================
    -- Modifies traction based on surface material.
    -- GTA material hashes mapped to grip multipliers.

    surface_traction = {
        enabled = true,

        -- Material grip multipliers (1.0 = normal road)
        -- Applied on top of vehicle traction values
        materials = {
            -- Paved surfaces
            asphalt     = 1.00,
            concrete    = 0.98,
            cobblestone = 0.90,

            -- Loose surfaces
            gravel      = 0.65,
            sand        = 0.50,
            dirt        = 0.60,
            mud         = 0.40,
            clay        = 0.55,

            -- Slippery surfaces
            grass       = 0.55,
            ice         = 0.15,
            snow        = 0.30,
            wet_road    = 0.75,

            -- Off-road
            offroad     = 0.58,
            forest      = 0.50,
        },

        -- Weather-based grip reduction
        -- Stacks with material multiplier
        weather_modifiers = {
            RAIN     = 0.80,  -- 20% grip loss in rain
            THUNDER  = 0.72,  -- 28% grip loss in storms
            FOGGY    = 0.92,  -- Slight grip loss (damp)
            SNOW     = 0.45,  -- Major grip loss
            SNOWLIGHT = 0.55,
            BLIZZARD = 0.30,
            XMAS     = 0.50,
        },

        -- Check rate for surface type (ms)
        tick_rate = 200,
    },

    -- =============================================
    -- RAGDOLL PHYSICS
    -- =============================================
    -- Controls when and how peds (player + NPC) ragdoll.
    -- Force-based system using mass, velocity, and impact angle.

    ragdoll = {
        enabled = true,

        -- Apply to player
        player = true,

        -- Apply to NPCs within this range of any player
        npc = true,
        npc_range = 80.0,

        -- ---- VEHICLE IMPACT ----
        -- Ped hit by vehicle: force depends on vehicle mass and speed
        vehicle_impact = {
            enabled = true,

            -- Minimum vehicle speed (km/h) to trigger ragdoll
            min_speed = 8.0,

            -- Force multiplier (higher = more dramatic launch)
            force_multiplier = 1.2,

            -- Ragdoll duration based on impact force
            -- { min_force, max_force, min_duration_ms, max_duration_ms }
            duration_curve = {
                { 0,   100,  1500, 3000 },  -- Light hit: 1.5-3s
                { 100, 500,  3000, 6000 },  -- Medium hit: 3-6s
                { 500, 9999, 6000, 10000 }, -- Heavy hit: 6-10s
            },

            -- Vertical launch factor (how much upward force on impact)
            vertical_factor = 0.3,

            -- Whether impact should spin the ped
            apply_torque = true,
            torque_multiplier = 0.6,
        },

        -- ---- BULLET IMPACT ----
        -- Ped hit by bullet: directional force based on weapon
        bullet_impact = {
            enabled = true,

            -- Minimum damage to trigger ragdoll (prevents pistol whip ragdoll)
            min_damage = 15,

            -- Chance to ragdoll per hit (0.0-1.0) at min damage
            -- Scales to 1.0 as damage increases
            base_chance = 0.15,

            -- Force applied on ragdoll trigger
            force = 8.0,

            -- Duration range (ms)
            min_duration = 1200,
            max_duration = 4000,

            -- Headshot always ragdolls
            headshot_always = true,
            headshot_force = 15.0,

            -- Shotgun/explosive always ragdolls
            heavy_weapon_always = true,
            heavy_weapon_force = 20.0,
        },

        -- ---- EXPLOSION IMPACT ----
        explosion_impact = {
            enabled = true,

            -- Force scales with proximity to blast center
            force_multiplier = 2.5,

            -- Max range for ragdoll from explosion center
            max_range = 15.0,

            -- Duration (ms)
            duration = 8000,
        },

        -- ---- MELEE IMPACT ----
        melee_impact = {
            enabled = true,

            -- Chance to ragdoll from heavy melee (running punch, bat, etc.)
            heavy_chance = 0.6,
            heavy_force = 6.0,

            -- Light melee (standing punch)
            light_chance = 0.08,
            light_force = 2.5,

            -- Duration (ms)
            min_duration = 800,
            max_duration = 3000,
        },

        -- ---- FALLING ----
        falling = {
            enabled = true,

            -- Height threshold (meters) before ragdoll activates on land
            min_height = 3.0,

            -- Force multiplier on landing (based on fall distance)
            force_multiplier = 1.0,

            -- Duration (ms)
            min_duration = 1500,
            max_duration = 6000,
        },

        -- ---- OBJECT IMPACT ----
        -- Hit by thrown/moving object
        object_impact = {
            enabled = true,
            min_speed = 5.0,    -- Object must be moving this fast (m/s)
            force_multiplier = 1.0,
            min_duration = 1500,
            max_duration = 5000,
        },

        -- ---- GLOBAL RAGDOLL SETTINGS ----

        -- Cooldown between ragdolls for same ped (ms)
        cooldown = 2000,

        -- Natural motion euphoria blending (more realistic ragdoll poses)
        use_natural_motion = true,

        -- Arm flailing during ragdoll
        arm_flail = true,

        -- Getting-up animation speed multiplier (lower = slower recovery)
        getup_speed = 0.85,

        -- Max concurrent ragdolled NPCs (performance cap)
        max_ragdolled_npcs = 12,

        -- NPC scan rate (ms)
        npc_scan_rate = 250,
    },

    -- =============================================
    -- IMPACT EVENT SYSTEM
    -- =============================================
    -- Central event bus for all physics impacts. Other modules
    -- (vehicle damage, ped damage) hook into these events.
    --
    -- Events emitted:
    --   hydra:physics:vehicleImpact  { ped, vehicle, speed, force, bone }
    --   hydra:physics:bulletImpact   { ped, weapon, damage, bone, attacker }
    --   hydra:physics:explosionImpact { ped, coords, distance, force }
    --   hydra:physics:meleeImpact    { ped, attacker, force, isHeavy }
    --   hydra:physics:fallImpact     { ped, height, force }
    --   hydra:physics:objectImpact   { ped, object, speed, force }
    --   hydra:physics:vehicleCrash   { vehicle, speed, decel, force, direction }
    --
    -- All events include enough data for damage calculation modules.

    impact_events = {
        enabled = true,

        -- Emit events for player
        player = true,

        -- Emit events for NPCs (can be expensive with many NPCs)
        npc = true,
        npc_range = 60.0,

        -- Vehicle crash detection (vehicle-to-vehicle or vehicle-to-world)
        vehicle_crash = {
            enabled = true,

            -- Minimum deceleration (km/h per tick) to register as crash
            min_decel = 15.0,

            -- Minimum speed before crash to register
            min_speed = 20.0,

            -- Cooldown per vehicle (ms)
            cooldown = 500,
        },

        -- Tick rate for impact detection (ms)
        tick_rate = 100,
    },

    -- =============================================
    -- HOOK SYSTEM
    -- =============================================
    -- Future modules register hooks to modify physics behavior.
    -- Hooks can alter force values, cancel ragdolls, or inject
    -- custom damage calculations.
    --
    -- Hook types:
    --   'preRagdoll'     - Before ragdoll applied. Return false to cancel.
    --   'postRagdoll'    - After ragdoll applied. Informational.
    --   'preImpact'      - Before impact event fires. Can modify force.
    --   'postImpact'     - After impact event fires. Informational.
    --   'vehicleCrash'   - Vehicle crash detected. For damage modules.
    --   'forceCalculated' - After force calculation, before application.

    hooks = {
        enabled = true,
    },
}

return HydraPhysicsConfig
