fx_version 'cerulean'
game 'gta5'

name 'hydra_updater'
author 'Hydra Framework'
description 'Hydra Framework - Auto-Updater'
version '1.0.0'

server_scripts {
    'server/updater.lua',
}

files {
    'config/config.lua',
}

dependency 'hydra_core'

lua54 'yes'
