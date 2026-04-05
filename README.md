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
2. Copy `hydra_core` and the `modules/` folder into your resources
3. Import `sql/hydra_install.sql` into your database (optional - tables auto-create)
4. Add to your `server.cfg`:

```cfg
ensure oxmysql
ensure hydra_core
ensure hydra_data
ensure hydra_bridge
ensure hydra_players
ensure hydra_identity
ensure hydra_commands
ensure hydra_keybinds
# ... ensure any other modules you need
```

5. Start your server. That's it.

## Architecture

```
hydra_core/                    Core engine (root level)
modules/
  hydra_data/                  Database & data layer
  hydra_bridge/                ESX/QBCore/QBox/TMC compatibility
  hydra_players/               Player management & accounts
  hydra_identity/              Character creation & selection
  ...                          All other modules
```

## Module List

### Core Infrastructure
| Module | Description |
|--------|-------------|
| `hydra_core` | Core engine - config, modules, security, events, callbacks, utilities |
| `hydra_data` | Data layer - MySQL abstraction, caching, collections, subscriptions |
| `hydra_bridge` | Framework bridge - ESX, QBCore, QBox, TMC compatibility adapters |
| `hydra_players` | Player management - accounts, jobs, characters, spawning |
| `hydra_identity` | Character creation, selection, and appearance management |
| `hydra_commands` | Centralized command system - permissions, args, help, typo suggestions |
| `hydra_keybinds` | Centralized keybind manager - conflict detection, profiles, enable/disable |
| `hydra_logs` | Server-side logging and audit trail |

### UI & Interaction
| Module | Description |
|--------|-------------|
| `hydra_ui` | Central NUI framework and UI management |
| `hydra_hud` | Player HUD, vehicle HUD, compass, navigation |
| `hydra_input` | Modal input dialogs, forms, confirmations |
| `hydra_context` | Context menus (list and radial) with submenus |
| `hydra_target` | 3D eye-targeting system with entity/model/coord targets |
| `hydra_zones` | Polyzone system (sphere, box, polygon) with enter/exit |
| `hydra_interact` | Unified interaction layer over target/zones/context |
| `hydra_notify` | Toast notification system |
| `hydra_progressbar` | Progress bars with animation and prop support |
| `hydra_chat` | Chat system with channels, commands, moderation |
| `hydra_markers` | 3D markers, floating text, checkpoints |

### Media & Presentation
| Module | Description |
|--------|-------------|
| `hydra_anims` | Centralized animation engine - dict caching, props, queuing, hooks |
| `hydra_audio` | Audio system - native sounds, custom NUI audio, spatial, ambient zones |
| `hydra_camera` | Camera system - orbit, paths, shake, cinematic bars, transitions |
| `hydra_scenes` | Scripted sequence engine - cutscenes, tutorials, timed orchestration |

### World & Physics
| Module | Description |
|--------|-------------|
| `hydra_world` | World management - population, law enforcement, scenarios, environment |
| `hydra_weather` | Weather and time cycle control with sync |
| `hydra_physics` | Hyper-realistic vehicle handling, ragdoll, rollover, aquaplaning, bogging |
| `hydra_object` | Prop/object spawning with lifecycle tracking, cleanup, and anti-orphan |
| `hydra_npc` | NPC spawning, behavior, dialogue, patrol routes, proximity management |
| `hydra_blips` | Blip management system |

### Gameplay Systems
| Module | Description |
|--------|-------------|
| `hydra_status` | Player status effects (hunger, thirst, stress, etc.) |
| `hydra_death` | Death, last-stand, respawn, and revive system |
| `hydra_emotes` | Animation/emote system with props and scenarios |
| `hydra_doorlock` | Door lock system with multiple lock types |
| `hydra_loadingscreen` | Custom loading screen |

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

### Using Commands

```lua
-- Register via hydra_commands (server-side)
exports['hydra_commands']:Register('mycommand', function(src, args, raw)
    -- args is parsed: { playerid = 5, amount = 100 }
    print('Player ' .. src .. ' used /mycommand')
end, {
    description = 'My custom command',
    category = 'general',
    permission = 'mymod.use',
    args = {
        { name = 'playerid', type = 'playerId', required = true, help = 'Target player' },
        { name = 'amount', type = 'number', required = true, help = 'Amount' },
    },
})
```

### Using Keybinds

```lua
-- Register via hydra_keybinds (client-side)
exports['hydra_keybinds']:Register('my_action', {
    key = 'G',
    description = 'Do Something',
    category = 'interaction',
    module = 'my_resource',
    onPress = function()
        print('Key pressed!')
    end,
    onRelease = function()
        print('Key released!')
    end,
    isHold = true,
})
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
})

-- CRUD operations
local id = Hydra.Data.Create('vehicles', { owner = identifier, plate = 'HYD 001', model = 'adder' })
local car = Hydra.Data.FindOne('vehicles', { plate = 'HYD 001' })
Hydra.Data.Update('vehicles', { id = car.id }, { fuel = 50 })
Hydra.Data.Delete('vehicles', { id = car.id })
```

### Using NPCs

```lua
-- Client-side NPC with interactions
local npcId = exports['hydra_npc']:Create({
    model = 'a_m_m_business_01',
    coords = vector4(-549.16, -189.80, 38.22, 207.39),
    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    invincible = true,
    frozen = true,
    interactions = {
        { label = 'Talk', icon = 'fas fa-comment', onSelect = function(id, entity)
            print('Player talked to NPC')
        end },
    },
})
```

### Using Scenes

```lua
-- Register a cutscene
exports['hydra_scenes']:Register('intro', {
    allowSkip = true,
    showBars = true,
    hideHud = true,
    steps = {
        { at = 0, camera = { position = vec3(100, 200, 50), target = vec3(100, 200, 40), fov = 40, transition = 1000 } },
        { at = 0, subtitle = { text = 'Welcome to the city...', duration = 3000 } },
        { at = 3000, camera = { position = vec3(110, 200, 45), fov = 50, transition = 2000 } },
        { at = 3000, subtitle = { text = 'Your journey begins here.', duration = 3000 } },
        { at = 6000, effect = { fadeOut = 1000 } },
    },
})

-- Play it
exports['hydra_scenes']:Play('intro')
```

### Bridge Compatibility

Existing ESX/QBCore scripts work automatically:

```lua
-- ESX patterns work under Hydra:
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
local xPlayer = ESX.GetPlayerFromId(source)
xPlayer.addMoney(500)

-- QBCore patterns work under Hydra:
local QBCore = exports['qb-core']:GetCoreObject()
local Player = QBCore.Functions.GetPlayer(source)
Player.Functions.AddMoney('cash', 500)
```

## Configuration

### Via Config Files
Edit `hydra_core/config/default.lua` for global settings. Each module has its own config in `modules/<module>/config/`.

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

## Module System

Create your own Hydra module:

```lua
Hydra.Modules.Register('my_module', {
    label = 'My Module',
    version = '1.0.0',
    dependencies = { 'hydra_core' },
    priority = 50,

    onLoad = function()
        -- Initialize
    end,

    onReady = function()
        -- Framework fully ready
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

Access from other scripts:
```lua
local myMod = Hydra.Use('my_module')
myMod.MyFunction()
```

## License

All rights reserved.
