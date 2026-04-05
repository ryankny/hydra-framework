fx_version 'cerulean'
game 'gta5'

name 'hydra_identity'
author 'Hydra Framework'
description 'Hydra Framework - Character Creation, Selection & Identity'
version '1.0.0'

dependencies {
    'hydra_core',
    'hydra_data',
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
    'config/identity.lua',
    'server/characters.lua',
    'server/main.lua',
}

client_scripts {
    'config/identity.lua',
    'client/main.lua',
    'client/camera.lua',
    'client/ped_preview.lua',
    'client/appearance.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/css/identity.css',
    'nui/js/identity.js',
    'nui/js/creation.js',
    'nui/js/selection.js',
    'nui/js/appearance.js',
}

lua54 'yes'
