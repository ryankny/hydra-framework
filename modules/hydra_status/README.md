# hydra_status

Player needs system covering hunger, thirst, stress, and custom statuses. Server-authoritative with client-side effects (health drain, screen effects) and HUD integration.

## Dependencies
- `hydra_core`
- `hydra_players`

## API

### Client
- `Hydra.Status.Get(name)` -- Get a cached status value.
- `Hydra.Status.GetAll()` -- Get all cached statuses.

### Server
- `Hydra.Status.Init(src)` -- Initialize statuses for a player.
- `Hydra.Status.Get(src, name)` / `GetAll(src)`
- `Hydra.Status.Set(src, name, value)` / `Add(src, name, amount)`
- `Hydra.Status.Sync(src, immediate)` -- Push statuses to client.
- `Hydra.Status.Save(src)` / `Cleanup(src)`

## Exports

**Client:** `GetStatus(name)`, `GetAllStatuses()`

**Server:** `GetStatus`, `GetAllStatuses`, `SetStatus`, `AddStatus`

## Events
- `hydra:status:sync` -- Server pushes status values to client.
- `hydra:status:effect` -- Server triggers gameplay effects (e.g. health drain).
- `hydra:status:clientAdd` -- Client reports stress triggers (shooting, speeding) to server.

## Configuration
- `config/status.lua` -- Status definitions (hunger, thirst, stress), decay rates, effect thresholds, stress triggers (`shooting`, `speeding`, `speed_threshold`).
