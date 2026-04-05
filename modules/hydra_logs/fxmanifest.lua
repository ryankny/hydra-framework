--[[
    Hydra Logs
    Comprehensive logging with Discord webhook integration.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_logs'
description 'Hydra Framework - Logging & Discord Webhook System'
author 'Hydra Framework'
version '1.0.0'

dependencies {
    'hydra_core',
}

server_scripts {
    'config/logs.lua',
    'server/webhooks.lua',
    'server/main.lua',
}
