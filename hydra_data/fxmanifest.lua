fx_version 'cerulean'
game 'gta5'

name 'hydra_data'
author 'Hydra Framework'
description 'Hydra Framework - Data Management Layer'
version '1.0.0'

dependencies {
    'hydra_core',
    'oxmysql',
}

shared_scripts {
    '@hydra_core/shared/config.lua',
    '@hydra_core/shared/utils.lua',
    '@hydra_core/shared/events.lua',
    '@hydra_core/shared/module.lua',
    '@hydra_core/shared/api.lua',
    'shared/store.lua',
}

server_scripts {
    'server/adapters/mysql.lua',
    'server/cache.lua',
    'server/collections.lua',
    'server/query.lua',
    'server/subscriptions.lua',
    'server/main.lua',
}

client_scripts {
    'client/store.lua',
}

files {
    'config/default.lua',
}

exports {
    -- Client-side store access
    'GetStore',
    'GetStoreValue',
}

server_exports {
    -- CRUD operations
    'Create',
    'Read',
    'Update',
    'Delete',
    'Find',
    'FindOne',
    'Count',

    -- Batch operations
    'BulkCreate',
    'BulkUpdate',

    -- Cache
    'CacheGet',
    'CacheSet',
    'CacheInvalidate',

    -- Collections
    'CreateCollection',
    'CollectionExists',

    -- Subscriptions
    'Subscribe',
    'Unsubscribe',

    -- Store (stateful client sync)
    'SetPlayerStore',
    'GetPlayerStore',
}

lua54 'yes'
