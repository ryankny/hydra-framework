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

client_scripts {
    'client/main.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/css/progressbar.css',
    'nui/js/progressbar.js',
}
