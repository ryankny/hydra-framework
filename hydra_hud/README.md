# hydra_hud

Player and vehicle HUD with navigation. Replaces default GTA HUD elements with a customizable NUI-based display showing health, armor, hunger, thirst, cash, and vehicle stats.

## Dependencies
- `hydra_core`
- `hydra_ui`
- `hydra_players`

## API

### Client
- `Hydra.HUD.SetVisible(visible)` -- Show or hide the entire HUD.
- `Hydra.HUD.Toggle()` -- Toggle HUD visibility.
- `Hydra.HUD.IsVisible()` -- Check current visibility state.
- `Hydra.HUD.Send(action, data)` -- Send data directly to the HUD NUI.

## Events
- `hydra:hud:moneyUpdate` -- Server pushes money change animations.
- `hydra:hud:jobUpdate` -- Server pushes job change data.

## Keybinds
- `F7` -- Toggle HUD visibility (configurable via `hydra_keybinds`).

## Configuration
- `config.lua` -- `update_rate`, player HUD settings (`show_health`, `show_armor`, `show_hunger`, etc.), vehicle HUD settings, position layout.
