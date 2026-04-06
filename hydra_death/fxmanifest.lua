--[[
    Hydra Death
    Death, last stand, respawn, and hospital mechanics.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_death'
description 'Hydra Framework - Death & Respawn System'
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
    'config/death.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
