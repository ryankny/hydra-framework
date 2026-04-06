fx_version 'cerulean'
game 'gta5'

name 'hydra_physics'
description 'Hydra Framework - Hyper-Realistic Physics'
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
}

server_scripts {
    'config/physics.lua',
    'server/main.lua',
}

client_scripts {
    'config/physics.lua',
    'client/handling.lua',
    'client/dynamics.lua',
    'client/ragdoll.lua',
    'client/impact.lua',
    'client/main.lua',
}
