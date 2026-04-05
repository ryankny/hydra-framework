--[[
    Hydra Anims
    Centralized animation management system with dict caching,
    prop management, queuing, hooks, and scenario support.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_anims'
description 'Centralized animation management system'
author 'Hydra Framework'
version '1.0.0'

dependencies {
    'hydra_core',
}

shared_scripts {
    'config/anims.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}
