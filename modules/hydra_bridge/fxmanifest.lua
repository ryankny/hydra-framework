fx_version 'cerulean'
game 'gta5'

name 'hydra_bridge'
author 'Hydra Framework'
description 'Hydra Framework - Framework Bridge (ESX/QBCore/QBox/TMC Compatibility)'
version '1.0.0'

dependencies {
    'hydra_core',
    'hydra_data',
}

shared_scripts {
    '@hydra_core/shared/config.lua',
    '@hydra_core/shared/utils.lua',
    '@hydra_core/shared/events.lua',
    '@hydra_core/shared/module.lua',
    '@hydra_core/shared/api.lua',
    'shared/bridge.lua',
}

server_scripts {
    'server/main.lua',
    'server/detector.lua',
    'bridges/esx/server.lua',
    'bridges/qbcore/server.lua',
    'bridges/qbox/server.lua',
    'bridges/tmc/server.lua',
}

client_scripts {
    'client/main.lua',
    'bridges/esx/client.lua',
    'bridges/qbcore/client.lua',
    'bridges/qbox/client.lua',
    'bridges/tmc/client.lua',
}

server_exports {
    'GetBridgeMode',
    'IsBridgeActive',
}

lua54 'yes'
