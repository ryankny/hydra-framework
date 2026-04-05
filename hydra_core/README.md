# hydra_core

Core engine for the Hydra Framework. Provides the boot sequence, configuration management, secure event system, callback system, module loader, and security layer that all other modules depend on.

## Dependencies
- `oxmysql`

## API

### Hydra.IsReady()
Returns `true` when the framework has completed initialization.

### Hydra.GetVersion()
Returns the framework version string.

### Hydra.OnReady(cb)
Registers a callback that fires once the framework is ready.

### Hydra.Use(moduleName)
Shorthand to get a module's API table.

### Hydra.RegisterModule(name, definition)
Register a module with the framework.

### Hydra.Events.Register(eventName, handler, opts)
Register a secure event handler with optional rate limiting.

### Hydra.Events.Emit / EmitServer / EmitClient
Trigger events locally, to server, or to a specific client.

### Hydra.Config.Get(key, default) / Hydra.Config.Set(key, value)
Read and write framework configuration values.

## Exports

**Shared (client + server):**
- `GetVersion`, `IsReady`
- `GetModule`, `IsModuleLoaded`
- `GetConfig`, `SetConfig`
- `ValidateSource`
- `TriggerCallback`, `RegisterCallback`

**Server-only:**
- `GetPlayerData`, `GetAllPlayers`, `GetPlayers`
- `RegisterModule`, `UnregisterModule`, `GetModules`
- `EmitSecure`
- `RegisterCallback`, `TriggerCallback`

## Events
- `hydra:playerLoaded` -- Client tells server it has finished loading.
- `hydra:receiveConfig` -- Server sends config to client.

## Configuration
- `config/default.lua` -- All default settings (server, security, performance, debug, database).
- `config/permissions.lua` -- ACE permission definitions.

Key options: `server.maintenance_mode`, `security.event_tokens`, `security.rate_limit`, `performance.tick_rate`, `debug.enabled`, `debug.log_level`.
