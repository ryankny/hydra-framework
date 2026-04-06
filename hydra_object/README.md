# hydra_object

Centralized object/prop management with spawning, attachment, tracking, and automatic cleanup. Every spawned object is tracked by owner, tag, and creation time. Prevents orphaned entities.

## Dependencies
- `hydra_core`

## API

### Spawning
- `Create(options)` -- Spawn an object. Options: `model`, `coords`, `rotation`, `heading`, `freeze`, `collision`, `network`, `invincible`, `alpha`, `visible`, `snapToGround`, `owner`, `tag`, `metadata`, `onDelete`. Returns `objId, entity`.
- `CreateAttached(targetEntity, options)` -- Spawn and attach in one call.

### Attachment
- `Attach(objId, targetEntity, options)` -- Options: `bone`, `offset`, `rotation`.
- `Detach(objId, options)` -- Options: `freeze`, `coords`.

### Removal
- `Remove(objId)` / `RemoveByOwner(owner)` / `RemoveByTag(tag)` / `RemoveAll()`

### Query
- `Get(objId)` / `GetEntity(objId)` / `Exists(objId)`
- `GetAll()` / `GetByOwner(owner)` / `GetByTag(tag)` / `GetCount(owner)`
- `GetNearby(coords, radius)` -- Returns sorted array of `{id, entity, distance}`.

### Modify
- `SetCoords`, `SetRotation`, `SetHeading`, `Freeze`, `SetVisible`, `SetAlpha`, `SetCollision`, `SetInvincible`, `SetMetadata`, `GetMetadata`

### Utilities
- `GetGroundCoords(coords)` / `Preload(models)`

### Hooks
- `OnPreCreate(fn)` / `OnPostCreate(fn)` / `OnDelete(fn)`

## Exports
All API functions listed above are available as exports.

## Events
- `hydra:object:create` / `hydra:object:removeByTag` / `hydra:object:removeAll` -- Server-triggered.

## Configuration
- `config/object.lua` -- `max_objects`, `max_per_owner`, `model_cache_size`, `model_timeout`, `default_freeze`, `default_collision`, `default_network`, `default_lod_distance`, `orphan_timeout`, `cleanup_interval`, `validate_interval`, `ground_raycast_distance`.
