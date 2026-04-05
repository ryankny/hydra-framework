fx_version 'cerulean'
game 'gta5'

name 'hydra_keybinds'
description 'Hydra Framework - Centralized Keybind Management System'
author 'Hydra Framework'
version '1.0.0'

dependencies { 'hydra_core' }

shared_scripts { 'config/keybinds.lua' }
client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }

lua54 'yes'
