fx_version 'cerulean'
game 'gta5'

name 'hydra_players'
author 'Hydra Framework'
description 'Hydra Framework - Player Management Module'
version '1.0.0'

dependencies {
    'hydra_core',
    'hydra_data',
    'hydra_bridge',
}

shared_scripts {
    '@hydra_core/shared/config.lua',
    '@hydra_core/shared/utils.lua',
    '@hydra_core/shared/events.lua',
    '@hydra_core/shared/module.lua',
    '@hydra_core/shared/api.lua',
    '@hydra_data/shared/store.lua',
}

server_scripts {
    'config/default.lua',
    'server/player.lua',
    'server/accounts.lua',
    'server/characters.lua',
    'server/jobs.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/spawn.lua',
}

server_exports {
    'GetPlayer',
    'GetAllPlayers',
    'GetAllPlayerIds',
    'GetPlayerByIdentifier',
    'AddMoney',
    'RemoveMoney',
    'SetMoney',
    'GetMoney',
    'SetJob',
    'GetJob',
    'SetGroup',
    'GetGroup',
    'SetMetadata',
    'GetMetadata',
    'SavePlayer',
    'SaveAllPlayers',
}

lua54 'yes'
