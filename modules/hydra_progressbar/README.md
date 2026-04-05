# hydra_progressbar

Lightweight progress bars for timed player actions with optional animation, prop attachment, and movement/combat disabling.

## Dependencies
- `hydra_core`
- `hydra_ui`

## API

### Client
- `Hydra.Progressbar.Start(options, cb)` -- Start a progress bar. Callback receives `true` (completed) or `false` (cancelled). Options include `duration`, `label`, `useWhileDead`, `canCancel`, `disableMovement`, `disableCarMovement`, `disableCombat`, `anim`, `prop`.
- `Hydra.Progressbar.Cancel()` -- Cancel the active progress bar.
- `Hydra.Progressbar.IsActive()` -- Check if a progress bar is running.

Uses `hydra_anims` for animation playback when available.

## Exports
- `ProgressStart(options, cb)`
- `ProgressCancel()`
- `IsProgressActive()`

## Configuration
No dedicated config file. NUI theming inherited from `hydra_ui`.
