# hydra_doorlock

Advanced door lock system with multiple lock types (key, keypad, job, item), 3D indicators, native door state control, database persistence, and admin configuration.

## Dependencies
- `hydra_core`
- `hydra_data`
- `hydra_players`

## API

### Client
- `Hydra.Doorlock.GetNearestDoor()` -- Returns `doorId, doorData, distance`.
- Interaction via `hydra_target` (auto-registered) or keybind fallback.

### Server
- `Hydra.Doorlock.GetAll()` -- Get all door definitions.
- `Hydra.Doorlock.SetLocked(id, locked, src)` -- Lock or unlock a door.
- `Hydra.Doorlock.Toggle(id, src)` -- Toggle lock state.
- `Hydra.Doorlock.CanAccess(src, id)` -- Check if a player can access a door.

## Exports

**Client:** `GetNearestDoor`, `IsLocked(id)`, `GetDoors`

**Server:** `GetDoor(id)`, `IsLocked(id)`, `SetLocked`, `ToggleDoor`, `CanAccess`

## Keybinds
- `E` -- Interact with nearest door (fallback when no target system).

## Events
- `hydra:doorlock:fullSync` / `hydra:doorlock:stateUpdate` -- State synchronization.
- `hydra:doorlock:doorAdded` / `hydra:doorlock:doorRemoved`
- `hydra:doorlock:denied` -- Access denied feedback.

## Configuration
- `config/doorlock.lua` -- `interact_distance`, `indicator_distance`, `draw_indicators`, `action_cooldown`, `sounds`, door definitions.
