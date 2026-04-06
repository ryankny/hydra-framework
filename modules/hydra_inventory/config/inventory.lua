--[[
    Hydra Inventory - Configuration

    Core inventory settings: slots, weight, vehicle storage,
    drops, dumpsters, robbery, money, and consumable behavior.
]]

HydraConfig = HydraConfig or {}

HydraConfig.Inventory = {
    -- -----------------------------------------------------------------------
    -- Player inventory
    -- -----------------------------------------------------------------------
    player = {
        slots = 40,                         -- Max inventory slots
        maxWeight = 120000,                 -- Max weight in grams (120 kg)
        -- Hotbar slots (first N slots are hotbar)
        hotbarSlots = 5,
    },

    -- -----------------------------------------------------------------------
    -- Money system
    -- -----------------------------------------------------------------------
    money = {
        -- If true, cash is a physical item that can be dropped/stolen
        -- If false, cash is just a number on the player (still displayed in UI)
        cashAsItem = true,
        -- Cash item name (used when cashAsItem = true)
        cashItemName = 'cash',
        -- Money types displayed in UI header
        types = {
            { name = 'cash', label = 'Cash', icon = 'cash', color = '#00B894' },
            { name = 'bank', label = 'Bank', icon = 'bank', color = '#6C5CE7' },
            { name = 'crypto', label = 'Crypto', icon = 'crypto', color = '#FDCB6E' },
        },
    },

    -- -----------------------------------------------------------------------
    -- Vehicle storage
    -- -----------------------------------------------------------------------
    vehicle = {
        -- Default trunk sizes by vehicle class
        -- Classes: 0=Compact, 1=Sedan, 2=SUV, 3=Coupe, 4=Muscle,
        -- 5=Sports, 6=Super, 7=Motorcycle, 8=Offroad, 9=Industrial,
        -- 10=Utility, 11=Van, 12=Cycle, 13=Boat, 14=Helicopter,
        -- 15=Plane, 16=Service, 17=Emergency, 18=Military, 19=Commercial, 20=Train
        trunkSlots = {
            [0] = 20, [1] = 30, [2] = 40, [3] = 20, [4] = 25,
            [5] = 15, [6] = 10, [7] = 5,  [8] = 35, [9] = 60,
            [10] = 50, [11] = 50, [12] = 0, [13] = 40, [14] = 30,
            [15] = 40, [16] = 30, [17] = 30, [18] = 50, [19] = 80,
            default = 30,
        },
        trunkWeight = {
            [0] = 30000,  [1] = 50000,  [2] = 75000,  [3] = 30000,  [4] = 40000,
            [5] = 25000,  [6] = 15000,  [7] = 8000,   [8] = 60000,  [9] = 150000,
            [10] = 100000, [11] = 100000, [12] = 0,    [13] = 60000, [14] = 50000,
            [15] = 80000, [16] = 50000, [17] = 60000,  [18] = 100000, [19] = 200000,
            default = 50000,
        },
        -- Glovebox (same for all vehicles)
        gloveboxSlots = 5,
        gloveboxWeight = 5000,
        -- Max distance to access trunk/glovebox
        accessDistance = 3.0,
        -- Lock trunk when vehicle is locked
        lockWithVehicle = true,
    },

    -- -----------------------------------------------------------------------
    -- Stashes (static storage locations)
    -- -----------------------------------------------------------------------
    stash = {
        -- Default stash size
        defaultSlots = 50,
        defaultWeight = 200000,
    },

    -- -----------------------------------------------------------------------
    -- World drops
    -- -----------------------------------------------------------------------
    drops = {
        enabled = true,
        -- How long drops persist (seconds, 0 = until restart)
        expireTime = 600,
        -- Max active drops in world
        maxDrops = 100,
        -- Pickup distance
        pickupDistance = 2.0,
        -- Drop bag model
        bagModel = 'prop_cs_heist_bag_01',
        -- Small drop (< this weight uses small prop)
        smallDropWeight = 5000,
        smallDropModel = 'prop_drug_package_02',
    },

    -- -----------------------------------------------------------------------
    -- Dumpster searching
    -- -----------------------------------------------------------------------
    dumpsters = {
        enabled = true,
        -- Dumpster model hashes
        models = {
            'prop_dumpster_01a', 'prop_dumpster_02a', 'prop_dumpster_02b',
            'prop_dumpster_3a', 'prop_dumpster_4a', 'prop_dumpster_4b',
        },
        -- Search time (ms)
        searchTime = 8000,
        -- Cooldown per dumpster (seconds)
        cooldown = 300,
        -- Chance to find something (0-100)
        findChance = 40,
        -- Search distance
        searchDistance = 2.0,
        -- Possible loot (item name -> weight/probability)
        loot = {
            { item = 'plastic',     min = 1, max = 3, chance = 30 },
            { item = 'paper',       min = 1, max = 5, chance = 25 },
            { item = 'bottle',      min = 1, max = 2, chance = 20 },
            { item = 'lighter',     min = 1, max = 1, chance = 10 },
            { item = 'phone_scrap', min = 1, max = 1, chance = 5 },
            { item = 'cash',        min = 1, max = 50, chance = 8 },
            { item = 'lockpick',    min = 1, max = 1, chance = 3 },
        },
    },

    -- -----------------------------------------------------------------------
    -- Give / trade
    -- -----------------------------------------------------------------------
    give = {
        distance = 3.0,                    -- Max distance to give items
        anim = true,                       -- Play give animation
    },

    -- -----------------------------------------------------------------------
    -- Rob / search
    -- -----------------------------------------------------------------------
    rob = {
        enabled = true,
        -- Victim must have hands up (surrender anim)
        requireHandsUp = true,
        -- Distance to rob
        distance = 2.0,
        -- Rob duration (ms)
        duration = 5000,
        -- Can steal cash
        canStealCash = true,
        -- Can steal items
        canStealItems = true,
        -- Max items stolen per rob
        maxItems = 3,
        -- Notify victim
        notifyVictim = true,
        -- Police alert
        policeAlert = true,
        policeAlertChance = 75,
    },

    -- -----------------------------------------------------------------------
    -- Consumables
    -- -----------------------------------------------------------------------
    consumables = {
        -- Cancel on damage
        cancelOnDamage = true,
        -- Cancel on movement (for some items)
        cancelOnMove = false,
        -- Default consume animation
        defaultAnim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger_enter' },
        defaultDuration = 3000,
    },

    -- -----------------------------------------------------------------------
    -- UI settings
    -- -----------------------------------------------------------------------
    ui = {
        -- Keybind to open inventory
        openKey = 'TAB',
        -- Sound effects
        sounds = true,
        -- Show item tooltips
        tooltips = true,
        -- Grid columns
        columns = 5,
    },
}
