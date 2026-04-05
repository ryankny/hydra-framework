--[[
    Hydra Input
    Modal input dialogs, confirmations, and multi-field forms.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_input'
description 'Hydra Framework - Input Dialog System'
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
    'nui/css/input.css',
    'nui/js/input.js',
}
