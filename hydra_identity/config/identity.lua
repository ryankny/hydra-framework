--[[
    Hydra Identity - Configuration

    Shared between server and client.
]]

HydraIdentityConfig = {
    -- Multi-character
    multichar = {
        enabled = true,
        max_characters = 5,
        -- Allow character deletion
        allow_delete = true,
        -- Require confirmation before delete
        delete_confirmation = true,
    },

    -- Character creation settings
    creation = {
        -- Minimum name length
        min_name_length = 2,
        -- Maximum name length
        max_name_length = 24,
        -- Minimum age
        min_age = 18,
        -- Maximum age
        max_age = 85,
        -- Default date of birth (YYYY-MM-DD)
        default_dob = '1990-01-01',
    },

    -- Spawn locations (admins can add more)
    -- Players can choose from these when spawning
    spawn_locations = {
        {
            name = 'Last Location',
            description = 'Spawn where you last logged out',
            icon = 'location',
            -- coords are nil for last location (uses saved position)
            coords = nil,
            heading = nil,
            is_last_location = true,
        },
        {
            name = 'Legion Square',
            description = 'Downtown Los Santos',
            icon = 'city',
            coords = { x = 215.76, y = -810.12, z = 30.73 },
            heading = 90.0,
        },
        {
            name = 'Vespucci Beach',
            description = 'Beach boardwalk',
            icon = 'beach',
            coords = { x = -1183.07, y = -1510.67, z = 4.38 },
            heading = 305.0,
        },
        {
            name = 'Sandy Shores',
            description = 'Desert town in Blaine County',
            icon = 'desert',
            coords = { x = 1865.01, y = 3747.85, z = 33.07 },
            heading = 30.0,
        },
        {
            name = 'Paleto Bay',
            description = 'Quiet town in the north',
            icon = 'town',
            coords = { x = -280.93, y = 6226.80, z = 31.49 },
            heading = 135.0,
        },
    },

    -- Nationalities dropdown
    nationalities = {
        'American', 'British', 'Canadian', 'Australian', 'German',
        'French', 'Italian', 'Spanish', 'Mexican', 'Brazilian',
        'Japanese', 'Korean', 'Chinese', 'Indian', 'Russian',
        'Dutch', 'Swedish', 'Norwegian', 'Irish', 'Scottish',
        'Polish', 'Turkish', 'South African', 'Argentinian', 'Colombian',
        'Nigerian', 'Egyptian', 'Jamaican', 'Filipino', 'Thai',
        'Other',
    },

    -- Camera position for character preview/creation
    -- Uses a high-altitude position to avoid world clutter
    camera = {
        -- Character creation camera
        creation = {
            -- Camera looks at the ped from ~2m away, slightly above eye level
            coords = { x = 402.89, y = -1002.0, z = -98.0 },
            ped_coords = { x = 402.89, y = -1000.0, z = -99.0 },
            ped_heading = 180.0,
        },
    },

    -- Default appearance (base values before customisation)
    default_appearance = {
        male = {
            model = 'mp_m_freemode_01',
            face = {
                shape_first = 0, shape_second = 0, shape_third = 0,
                skin_first = 0, skin_second = 0, skin_third = 0,
                shape_mix = 0.5, skin_mix = 0.5, third_mix = 0.0,
            },
            hair = { style = 0, color = 0, highlight = 0 },
            beard = { style = -1, color = 0, opacity = 1.0 },
            eyebrows = { style = 0, color = 0, opacity = 1.0 },
            eyes = { color = 0 },
        },
        female = {
            model = 'mp_f_freemode_01',
            face = {
                shape_first = 21, shape_second = 0, shape_third = 0,
                skin_first = 0, skin_second = 0, skin_third = 0,
                shape_mix = 0.5, skin_mix = 0.5, third_mix = 0.0,
            },
            hair = { style = 0, color = 0, highlight = 0 },
            beard = { style = -1, color = 0, opacity = 1.0 },
            eyebrows = { style = 0, color = 0, opacity = 1.0 },
            eyes = { color = 0 },
        },
    },
}

return HydraIdentityConfig
