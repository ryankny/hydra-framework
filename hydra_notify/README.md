# hydra_notify

Notification system for displaying toast-style notifications to players. Supports types (success, error, info, warning), titles, durations, and server-triggered notifications.

## Dependencies
- `hydra_core`
- `hydra_ui`

## API

### Client
- `Hydra.Notify.Show(data)` -- Show a notification. `data` contains `type`, `title`, `message`, `duration`.
- `Hydra.Notify.Clear()` -- Clear all active notifications.

### Server
- `Hydra.Notify.Send(source, data)` -- Send a notification to a specific player.
- `Hydra.Notify.SendAll(data)` -- Send a notification to all players.

## Exports

**Server:**
- `Notify(source, data)`
- `NotifyAll(data)`

## Events
- `hydra:notify:show` -- Client-side event to display a notification.

## Configuration
No dedicated config file. NUI theming inherited from `hydra_ui`.
