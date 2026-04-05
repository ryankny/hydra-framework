--[[
    Hydra Object
    Centralized prop/object spawning, tracking, and cleanup.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_object'
description 'Hydra Framework - Object & Prop Management'
author 'Hydra Framework'
version '1.0.0'

dependencies {
    'hydra_core',
}

shared_scripts {
    'config/object.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}
