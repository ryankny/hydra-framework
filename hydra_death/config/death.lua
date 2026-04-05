--[[
    Hydra Death - Configuration
]]

HydraDeathConfig = {
    -- Last stand duration (seconds) before forced respawn prompt
    -- Set to 0 to skip last stand
    last_stand_duration = 120,

    -- Respawn timer after last stand expires (seconds)
    -- Player sees a countdown, can hold E to respawn at hospital
    respawn_timer = 10,

    -- Allow EMS revive during last stand
    allow_revive = true,

    -- Respawn cost (deducted from player's bank account)
    respawn_cost = 500,
    respawn_cost_account = 'bank',

    -- Hospital spawn locations (randomly selected on respawn)
    hospitals = {
        { label = 'Pillbox Hill Medical',  coords = vector3(338.2, -1394.3, 32.5),   heading = 50.0 },
        { label = 'Mount Zonah Medical',   coords = vector3(-449.7, -340.8, 34.5),    heading = 270.0 },
        { label = 'Sandy Shores Medical',  coords = vector3(1839.6, 3672.9, 34.3),    heading = 210.0 },
        { label = 'Paleto Bay Medical',    coords = vector3(-247.8, 6331.4, 32.4),    heading = 228.0 },
    },

    -- Disable actions while downed
    disable_while_dead = {
        movement = true,
        combat = true,
        vehicle_entry = true,
    },

    -- Respawn effects
    effects = {
        screen_fade = true,        -- Fade to black on respawn
        heal_on_respawn = true,    -- Full heal on hospital respawn
        remove_weapons = false,    -- Remove weapons on death
    },

    -- Admin/EMS revive command
    revive_command = 'revive',
    revive_permission = 'hydra.admin',

    -- EMS job names that can revive (checked against player job)
    ems_jobs = { 'ambulance', 'doctor', 'ems' },
}

return HydraDeathConfig
