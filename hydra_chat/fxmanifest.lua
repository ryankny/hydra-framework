--[[
    Hydra Chat
    Custom chat system with commands, channels, and formatting.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_chat'
description 'Hydra Framework - Custom Chat System'
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
    'config/chat.lua',
}

server_scripts {
    'server/main.lua',
    'server/commands.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/css/chat.css',
    'nui/js/chat.js',
}
