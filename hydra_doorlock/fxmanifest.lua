--[[
    Hydra Doorlock
    Advanced door lock system with multiple lock types,
    in-game admin configuration, and database persistence.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_doorlock'
description 'Hydra Framework - Advanced Door Lock System'
author 'Hydra Framework'
version '1.0.0'

dependencies {
    'hydra_core',
    'hydra_data',
    'hydra_players',
}

shared_scripts {
    '@hydra_core/shared/config.lua',
    '@hydra_core/shared/utils.lua',
    '@hydra_core/shared/events.lua',
    '@hydra_core/shared/module.lua',
    '@hydra_core/shared/api.lua',
    'config/doorlock.lua',
}

server_scripts {
    'server/main.lua',
    'server/admin.lua',
}

client_scripts {
    'client/main.lua',
    'client/admin.lua',
}
