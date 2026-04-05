fx_version 'cerulean'
game 'gta5'

name 'hydra_loadingscreen'
author 'Hydra Framework'
description 'Hydra Framework - Customisable Loading Screen'
version '1.0.0'

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
