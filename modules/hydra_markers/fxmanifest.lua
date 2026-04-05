--[[
    Hydra Markers
    Centralized 3D marker, checkpoint, and floating text system.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_markers'
description 'Hydra Framework - 3D Markers, Checkpoints & Floating Text'
author 'Hydra Framework'
version '1.0.0'

dependencies {
    'hydra_core',
}

shared_scripts {
    'config/markers.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
