--[[
    Hydra AntiCheat
    Advanced server-authoritative anti-cheat with client-side monitoring.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_anticheat'
description 'Hydra Framework - Advanced Anti-Cheat System'
author 'Hydra Framework'
version '2.0.0'

dependencies {
    'hydra_core',
}

shared_scripts {
    '@hydra_core/shared/config.lua',
    '@hydra_core/shared/utils.lua',
    '@hydra_core/shared/events.lua',
    '@hydra_core/shared/module.lua',
    '@hydra_core/shared/api.lua',
    'config/anticheat.lua',
}

server_scripts {
    'server/main.lua',
    'server/detections.lua',
    'server/events.lua',
    'server/combat.lua',
    'server/vehicles.lua',
    'server/network.lua',
}

client_scripts {
    'client/main.lua',
    'client/monitors.lua',
    'client/combat.lua',
    'client/vehicles.lua',
    'client/menu_detection.lua',
}

lua54 'yes'
