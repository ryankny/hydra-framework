--[[
    Hydra Scenes
    Scripted sequence and cutscene engine for the Hydra framework.
    Orchestrates camera, animation, audio, NPCs, objects, and markers
    into timed, skippable sequences for cutscenes, tutorials, job intros,
    mission briefings, and more.
]]

fx_version 'cerulean'
game 'gta5'

name 'hydra_scenes'
description 'Hydra Framework - Scripted Sequence & Cutscene Engine'
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
    'config/scenes.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

lua54 'yes'
