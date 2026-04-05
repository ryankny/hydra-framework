# hydra_ui

Core NUI engine shared by all Hydra UI modules (HUD, notifications, menus, etc.). Manages the NUI frame lifecycle, message queuing, theming, and focus control.

## Dependencies
- `hydra_core`

## API

### Client
- `Hydra.UI.Send(module, action, data)` -- Send a message to the NUI frame. Queues messages until the frame reports ready.
- `Hydra.UI.OnNUI(name, handler)` -- Register a NUI callback with error handling.
- `Hydra.UI.SetFocus(hasFocus, hasCursor)` -- Set NUI focus state.
- `Hydra.UI.ReleaseFocus()` -- Release all NUI focus.

### Theming
Theme data is defined in `shared/theme.lua` and synced from server to client via the `hydra:ui:syncTheme` event.

## Events
- `hydra:ui:syncTheme` -- Server pushes theme config to client.
- `hydra:ui:command` -- Server sends a UI command to client.

## Configuration
- `shared/theme.lua` -- Color palette, font, border-radius, and other CSS variables.

## Files
- `nui/index.html` -- Root NUI page.
- `nui/css/hydra.css`, `nui/css/animations.css`
- `nui/js/core.js`, `nui/js/components.js`, `nui/js/animations.js`
