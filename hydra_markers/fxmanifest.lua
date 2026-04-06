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
    '@hydra_core/shared/config.lua',
    '@hydra_core/shared/utils.lua',
    '@hydra_core/shared/events.lua',
    '@hydra_core/shared/module.lua',
    '@hydra_core/shared/api.lua',
    'config/markers.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
