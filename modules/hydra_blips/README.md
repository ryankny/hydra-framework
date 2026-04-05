# hydra_blips

Managed blip system with categories, server sync, client-only blips, category toggling, and auto-cleanup on resource stop.

## Dependencies
- `hydra_core`

## API

### Client
- `Hydra.Blips.CreateLocal(data)` -- Create a client-only blip. Returns `blipId`.
- `Hydra.Blips.RemoveLocal(id)` -- Remove a blip by ID.
- `Hydra.Blips.SetCategoryVisible(category, visible)` -- Toggle visibility for an entire category.
- `Hydra.Blips.IsCategoryVisible(category)`

### Server
- `Hydra.Blips.Create(data)` -- Create a synced blip (sent to all clients). `data` includes `coords`, `sprite`, `color`, `scale`, `label`, `category`, `short_range`.
- `Hydra.Blips.Update(id, data)` / `Remove(id)`
- `Hydra.Blips.RemoveByResource(resourceName)` / `RemoveByCategory(category)`
- `Hydra.Blips.GetAll()`

## Exports

**Client:** `CreateLocalBlip`, `RemoveLocalBlip`, `SetCategoryVisible`, `IsCategoryVisible`

**Server:** `CreateBlip`, `UpdateBlip`, `RemoveBlip`, `RemoveBlipsByResource`, `RemoveBlipsByCategory`

## Events
- `hydra:blips:create` / `hydra:blips:update` / `hydra:blips:remove` -- Server to client sync.

## Configuration
- `config/blips.lua` -- `defaults` (sprite, color, scale, display), `categories` with visibility toggles.
