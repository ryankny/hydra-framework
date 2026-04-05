# hydra_audio

Centralized audio management system. Handles GTA native sounds, custom HTML5 audio via NUI, 3D spatial audio, ambient soundscapes, soundbanks, and cascading volume control.

## Dependencies
- `hydra_core`

## API

### Playback
- `PlayFrontend(name, soundSet, category)` -- GTA native UI sound.
- `PlayAtCoord(name, soundSet, coords, range, category)` -- 3D spatial sound.
- `PlayOnEntity(name, soundSet, entity, category)` -- Sound attached to entity.
- `PlayCustom(url, options)` -- HTML5 audio via NUI. Options: `volume`, `loop`, `category`, `fadeIn`.
- `PlayBank(bankName, soundName, options)` -- Play from a registered soundbank.

### Control
- `Stop(soundId, fadeOut)` / `StopAll(category, fadeOut)`
- `Pause(soundId)` / `Resume(soundId)`
- `SetVolume(soundId, volume)` / `Fade(soundId, from, to, durationMs)`

### Volume
- `SetMasterVolume(volume)` / `GetMasterVolume()`
- `SetCategoryVolume(category, volume)` / `GetCategoryVolume(category)`

### Ambient
- `StartAmbient(name, options)` / `StopAmbient(id, fadeOut)` / `StopAllAmbient(fadeOut)`

### Query
- `IsPlaying(soundId)` / `GetActiveCount(category)`
- `RegisterBank(name, sounds)` -- Register a soundbank at runtime.

### Hooks
- `OnPlay(fn)` / `OnStop(fn)` -- Listen to all sound start/stop events.

## Exports

**Client:** `PlayFrontend`, `PlayAtCoord`, `PlayOnEntity`, `PlayCustom`, `PlayBank`, `Stop`, `StopAll`, `Pause`, `Resume`, `SetVolume`, `Fade`, `SetMasterVolume`, `GetMasterVolume`, `SetCategoryVolume`, `GetCategoryVolume`, `StartAmbient`, `StopAmbient`, `StopAllAmbient`, `IsPlaying`, `GetActiveCount`, `RegisterBank`, `OnPlay`, `OnStop`

**Server:** `PlayClient`, `PlayAll`, `StopClient`, `StopAllClients`

## Configuration
- `config/audio.lua` -- `master_volume`, `categories` (volume per category), `max_concurrent_sounds`, `max_concurrent_ambient`, `spatial_falloff`, `fade_default_duration`, `soundbanks`, `ambient_zones`, `cleanup_interval`.
