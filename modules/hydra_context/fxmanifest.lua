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

client_scripts {
    'client/main.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/css/context.css',
    'nui/js/context.js',
}
