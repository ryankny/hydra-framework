# hydra_target

3D eye-targeting interaction system using raycasts. Hold a key to enter target mode, look at entities/coordinates to see interaction options. Uses `hydra_context` for the option menu when available.

## Dependencies
- `hydra_core`

## API

### Registration
- `Hydra.Target.AddEntity(entity, options)` -- Target a specific entity.
- `Hydra.Target.AddModel(model, options)` -- Target all entities matching a model hash.
- `Hydra.Target.AddBone(model, bone, options)` -- Target a specific bone on a model.
- `Hydra.Target.AddGlobalPed(options)` / `AddGlobalVehicle(options)` / `AddGlobalObject(options)` -- Target all entities of a type.
- `Hydra.Target.AddCoord(coords, radius, options)` -- Target a coordinate sphere.

### Removal
- `RemoveEntity(id)`, `RemoveModel(id)`, `RemoveGlobal(id)`, `RemoveCoord(id)`

### Option fields
Each option: `label`, `icon`, `event`, `serverEvent`, `args`, `onSelect`, `canInteract(entity, coords, args)`, `job`, `distance`.

## Exports
- `AddEntity`, `RemoveEntity`, `AddModel`, `RemoveModel`, `AddBone`
- `AddGlobalPed`, `AddGlobalVehicle`, `AddGlobalObject`, `RemoveGlobal`
- `AddCoord`, `RemoveCoord`
- `IsActive`, `Enable`, `Disable`

## Keybinds
- Hold key (configurable) to enter targeting mode. Default set in `config/target.lua`.

## Configuration
- `config/target.lua` -- `key`, `max_distance`, `tick_rate`, `highlight` settings, `draw_sprite`.
