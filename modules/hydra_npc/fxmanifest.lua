--[[
    Hydra NPC
    Centralized NPC spawning, management, and behavior system.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_npc'
description 'Hydra Framework - NPC Spawning & Management'
author 'Hydra Framework'
version '1.0.0'

dependencies {
    'hydra_core',
}

shared_scripts {
    'config/npc.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}
