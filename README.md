# Hydra Framework

A high-performance, security-first FiveM framework built for speed, modularity, and developer experience.

## Features

- **Blazing Fast** - Optimized hot paths, LRU caching, minimal tick usage, lazy module loading
- **Security First** - Event token validation, rate limiting, payload size checks, exploit protection, input sanitization
- **Modular Architecture** - Everything is a module. Add, remove, hot-reload without touching core
- **Built-in Data Layer** - Kuzzle-inspired data management with collections, caching, real-time subscriptions
- **Framework Bridge** - Drop-in compatibility with ESX, QBCore, QBox, and TMC scripts
- **Plug & Play** - Works out of the box with MySQL. Zero config needed for basic setup
- **Developer Friendly** - Clean API, dot-notation config, callback system, reactive stores

## Quick Start

1. Install [oxmysql](https://github.com/overextended/oxmysql)
2. Copy `hydra_core`, `hydra_data`, `hydra_bridge`, and `hydra_players` into your resources folder
3. Import `sql/hydra_install.sql` into your database (optional - tables auto-create)
4. Add to your `server.cfg`:

```cfg
ensure oxmysql
ensure hydra_core
ensure hydra_data
ensure hydra_bridge
ensure hydra_players
```

5. Start your server. That's it.

## Architecture

```
hydra_core/       Core engine - config, modules, security, events, callbacks
hydra_data/       Data layer - DB abstraction, cache, collections, subscriptions
hydra_bridge/     Compatibility - ESX/QBCore/QBox/TMC bridge adapters
hydra_players/    Player module - accounts, jobs, characters, spawning
```

## Writing Hydra Scripts

### Native Hydra Script

```lua
-- fxmanifest.lua
fx_version 'cerulean'
game 'gta5'
dependencies { 'hydra_core' }
server_scripts { 'server/main.lua' }

-- server/main.lua
Hydra.OnReady(function()
    local Players = Hydra.Use('players')

    Hydra.Callbacks.Register('myScript:getData', function(source, cb)
        local player = Players.GetPlayer(source)
        cb(player.accounts, player.job)
    end)

    Hydra.Events.Register('myScript:doSomething', function(source, data)
        Players.AddMoney(source, 'cash', 500)
    end)
end)
```

### Using the Data Layer

```lua
-- Create a collection (auto-creates DB table)
Hydra.Data.Collections.Create('vehicles', {
    { name = 'owner',     type = 'VARCHAR(64)' },
    { name = 'plate',     type = 'VARCHAR(8)', nullable = false },
    { name = 'model',     type = 'VARCHAR(64)' },
    { name = 'garage',    type = 'VARCHAR(32)', default = 'default' },
    { name = 'fuel',      type = 'INT', default = 100 },
    { name = 'body',      type = 'FLOAT', default = 1000.0 },
    { name = 'properties', type = 'LONGTEXT', default = '{}' },
})

-- CRUD operations
local id = Hydra.Data.Create('vehicles', { owner = identifier, plate = 'HYD 001', model = 'adder' })
local car = Hydra.Data.FindOne('vehicles', { plate = 'HYD 001' })
local cars = Hydra.Data.Find('vehicles', { owner = identifier }, { sort = { id = 'DESC' }, limit = 10 })
Hydra.Data.Update('vehicles', { id = car.id }, { fuel = 50, garage = 'legion' })
Hydra.Data.Delete('vehicles', { id = car.id })

-- Subscribe to changes
Hydra.Data.Subscriptions.Subscribe('vehicles', { owner = identifier }, function(action, payload)
    print('Vehicle ' .. action .. ':', json.encode(payload))
end)
```

### Bridge Compatibility

Existing ESX/QBCore scripts work automatically. The bridge detects your legacy framework and creates compatibility objects:

```lua
-- These ESX patterns work under Hydra:
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
local xPlayer = ESX.GetPlayerFromId(source)
xPlayer.addMoney(500)

-- These QBCore patterns work under Hydra:
local QBCore = exports['qb-core']:GetCoreObject()
local Player = QBCore.Functions.GetPlayer(source)
Player.Functions.AddMoney('cash', 500)
```

## Configuration

### Via Config Files
Edit `hydra_core/config/default.lua` for global settings, or module-specific configs.

### Via server.cfg Convars
```cfg
set hydra_locale "en"
set hydra_debug "true"
set hydra_log_level "debug"
set hydra_rate_limit "50"
set hydra_bridge_mode "native"
```

### Programmatic
```lua
Hydra.Config.Set('debug.log_level', 'debug')
local rateLimit = Hydra.Config.Get('security.rate_limit', 50)
```

## Admin Commands

| Command | Description |
|---------|-------------|
| `/hydra info` | Show framework version and loaded modules |
| `/hydra modules` | List all modules and their states |
| `/hydra maintenance on/off` | Toggle maintenance mode |
| `/hydra debug <level>` | Set log level (error/warn/info/debug/trace) |
| `/hydra reload <module>` | Hot-reload a module |

## Module System

Create your own Hydra module:

```lua
Hydra.RegisterModule('my_module', {
    label = 'My Module',
    version = '1.0.0',
    dependencies = { 'players' },
    priority = 50,

    onLoad = function()
        -- Initialize your module
    end,

    onReady = function()
        -- Framework is fully ready
    end,

    onPlayerJoin = function(source)
        -- Player connected
    end,

    onPlayerDrop = function(source, reason)
        -- Player disconnected
    end,

    api = {
        MyFunction = function() return 'hello' end,
    },
})
```

Other scripts can then use your module:
```lua
local myMod = Hydra.Use('my_module')
myMod.MyFunction()
```

## License

All rights reserved.
