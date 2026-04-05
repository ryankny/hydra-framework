# hydra_zones

Zone management system supporting sphere, box, and polygon zones with enter/exit events. Zones can be created client-side or synced from the server.

## Dependencies
- `hydra_core`

## API

### Zone Creation
- `Hydra.Zones.Add(data)` -- Generic zone registration. Returns zone ID.
- `Hydra.Zones.AddSphere(center, radius, data)` -- Sphere zone shorthand.
- `Hydra.Zones.AddBox(min, max, data)` -- Box zone shorthand.
- `Hydra.Zones.AddPoly(points, minZ, maxZ, data)` -- Polygon zone shorthand.

### Zone Management
- `Hydra.Zones.Remove(id)`
- `Hydra.Zones.IsInZone(id)` -- Check if player is inside a specific zone.
- `Hydra.Zones.GetCurrentZones()` -- Get all zones the player is currently inside.

### Global Handlers
- `Hydra.Zones.OnEnter(handler)` / `Hydra.Zones.OnExit(handler)` -- Global enter/exit listeners.

Per-zone callbacks can be passed via `data.onEnter` and `data.onExit`.

## Exports
- `AddZone`, `AddSphere`, `AddBox`, `AddPoly`, `RemoveZone`
- `IsInZone`, `GetCurrentZones`
- `OnZoneEnter`, `OnZoneExit`

## Events
- `hydra:zones:enter` / `hydra:zones:exit` -- Fired with `(zoneId, zoneName, metadata)`.
- `hydra:zones:register` / `hydra:zones:remove` -- Server-synced zone lifecycle.

## Configuration
- `config/zones.lua` -- `tick_rate`, `debug` draw toggle.
