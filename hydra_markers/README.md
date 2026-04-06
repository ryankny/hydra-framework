# hydra_markers

3D marker, checkpoint, and floating text system. Uses a two-thread architecture: a slow proximity check maintains a small set of nearby markers, and a fast render thread only iterates that subset per frame.

## Dependencies
- `hydra_core`

## API

### Markers
- `Add(options)` -- Create a 3D marker. Options: `coords`, `type`, `scale`, `color`, `rotation`, `bobUpDown`, `faceCamera`, `rotate`, `drawDistance`, `enterDistance`, `visible`, `label`, `labelColor`, `owner`, `tag`, `metadata`, `onEnter`, `onExit`. Returns `markerId`.
- `Remove(id)` / `RemoveByOwner(owner)` / `RemoveByTag(tag)` / `RemoveAll()`

### Modify
- `SetCoords(id, coords)`, `SetColor(id, r, g, b, a)`, `SetScale(id, scale)`, `SetVisible(id, visible)`, `SetLabel(id, text)`, `SetMetadata(id, key, value)`, `GetMetadata(id, key)`

### Query
- `Get(id)`, `Exists(id)`, `GetAll()`, `GetByTag(tag)`, `GetNearby(coords, radius)`
- `IsInside(id)`, `GetInsideMarkers()`, `GetCount()`

### Floating Text
- `AddText(options)` / `RemoveText(id)` / `SetText(id, text)` / `RemoveTextByTag(tag)`

### Checkpoints
- `AddCheckpoint(options)` / `RemoveCheckpoint(id)` / `RemoveAllCheckpoints()`

### Global Handlers
- `OnEnter(fn)` / `OnExit(fn)` -- Fired for any marker enter/exit.

## Exports
All API functions listed above are available as exports.

## Events
- `hydra:markers:enter` / `hydra:markers:exit` -- Fired with `(markerId, coords)`.

## Configuration
- `config/markers.lua` -- `default_marker_type`, `default_scale`, `default_color`, `default_draw_distance`, `max_draw_distance`, `max_markers`, `default_bob`, `default_rotate`, `float_text_font`, `float_text_scale`.
