--[[
    Hydra Blips
    Managed blip system with categories and auto-cleanup.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_blips'
description 'Hydra Framework - Blip Management System'
author 'Hydra Framework'
version '1.0.0'

dependencies {
    'hydra_core',
}

shared_scripts {
    'config/blips.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
