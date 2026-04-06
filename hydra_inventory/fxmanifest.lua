--[[
    Hydra Inventory
    Full-featured inventory system with player, vehicle, stash,
    and world drop support. Drag-drop NUI with weight-based slots.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_inventory'
description 'Hydra Framework - Inventory System'
author 'Hydra Framework'
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
    'config/inventory.lua',
    'config/items.lua',
    'shared/utils.lua',
}

server_scripts {
    'server/main.lua',
    'server/drops.lua',
    'server/vehicles.lua',
    'server/stashes.lua',
}

client_scripts {
    'client/main.lua',
    'client/drops.lua',
    'client/vehicles.lua',
    'client/dumpsters.lua',
    'client/rob.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/css/inventory.css',
    'nui/js/inventory.js',
    'nui/img/*.png',
}

lua54 'yes'
