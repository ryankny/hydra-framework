--[[
    Hydra Death
    Death, last stand, respawn, and hospital mechanics.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_death'
description 'Hydra Framework - Death & Respawn System'
author 'Hydra Framework'
version '1.0.0'

dependencies {
    'hydra_core',
    'hydra_players',
}

shared_scripts {
    'config/death.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
