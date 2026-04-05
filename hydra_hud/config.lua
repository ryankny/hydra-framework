--[[
    Hydra HUD - Configuration
]]

HydraHUDConfig = {
    -- Update tick rate (ms) - lower = smoother but more CPU
    update_rate = 100,

    -- Player HUD
    player = {
        enabled = true,
        position = 'bottom-left',    -- 'bottom-left', 'bottom-right', 'bottom-center'
        show_health = true,
        show_armor = true,
        show_hunger = true,
        show_thirst = true,
        show_stamina = false,
        show_oxygen = true,          -- Only when underwater
        show_cash = true,
        show_bank = true,
        show_job = true,
        -- Auto-hide when values are full
        auto_hide = true,
        auto_hide_delay = 5000,      -- ms before hiding full bars
    },

    -- Vehicle HUD
    vehicle = {
        enabled = true,
        show_speedometer = true,
        speed_unit = 'mph',          -- 'mph' or 'kmh'
        show_fuel = true,
        show_engine_health = true,
        show_seatbelt = true,
        show_lock = true,
        show_lights = true,
        show_gear = true,
        show_rpm = true,
    },

    -- Navigation display
    navigation = {
        enabled = true,
        show_compass = true,
        show_street_name = true,
        show_zone = true,
        show_time = true,
        show_direction = true,
        time_format = '12h',         -- '12h' or '24h'
    },

    -- Minimap settings
    minimap = {
        -- Minimap shape: 'square', 'circle', or 'default'
        shape = 'square',
        -- Custom border
        border = true,
        border_color = '#6C5CE7',
    },
}

return HydraHUDConfig
