--[[
    Hydra Progressbar
    Lightweight, performant progress bars for player actions.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_progressbar'
description 'Hydra Framework - Progress Bar System'
author 'Hydra Framework'
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

client_scripts {
    'client/main.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/css/progressbar.css',
    'nui/js/progressbar.js',
}
