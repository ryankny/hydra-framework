fx_version 'cerulean'
game 'gta5'

name 'hydra_commands'
description 'Hydra Framework - Centralized Command System'
author 'Hydra Framework'
version '1.0.0'

dependencies { 'hydra_core' }

shared_scripts { 'config/commands.lua' }
client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }

lua54 'yes'
