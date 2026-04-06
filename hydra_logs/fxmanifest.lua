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

shared_scripts {
    '@hydra_core/shared/config.lua',
    '@hydra_core/shared/utils.lua',
    '@hydra_core/shared/events.lua',
    '@hydra_core/shared/module.lua',
    '@hydra_core/shared/api.lua',
}

server_scripts {
    'config/logs.lua',
    'server/webhooks.lua',
    'server/main.lua',
}
