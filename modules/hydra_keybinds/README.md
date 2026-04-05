# hydra_keybinds

Centralized keybind management system. Replaces scattered `RegisterKeyMapping` calls with a unified API that tracks bindings, detects conflicts, and supports runtime enable/disable.

## Dependencies
- `hydra_core`

## API

### Registration
- `Register(id, options)` -- Register a keybind. Options: `key`, `description`, `category`, `module`, `isHold`, `onPress`, `onRelease`, `enabled`, `mapper`.
- `Unregister(id)` -- Disable and remove a keybind from tracking.

### Control
- `SetEnabled(id, enabled)` -- Enable or disable a keybind at runtime.
- `DisableAll()` / `EnableAll()` -- Global toggle (e.g. during NUI focus).
- `IsDisabled()` -- Check global disable state.

### Query
- `Exists(id)` / `GetInfo(id)` -- Single keybind lookup.
- `GetAll(category)` -- List all keybinds, optionally filtered by category.
- `GetCategories()` -- List all registered categories.
- `GetConflicts()` -- Get keys bound to multiple actions.

### Hooks
- `OnTrigger(fn)` -- Callback fires on any keybind press/release.

## Exports
- `Register`, `Unregister`, `SetEnabled`, `Exists`, `GetInfo`
- `GetAll`, `GetCategories`, `GetConflicts`
- `DisableAll`, `EnableAll`, `IsDisabled`, `OnTrigger`

## Commands
- `/keybinds` -- Print all registered keybinds to console (configurable command name).

## Configuration
- `config/keybinds.lua` -- `enabled`, `conflict_detection`, `conflict_action` (`warn`/`block`/`allow`), `list_command`, `debug`.
