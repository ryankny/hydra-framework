--[[
    Hydra AntiCheat
    Advanced server-authoritative anti-cheat with client-side monitoring.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_anticheat'
description 'Hydra Framework - Advanced Anti-Cheat System'
author 'Hydra Framework'
version '1.0.0'

dependencies {
    'hydra_core',
}

shared_scripts {
    'config/anticheat.lua',
}

server_scripts {
    'server/main.lua',
    'server/detections.lua',
    'server/events.lua',
}

client_scripts {
    'client/main.lua',
    'client/monitors.lua',
}

lua54 'yes'
