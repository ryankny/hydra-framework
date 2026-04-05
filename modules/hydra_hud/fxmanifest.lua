fx_version 'cerulean'
game 'gta5'

name 'hydra_hud'
author 'Hydra Framework'
description 'Hydra Framework - HUD System (Player, Vehicle, Navigation)'
version '1.0.0'

dependencies {
    'hydra_core',
    'hydra_ui',
    'hydra_players',
}

shared_scripts {
    '@hydra_core/shared/config.lua',
    '@hydra_core/shared/utils.lua',
    '@hydra_core/shared/events.lua',
    '@hydra_core/shared/module.lua',
    '@hydra_core/shared/api.lua',
    '@hydra_data/shared/store.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'config.lua',
    'client/main.lua',
    'client/player_hud.lua',
    'client/vehicle_hud.lua',
    'client/navigation.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/css/hud.css',
    'nui/css/vehicle.css',
    'nui/css/navigation.css',
    'nui/js/hud.js',
    'nui/js/vehicle.js',
    'nui/js/navigation.js',
}

lua54 'yes'
