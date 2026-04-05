--[[
    Hydra Interact
    Unified interaction layer orchestrating target, zones, and context systems.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_interact'
description 'Hydra Framework - Unified Interaction System'
author 'Hydra Framework'
version '1.0.0'

dependencies {
    'hydra_core',
}

shared_scripts {
    'config/interact.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}
