--[[
    Hydra Emotes
    Animation and emote system with props and shared emotes.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_emotes'
description 'Hydra Framework - Animation & Emote System'
author 'Hydra Framework'
version '1.0.0'

dependencies {
    'hydra_core',
}

shared_scripts {
    'config/emotes.lua',
}

client_scripts {
    'client/main.lua',
}
