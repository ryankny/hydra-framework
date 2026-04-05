fx_version 'cerulean'
game 'gta5'

name 'hydra_audio'
author 'Hydra Framework'
description 'Hydra Framework - Centralized Audio Management System'
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
    'config/audio.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/js/audio.js',
}

client_exports {
    'PlayFrontend',
    'PlayAtCoord',
    'PlayOnEntity',
    'PlayCustom',
    'PlayBank',
    'Stop',
    'StopAll',
    'Pause',
    'Resume',
    'SetVolume',
    'Fade',
    'SetMasterVolume',
    'GetMasterVolume',
    'SetCategoryVolume',
    'GetCategoryVolume',
    'StartAmbient',
    'StopAmbient',
    'StopAllAmbient',
    'IsPlaying',
    'GetActiveCount',
    'RegisterBank',
    'OnPlay',
    'OnStop',
}

server_exports {
    'PlayClient',
    'PlayAll',
    'StopClient',
    'StopAllClients',
}

lua54 'yes'
