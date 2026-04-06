fx_version 'cerulean'
game 'gta5'

name 'hydra_commands'
description 'Hydra Framework - Centralized Command System'
author 'Hydra Framework'
version '1.0.0'

dependencies { 'hydra_core' }

shared_scripts {
    '@hydra_core/shared/config.lua',
    '@hydra_core/shared/utils.lua',
    '@hydra_core/shared/events.lua',
    '@hydra_core/shared/module.lua',
    '@hydra_core/shared/api.lua',
    'config/commands.lua',
}
client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }

lua54 'yes'
