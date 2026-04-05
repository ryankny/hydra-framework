# hydra_anims

Centralized animation management system. Provides LRU dict caching, priority-based animation playback, queuing, prop management, scenario support, hooks, and completion monitoring.

## Dependencies
- `hydra_core`

## API

### Playback
- `Hydra.Anims.Play(ped, options)` -- Play an animation. Options: `dict`, `anim`, `flag`, `duration`, `priority`, `blendIn`, `blendOut`, `playbackRate`, `props`, `lockControl`, `lockPosition`, `label`, `onStart`, `onEnd`. Returns `animId`.
- `Hydra.Anims.PlayScenario(ped, scenario, options)` -- Play a scenario.
- `Hydra.Anims.Stop(ped, animId, blendOut)` / `StopAll(ped, blendOut)`
- `Hydra.Anims.Queue(ped, options)` -- Queue animation after current finishes.

### Query
- `IsPlaying(ped, animId)` / `GetCurrent(ped)` / `GetProgress(ped)` / `GetDuration(dict, anim)`

### Dict Cache
- `LoadDict(dict)` / `ReleaseDict(dict)` / `Preload(dicts)`

### Props
- `AttachProp(ped, options)` / `DetachProp(propEntity)` / `DetachAllProps(ped)`

### Hooks
- `OnBefore(fn)` -- Return `false` to cancel. `OnAfter(fn)`, `OnCancel(fn)`.

## Exports
- `Play`, `Stop`, `StopAll`, `Queue`, `PlayScenario`
- `IsPlaying`, `GetCurrent`, `GetProgress`, `GetDuration`
- `LoadDict`, `ReleaseDict`, `Preload`
- `AttachProp`, `DetachProp`, `DetachAllProps`
- `OnBefore`, `OnAfter`, `OnCancel`

## Events
- `hydra:anims:play` / `hydra:anims:stop` -- Server-triggered playback control.

## Configuration
- `config/anims.lua` -- `dict_cache_size`, `dict_timeout`, `max_queue_size`, `default_flag`, `default_blend_in`, `default_blend_out`, `cleanup_interval`, `sync_to_server`, `prop_cleanup_delay`.
