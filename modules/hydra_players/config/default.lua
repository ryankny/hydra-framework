--[[
    Hydra Players - Default Configuration
]]

HydraPlayersConfig = {
    -- Identifier priority (first found is used)
    identifier_type = 'license',  -- 'license', 'steam', 'discord', 'fivem'

    -- Multi-character support
    multichar = {
        enabled = false,
        max_characters = 5,
    },

    -- Starting values for new players
    new_player = {
        accounts = {
            cash = 5000,
            bank = 10000,
        },
        job = {
            name = 'unemployed',
            label = 'Unemployed',
            grade = 0,
            grade_name = 'Unemployed',
            grade_label = 'Unemployed',
        },
        group = 'user',
        position = { x = -269.4, y = -955.3, z = 31.2, heading = 205.8 }, -- Default spawn
    },

    -- Auto-save interval (seconds, 0 = disabled)
    auto_save_interval = 300,

    -- Account types
    accounts = {
        cash = { label = 'Cash', default = 0 },
        bank = { label = 'Bank', default = 0 },
        black_money = { label = 'Dirty Money', default = 0 },
    },

    -- Spawn settings
    spawn = {
        -- Use last position on spawn
        use_last_position = true,
        -- Default spawn point if no last position
        default_spawn = { x = -269.4, y = -955.3, z = 31.2, heading = 205.8 },
        -- Spawn selection UI
        spawn_selection = false,
    },

    -- Jobs (can be extended by other modules)
    jobs = {
        unemployed = {
            label = 'Unemployed',
            grades = {
                [0] = { name = 'Unemployed', label = 'Unemployed', salary = 0 },
            },
        },
        police = {
            label = 'Police',
            grades = {
                [0] = { name = 'recruit', label = 'Recruit', salary = 500 },
                [1] = { name = 'officer', label = 'Officer', salary = 750 },
                [2] = { name = 'sergeant', label = 'Sergeant', salary = 1000 },
                [3] = { name = 'lieutenant', label = 'Lieutenant', salary = 1250 },
                [4] = { name = 'chief', label = 'Chief', salary = 1500 },
            },
        },
        ambulance = {
            label = 'EMS',
            grades = {
                [0] = { name = 'emt', label = 'EMT', salary = 500 },
                [1] = { name = 'paramedic', label = 'Paramedic', salary = 750 },
                [2] = { name = 'doctor', label = 'Doctor', salary = 1000 },
                [3] = { name = 'chief', label = 'Chief of Medicine', salary = 1250 },
            },
        },
        mechanic = {
            label = 'Mechanic',
            grades = {
                [0] = { name = 'trainee', label = 'Trainee', salary = 400 },
                [1] = { name = 'mechanic', label = 'Mechanic', salary = 600 },
                [2] = { name = 'senior', label = 'Senior Mechanic', salary = 800 },
                [3] = { name = 'manager', label = 'Manager', salary = 1000 },
            },
        },
        taxi = {
            label = 'Taxi',
            grades = {
                [0] = { name = 'driver', label = 'Driver', salary = 400 },
                [1] = { name = 'senior', label = 'Senior Driver', salary = 600 },
                [2] = { name = 'manager', label = 'Manager', salary = 800 },
            },
        },
    },
}

return HydraPlayersConfig
