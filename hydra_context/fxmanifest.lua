--[[
    Hydra Context
    Radial and list-based context menus for player interaction.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_context'
description 'Hydra Framework - Context Menu System'
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
    'nui/css/context.css',
    'nui/js/context.js',
}
