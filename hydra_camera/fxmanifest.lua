--[[
    Hydra Camera
    Centralized camera management system for the Hydra framework.
    Provides a single unified API for scripted cameras, orbit cameras,
    screen shake, cinematic bars, path interpolation, and transitions.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_camera'
description 'Hydra Framework - Centralized Camera Management System'
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
    'config/camera.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

lua54 'yes'
