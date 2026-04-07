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
        enabled = false,  -- Disabled by default — enable when tuned for your server

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

            -- Industrial: heavy, slow response, strong brakes
            [10] = {
                traction_curve_max = 0.68,
                traction_curve_min = 0.55,
                suspension_force = 2.8,
                suspension_comp_damp = 0.8,
                suspension_rebound_damp = 0.9,
                brake_force = 0.80,
                brake_bias_front = 0.55,
                anti_rollbar_force = 0.50,
                drive_inertia = 1.15,
            },

            -- Utility: work trucks, moderate handling
            [11] = {
                traction_curve_max = 0.72,
                suspension_force = 1.8,
                suspension_comp_damp = 0.9,
                brake_force = 0.75,
                anti_rollbar_force = 0.55,
                drive_inertia = 1.05,
            },

            -- Vans: heavy, boxy, body roll
            [12] = {
                traction_curve_max = 0.70,
                traction_curve_min = 0.58,
                suspension_force = 1.7,
                suspension_comp_damp = 0.85,
                suspension_rebound_damp = 1.0,
                brake_force = 0.72,
                brake_bias_front = 0.58,
                anti_rollbar_force = 0.50,
                drive_inertia = 1.08,
            },

            -- Cycles: human-powered, minimal physics override
            [13] = {
                traction_curve_max = 0.80,
                brake_force = 0.60,
                anti_rollbar_force = 0.0,
            },

            -- Boats: water handling (minimal land-based effect)
            [14] = {
                traction_curve_max = 0.50,
                suspension_force = 1.0,
            },

            -- Helicopters: no ground handling relevance
            [15] = {},

            -- Planes: no ground handling relevance
            [16] = {},

            -- Service: buses, taxis, moderate handling
            [17] = {
                traction_curve_max = 0.75,
                suspension_force = 1.8,
                suspension_comp_damp = 1.0,
                brake_force = 0.78,
                anti_rollbar_force = 0.60,
                drive_inertia = 1.05,
            },

            -- Emergency: tuned for pursuit, stiffer than stock
            [18] = {
                traction_curve_max = 0.88,
                suspension_force = 2.1,
                suspension_comp_damp = 1.3,
                brake_force = 0.92,
                anti_rollbar_force = 0.88,
            },

            -- Military: heavy, wide, stable at speed
            [19] = {
                traction_curve_max = 0.74,
                traction_curve_min = 0.62,
                suspension_force = 3.0,
                suspension_comp_damp = 1.0,
                suspension_rebound_damp = 1.1,
                suspension_raise = 0.03,
                brake_force = 0.85,
                anti_rollbar_force = 0.70,
                drive_inertia = 1.20,
            },

            -- Commercial: big rigs, trailers, very heavy
            [20] = {
                traction_curve_max = 0.65,
                traction_curve_min = 0.50,
                suspension_force = 3.2,
                suspension_comp_damp = 0.7,
                suspension_rebound_damp = 0.8,
                brake_force = 0.70,
                brake_bias_front = 0.52,
                anti_rollbar_force = 0.45,
                drive_inertia = 1.25,
            },

            -- Trains: no handling override
            [21] = {},

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
        enabled = false,

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
        enabled = false,

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
    -- VEHICLE ROLLOVER
    -- =============================================
    -- Simulates realistic vehicle rollovers. GTA's default
    -- anti-roll is extremely aggressive - vehicles almost never
    -- flip. This reduces anti-roll force dynamically during
    -- sharp turns, high-speed direction changes, and off-road
    -- bumps, making SUVs and tall vehicles behave realistically.

    rollover = {
        enabled = true,

        -- How aggressively roll is allowed (0.0 = stock GTA, 1.0 = very tippy)
        intensity = 0.7,

        -- Speed threshold (km/h) to begin roll calculations
        -- Below this, stock anti-roll is preserved for low-speed stability
        min_speed = 25.0,

        -- Maximum anti-roll reduction factor (0.0 = full removal, 1.0 = no change)
        -- Lower values = vehicles can roll more easily
        min_arb_factor = 0.15,

        -- Lateral G-force threshold to trigger roll vulnerability
        -- Higher = only extreme turns cause roll risk
        lateral_g_threshold = 0.4,

        -- Per-class roll susceptibility (higher = tips easier)
        -- Vehicles with high center of gravity should tip more
        -- All 23 GTA vehicle classes (0-22) covered.
        -- Custom vehicles inherit their vehicles.meta class automatically.
        class_multipliers = {
            [0]  = 0.6,    -- Compacts: low CoG, stable
            [1]  = 0.7,    -- Sedans: moderate
            [2]  = 1.3,    -- SUVs: high CoG, roll-prone
            [3]  = 0.5,    -- Coupes: low, stable
            [4]  = 0.8,    -- Muscle: moderate-high
            [5]  = 0.7,    -- Sports Classics
            [6]  = 0.4,    -- Sports: very low CoG
            [7]  = 0.3,    -- Super: ground-hugging
            [8]  = 1.5,    -- Motorcycles: highside potential
            [9]  = 1.1,    -- Off-Road: tall, moderate roll
            [10] = 1.4,    -- Industrial: heavy, top-heavy
            [11] = 1.2,    -- Utility: vans, trucks
            [12] = 1.3,    -- Vans: tall, boxy
            [13] = 2.0,    -- Cycles: very tippy, narrow wheelbase
            [14] = 0.3,    -- Boats: N/A on water, low on land
            [15] = 0.0,    -- Helicopters: no roll physics
            [16] = 0.0,    -- Planes: no roll physics
            [17] = 1.0,    -- Service: buses, moderate
            [18] = 0.8,    -- Emergency: tuned suspension
            [19] = 0.9,    -- Military: heavy but wide
            [20] = 1.5,    -- Commercial: trucks, very top-heavy
            [21] = 0.0,    -- Trains: no roll physics
            [22] = 0.2,    -- Open Wheel: extremely low CoG
        },

        -- Uneven terrain roll multiplier (bumps/jumps amplify roll)
        terrain_amplify = 1.3,

        -- Recovery: how quickly ARB restores when driving straight
        -- Lower = takes longer to stabilize after near-roll
        recovery_rate = 0.06,

        -- Tick rate (ms)
        tick_rate = 50,
    },

    -- =============================================
    -- AQUAPLANING / HYDROPLANING
    -- =============================================
    -- Vehicles lose traction on standing water during rain.
    -- Effect scales with speed: faster = more aquaplaning.
    -- Simulates the wedge of water lifting tires off the road.

    aquaplaning = {
        enabled = true,

        -- Only active during these weather types
        weather_types = {
            'RAIN', 'THUNDER',
        },

        -- Speed threshold (km/h) where aquaplaning begins
        -- Real-world aquaplaning starts ~80km/h on worn tires
        onset_speed = 60.0,

        -- Speed at which aquaplaning reaches maximum effect
        full_speed = 120.0,

        -- Maximum traction loss at full aquaplaning (0.0-1.0)
        -- 0.5 = lose 50% of grip at full_speed in rain
        max_traction_loss = 0.45,

        -- Steering responsiveness reduction during aquaplaning (0.0-1.0)
        -- Simulates the steering becoming "floaty"
        steering_loss = 0.35,

        -- Random directional pull during aquaplaning
        -- Simulates uneven water hitting tires, causing drift
        drift_pull = {
            enabled = true,
            intensity = 0.4,      -- How strong the random pull is
            change_rate = 2000,   -- How often pull direction changes (ms)
        },

        -- Braking distance increase during aquaplaning (multiplier)
        brake_reduction = 0.40,

        -- Per-class resistance to aquaplaning (higher = more resistant)
        -- Wide tires and heavy vehicles aquaplane less.
        -- All 23 classes covered - custom vehicles auto-inherit.
        class_resistance = {
            [0]  = 0.9,    -- Compacts: narrow tires, light
            [1]  = 1.0,    -- Sedans: average
            [2]  = 1.2,    -- SUVs: heavier, more ground pressure
            [3]  = 0.9,    -- Coupes: sporty tires, light
            [4]  = 1.0,    -- Muscle: wide rears, moderate
            [5]  = 0.8,    -- Sports Classics: old tire tech
            [6]  = 0.85,   -- Sports: wide but low-profile
            [7]  = 0.7,    -- Super: wide slicks, low profile
            [8]  = 0.6,    -- Motorcycles: very vulnerable
            [9]  = 1.4,    -- Off-Road: aggressive treads
            [10] = 1.5,    -- Industrial: massive tires, heavy
            [11] = 1.2,    -- Utility: chunky tires
            [12] = 1.1,    -- Vans: heavy, wide contact patch
            [13] = 0.5,    -- Cycles: thin tires, worst
            [14] = 0.0,    -- Boats: N/A
            [15] = 0.0,    -- Helicopters: N/A
            [16] = 0.0,    -- Planes: N/A
            [17] = 1.1,    -- Service: commercial tires
            [18] = 1.1,    -- Emergency: performance all-season
            [19] = 1.5,    -- Military: heavy-duty treads
            [20] = 1.6,    -- Commercial: massive contact patch
            [21] = 0.0,    -- Trains: N/A
            [22] = 0.5,    -- Open Wheel: slick tires, worst in rain
        },

        -- Visual indicator: notify player when aquaplaning
        show_warning = true,
        warning_threshold = 0.4, -- Traction loss % to trigger warning

        -- Tick rate (ms)
        tick_rate = 100,
    },

    -- =============================================
    -- MUD / DIRT BOGGING & SINKING
    -- =============================================
    -- Vehicles slow down, lose traction, and can get stuck
    -- when driving on mud, dirt, and sand. Simulates wheel
    -- sinking into soft ground with progressive resistance.
    -- Heavier vehicles sink more, off-road vehicles resist.

    bogging = {
        enabled = true,

        -- Surface types that cause bogging
        -- Each surface has: traction_mult, resistance, sink_rate, max_sink
        --   traction_mult: grip multiplier (stacks with surface_traction)
        --   resistance: speed reduction force (higher = slower max speed)
        --   sink_rate: how fast the vehicle sinks per second while stationary/slow
        --   max_sink: maximum sink depth (visual + physics effect)
        --   escape_difficulty: 0.0 (easy to escape) to 1.0 (nearly stuck)
        surfaces = {
            mud = {
                traction_mult = 0.45,
                resistance = 0.35,
                sink_rate = 0.08,
                max_sink = 0.25,
                escape_difficulty = 0.7,
            },
            dirt = {
                traction_mult = 0.70,
                resistance = 0.15,
                sink_rate = 0.03,
                max_sink = 0.10,
                escape_difficulty = 0.3,
            },
            sand = {
                traction_mult = 0.50,
                resistance = 0.30,
                sink_rate = 0.06,
                max_sink = 0.20,
                escape_difficulty = 0.6,
            },
            grass = {
                traction_mult = 0.75,
                resistance = 0.08,
                sink_rate = 0.01,
                max_sink = 0.05,
                escape_difficulty = 0.1,
            },
            forest = {
                traction_mult = 0.55,
                resistance = 0.25,
                sink_rate = 0.05,
                max_sink = 0.15,
                escape_difficulty = 0.5,
            },
        },

        -- Weather makes bogging worse (rain = softer ground)
        weather_multipliers = {
            RAIN     = 1.5,   -- 50% worse in rain
            THUNDER  = 1.8,   -- 80% worse in storms
        },

        -- Speed below which sinking begins (km/h)
        -- Vehicle must be slow/stopped to sink
        sink_speed_threshold = 5.0,

        -- Speed needed to escape (km/h) - above this, sinking stops
        escape_speed = 15.0,

        -- Wheel spin effect: revving while stuck digs deeper
        wheelspin_dig = {
            enabled = true,
            dig_rate = 0.04,       -- Extra sink per second while spinning
            rpm_threshold = 0.6,   -- RPM % to trigger digging
        },

        -- Per-class bogging resistance (higher = less affected)
        -- Off-road vehicles have aggressive treads, wider stance.
        -- All 23 classes covered - custom vehicles auto-inherit.
        class_resistance = {
            [0]  = 0.8,    -- Compacts: low clearance, road tires
            [1]  = 0.85,   -- Sedans: road tires, moderate weight
            [2]  = 1.1,    -- SUVs: moderate off-road ability
            [3]  = 0.7,    -- Coupes: low clearance, sport tires
            [4]  = 0.9,    -- Muscle: high torque helps, road tires
            [5]  = 0.7,    -- Sports Classics: old, low, fragile
            [6]  = 0.6,    -- Sports: low clearance, terrible off-road
            [7]  = 0.5,    -- Super: ground-scraping, very bad
            [8]  = 0.8,    -- Motorcycles: light but narrow
            [9]  = 1.8,    -- Off-Road: built for this
            [10] = 1.3,    -- Industrial: heavy, large tires
            [11] = 1.2,    -- Utility: work vehicles, decent
            [12] = 1.0,    -- Vans: heavy, average tires
            [13] = 0.5,    -- Cycles: very light, sinks in
            [14] = 0.0,    -- Boats: N/A
            [15] = 0.0,    -- Helicopters: N/A
            [16] = 0.0,    -- Planes: N/A
            [17] = 0.9,    -- Service: buses/taxis, road-only
            [18] = 1.1,    -- Emergency: reinforced, moderate off-road
            [19] = 1.5,    -- Military: wide tracks, heavy duty
            [20] = 1.2,    -- Commercial: heavy, large tires
            [21] = 0.0,    -- Trains: N/A
            [22] = 0.3,    -- Open Wheel: impossible off-road
        },

        -- Vehicle weight factor: heavier = sinks faster
        -- Uses vehicle handling mass value
        weight_factor = 0.3,  -- How much mass influences sink rate (0.0-1.0)

        -- Stuck state: when sink reaches max, vehicle is "stuck"
        stuck = {
            -- Force needed to break free (holding throttle)
            escape_time = 3.0,          -- Seconds of full throttle to escape
            escape_traction_boost = 1.5, -- Temporary traction boost while escaping

            -- Rocking mechanic: alternating forward/reverse helps escape
            rocking = {
                enabled = true,
                boost_per_rock = 0.15,  -- Each rock adds this to escape progress
                rock_window = 2000,     -- ms window to detect a "rock" (direction change)
            },
        },

        -- Visual feedback
        show_stuck_warning = true,
        show_sinking_indicator = true,

        -- Tick rate (ms)
        tick_rate = 100,
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
