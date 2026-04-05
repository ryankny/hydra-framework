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
