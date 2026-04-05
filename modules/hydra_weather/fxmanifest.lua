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
    'config/weather.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
