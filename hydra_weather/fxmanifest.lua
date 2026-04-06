--[[
    Hydra Weather
    Synced weather and time system with admin controls.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_weather'
description 'Hydra Framework - Synced Weather & Time System'
author 'Hydra Framework'
version '1.0.0'

dependencies {
    'hydra_core',
}

shared_scripts {
    '@hydra_core/shared/config.lua',
    '@hydra_core/shared/utils.lua',
    '@hydra_core/shared/events.lua',
    '@hydra_core/shared/module.lua',
    '@hydra_core/shared/api.lua',
    'config/weather.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
