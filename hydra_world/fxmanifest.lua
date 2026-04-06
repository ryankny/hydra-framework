fx_version 'cerulean'
game 'gta5'

name 'hydra_world'
description 'Hydra Framework - World Management'
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
    'config/world.lua',
    'server/main.lua',
}

client_scripts {
    'config/world.lua',
    'client/population.lua',
    'client/law.lua',
    'client/scenarios.lua',
    'client/environment.lua',
    'client/main.lua',
}
