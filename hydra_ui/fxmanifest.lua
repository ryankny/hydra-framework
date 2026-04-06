fx_version 'cerulean'
game 'gta5'

name 'hydra_ui'
author 'Hydra Framework'
description 'Hydra Framework - Core UI Engine'
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
    'shared/theme.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/bridge.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/css/hydra.css',
    'nui/css/animations.css',
    'nui/js/core.js',
    'nui/js/components.js',
    'nui/js/animations.js',
}

lua54 'yes'
