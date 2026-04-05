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
    'config/target.lua',
}

client_scripts {
    'client/raycast.lua',
    'client/main.lua',
}
