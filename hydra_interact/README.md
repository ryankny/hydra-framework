# hydra_interact

Unified interaction layer that orchestrates `hydra_target`, `hydra_zones`, and `hydra_context` into a single API. Provides interaction points, entity interactions, model interactions, zone interactions, and proximity prompts.

## Dependencies
- `hydra_core`

## API

### Adding Interactions
- `Hydra.Interact.AddPoint(options)` -- Add an interaction at world coordinates.
- `Hydra.Interact.AddEntity(entity, options)` / `AddModel(model, options)`
- `Hydra.Interact.AddNetEntity(netId, options)` / `AddLocalEntity(entity, options)`
- `Hydra.Interact.AddZone(zoneType, zoneData, options)` -- Sphere, box, or poly zone.

### Options
`label`, `icon`, `distance`, `groups` (job filter), `canInteract(data)`, `onSelect(data)`, `event`, `serverEvent`, `tag`, `metadata`, `options` (array for multi-option context menu).

### Management
- `Remove(id)` / `RemoveByTag(tag)` / `SetEnabled(id, bool)`
- `Exists(id)` / `GetAll()` / `GetNearby()` / `Refresh()`

### Hooks
- `Hydra.Interact.OnBefore(fn)` / `OnAfter(fn)` -- Pre/post interaction hooks.

## Exports
- `AddPoint`, `AddEntity`, `AddModel`, `AddNetEntity`, `AddLocalEntity`, `AddZone`
- `Remove`, `RemoveByTag`, `SetEnabled`, `Exists`, `GetAll`, `GetNearby`, `Refresh`
- `OnBefore`, `OnAfter`

## Events
- `hydra:interact:trigger` -- Server triggers an interaction on the client.

## Configuration
- `config/interact.lua` -- `enabled`, `use_target`, `use_zones`, `default_distance`, `max_distance`, `cooldown`, `max_active_points`, `show_prompts`, `tick_rate`.
