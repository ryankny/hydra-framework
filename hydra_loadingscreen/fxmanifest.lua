fx_version 'cerulean'
game 'gta5'

name 'hydra_loadingscreen'
author 'Hydra Framework'
description 'Hydra Framework - Customisable Loading Screen'
version '1.0.0'

shared_scripts {
    '@hydra_core/shared/config.lua',
    '@hydra_core/shared/utils.lua',
    '@hydra_core/shared/events.lua',
    '@hydra_core/shared/module.lua',
    '@hydra_core/shared/api.lua',
}

loadscreen 'nui/index.html'
loadscreen_manual_shutdown 'yes'
loadscreen_cursor 'yes'

files {
    'nui/index.html',
    'nui/css/loading.css',
    'nui/js/loading.js',
    'nui/js/config.js',
    'nui/assets/logo.svg',
    'config/loadingscreen.js',
}

client_scripts {
    'client/main.lua',
}

lua54 'yes'
