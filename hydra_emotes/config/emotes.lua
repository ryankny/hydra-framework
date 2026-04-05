--[[
    Hydra Emotes - Configuration

    Emote definitions, keybind, and command settings.
    Developers can register additional emotes at runtime.
]]

HydraEmotesConfig = {
    -- Command to open emote menu (uses hydra_context if available)
    command = 'emote',
    -- Command alias
    alias = 'e',

    -- Cancel emote key
    cancel_key = 'X',
    cancel_key_description = 'Cancel Emote',

    -- Allow emotes while in vehicle (seated emotes only)
    allow_in_vehicle = false,

    -- Cancel emote on movement
    cancel_on_move = true,

    -- Emote definitions
    -- type: 'anim' (animation), 'scenario' (GTA scenario), 'expression' (face)
    emotes = {
        -- Greetings
        wave = {
            label = 'Wave',
            category = 'greetings',
            type = 'anim',
            dict = 'friends@frj@ig_1',
            anim = 'wave_a',
            duration = 3000,
            flag = 49,
        },
        salute = {
            label = 'Salute',
            category = 'greetings',
            type = 'anim',
            dict = 'anim@mp_player_intuppersalute',
            anim = 'idle_a',
            duration = 3000,
            flag = 49,
        },
        handshake = {
            label = 'Handshake',
            category = 'greetings',
            type = 'anim',
            dict = 'mp_common',
            anim = 'givetake1_a',
            duration = 2500,
            flag = 49,
        },

        -- Actions
        sit = {
            label = 'Sit',
            category = 'actions',
            type = 'scenario',
            scenario = 'PROP_HUMAN_SEAT_BENCH',
            looping = true,
        },
        lean = {
            label = 'Lean Wall',
            category = 'actions',
            type = 'anim',
            dict = 'amb@world_human_leaning@male@wall@back@idle_a',
            anim = 'idle_a',
            looping = true,
            flag = 49,
        },
        crossarms = {
            label = 'Cross Arms',
            category = 'actions',
            type = 'anim',
            dict = 'anim@heists@heist_corona@single_team',
            anim = 'single_team_loop_boss',
            looping = true,
            flag = 49,
        },
        kneel = {
            label = 'Kneel',
            category = 'actions',
            type = 'anim',
            dict = 'amb@medic@standing@kneel@base',
            anim = 'base',
            looping = true,
            flag = 1,
        },
        pushups = {
            label = 'Push Ups',
            category = 'actions',
            type = 'anim',
            dict = 'amb@world_human_push_ups@male@base',
            anim = 'base',
            looping = true,
            flag = 1,
        },
        situps = {
            label = 'Sit Ups',
            category = 'actions',
            type = 'anim',
            dict = 'amb@world_human_sit_ups@male@base',
            anim = 'base',
            looping = true,
            flag = 1,
        },

        -- Expressions
        thumbsup = {
            label = 'Thumbs Up',
            category = 'reactions',
            type = 'anim',
            dict = 'anim@mp_player_intthumbs_up',
            anim = 'idle_a',
            duration = 2500,
            flag = 49,
        },
        facepalm = {
            label = 'Facepalm',
            category = 'reactions',
            type = 'anim',
            dict = 'anim@mp_player_intcelebrationfemale@face_palm',
            anim = 'face_palm',
            duration = 3000,
            flag = 49,
        },
        shrug = {
            label = 'Shrug',
            category = 'reactions',
            type = 'anim',
            dict = 'gestures@m@standing@casual',
            anim = 'gesture_shrug_hard',
            duration = 2000,
            flag = 49,
        },

        -- Dance
        dance = {
            label = 'Dance',
            category = 'dance',
            type = 'anim',
            dict = 'anim@amb@nightclub@dancers@solomale_no_props@',
            anim = 'high_center',
            looping = true,
            flag = 1,
        },
        dance2 = {
            label = 'Dance 2',
            category = 'dance',
            type = 'anim',
            dict = 'anim@amb@nightclub@dancers@solomale_no_props@',
            anim = 'high_center_down',
            looping = true,
            flag = 1,
        },

        -- Scenarios
        smoke = {
            label = 'Smoke',
            category = 'props',
            type = 'scenario',
            scenario = 'WORLD_HUMAN_SMOKING',
            looping = true,
        },
        drink = {
            label = 'Drink Coffee',
            category = 'props',
            type = 'scenario',
            scenario = 'WORLD_HUMAN_DRINKING',
            looping = true,
        },
        clipboard = {
            label = 'Clipboard',
            category = 'props',
            type = 'scenario',
            scenario = 'WORLD_HUMAN_CLIPBOARD',
            looping = true,
        },
        phone = {
            label = 'Phone',
            category = 'props',
            type = 'scenario',
            scenario = 'WORLD_HUMAN_STAND_MOBILE',
            looping = true,
        },
        camera = {
            label = 'Camera',
            category = 'props',
            type = 'scenario',
            scenario = 'WORLD_HUMAN_PAPARAZZI',
            looping = true,
        },
    },

    -- Category labels for the emote menu
    categories = {
        greetings = 'Greetings',
        actions   = 'Actions',
        reactions  = 'Reactions',
        dance     = 'Dance',
        props     = 'Prop Emotes',
    },
}

return HydraEmotesConfig
