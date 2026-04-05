# hydra_camera

Centralized camera management system. Provides scripted cameras, orbit cameras, screen shake, cinematic bars, path interpolation, transitions, and screen fades.

## Dependencies
- `hydra_core`

## API

### Camera Lifecycle
- `Create(options)` -- Create a camera. Options: `position`, `rotation`, `fov`, `target`, `targetEntity`, `active`, `transition`, `label`. Returns `camId`.
- `Destroy(camId)` / `DestroyAll(transitionMs)`
- `Activate(camId, transitionMs)` / `Deactivate(transitionMs)`
- `TransitionTo(fromCamId, toCamId, durationMs)`

### Properties
- `SetPosition(camId, coords, transitionMs)` / `SetRotation(camId, rotation, transitionMs)`
- `SetFov(camId, fov, transitionMs)` / `PointAt(camId, coords)` / `PointAtEntity(camId, entity, offsetZ)`
- `GetPosition(camId)` / `GetRotation(camId)` / `GetFov(camId)`
- `IsActive(camId)` / `GetActive()`

### Orbit Camera
- `StartOrbit(options)` -- Options: `target`, `targetEntity`, `distance`, `pitch`, `heading`, `fov`, `autoRotate`, `lockPitch`, `lockZoom`.
- `StopOrbit(transitionMs)` / `GetOrbitState()`

### Effects
- `Shake(intensity, durationMs, frequency)` / `StopShake()`
- `ShowBars(fadeMs)` / `HideBars(fadeMs)` / `AreBarsVisible()`
- `FadeIn(durationMs)` / `FadeOut(durationMs)` / `IsFadedOut()`
- `FreezeLook(frozen)`

### Path Interpolation
- `PlayPath(points, options)` -- Animate camera along waypoints. Each point: `position`, `rotation`, `fov`, `duration`. Options: `ease`, `loop`, `onComplete`.
- `StopPath()`

### Hooks
- `OnActivate(fn)` / `OnDeactivate(fn)`

## Exports
- `Create`, `Destroy`, `DestroyAll`, `Activate`, `Deactivate`, `TransitionTo`
- `SetPosition`, `SetRotation`, `PointAt`, `PointAtEntity`, `SetFov`
- `GetPosition`, `GetRotation`, `GetFov`, `IsActive`, `GetActive`
- `StartOrbit`, `StopOrbit`, `GetOrbitState`
- `Shake`, `StopShake`, `ShowBars`, `HideBars`, `AreBarsVisible`
- `FadeIn`, `FadeOut`, `IsFadedOut`, `PlayPath`, `StopPath`, `FreezeLook`
- `OnActivate`, `OnDeactivate`

## Configuration
- `config/camera.lua` -- `default_fov`, `default_transition_ms`, `default_ease`, `max_active_cameras`, `orbit_speed`, `orbit_zoom_min/max`, `orbit_min/max_pitch`, `cinematic_bar_size`, `cinematic_fade_ms`, `cleanup_on_death`.
