fx_version 'cerulean'
game 'gta5'

name 'hydra_notify'
author 'Hydra Framework'
description 'Hydra Framework - Notification System'
version '1.0.0'

dependencies {
    'hydra_core',
    'hydra_ui',
}

shared_scripts {
    '@hydra_core/shared/config.lua',
    '@hydra_core/shared/utils.lua',
    '@hydra_core/shared/events.lua',
    '@hydra_core/shared/module.lua',
    '@hydra_core/shared/api.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/css/notify.css',
    'nui/js/notify.js',
}

server_exports {
    'Notify',
    'NotifyAll',
}

lua54 'yes'
