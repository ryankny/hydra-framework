--[[
    Hydra Status
    Player needs system: hunger, thirst, stress and custom statuses.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_status'
description 'Hydra Framework - Player Needs System'
author 'Hydra Framework'
version '1.0.0'

dependencies {
    'hydra_core',
    'hydra_players',
}

shared_scripts {
    '@hydra_core/shared/config.lua',
    '@hydra_core/shared/utils.lua',
    '@hydra_core/shared/events.lua',
    '@hydra_core/shared/module.lua',
    '@hydra_core/shared/api.lua',
    'config/status.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
