fx_version 'cerulean'
game 'gta5'

name 'hydra_core'
author 'Hydra Framework'
description 'Hydra Framework - Core Engine'
version '1.0.0'

-- Shared libraries (loaded first, available to all Hydra resources)
shared_scripts {
    'shared/config.lua',
    'shared/utils.lua',
    'shared/events.lua',
    'shared/module.lua',
    'shared/api.lua',
}

server_scripts {
    'server/main.lua',
    'server/security.lua',
    'server/modules.lua',
    'server/config_manager.lua',
    'server/commands.lua',
    'server/callbacks.lua',
}

client_scripts {
    'client/main.lua',
    'client/callbacks.lua',
    'client/nui.lua',
}

-- Export the Hydra API globally
exports {
    -- Core
    'GetVersion',
    'IsReady',

    -- Modules
    'GetModule',
    'IsModuleLoaded',

    -- Config
    'GetConfig',
    'SetConfig',

    -- Security
    'ValidateSource',

    -- Callbacks
    'TriggerCallback',
    'RegisterCallback',
}

server_exports {
    -- Server-only exports
    'GetPlayerData',
    'GetAllPlayers',
    'RegisterModule',
    'UnregisterModule',
    'GetModules',
    'EmitSecure',
    'RegisterCallback',
    'TriggerCallback',
}

-- Ensure hydra_core starts before all other hydra resources
dependency 'oxmysql'

-- Load default config
files {
    'config/default.lua',
    'config/permissions.lua',
}

lua54 'yes'
