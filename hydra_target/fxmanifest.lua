--[[
    Hydra Target
    3D eye-targeting interaction system using raycasts.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_target'
description 'Hydra Framework - 3D Eye Targeting System'
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
    'config/target.lua',
}

client_scripts {
    'client/raycast.lua',
    'client/main.lua',
}
