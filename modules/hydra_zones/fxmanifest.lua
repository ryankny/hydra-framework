--[[
    Hydra Zones
    Polyzone / area management with enter/exit events.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_zones'
description 'Hydra Framework - Zone Management System'
author 'Hydra Framework'
version '1.0.0'

dependencies {
    'hydra_core',
}

shared_scripts {
    'config/zones.lua',
    'shared/math.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
