# hydra_scenes

Scripted sequence and cutscene engine. Orchestrates camera, animation, audio, NPCs, objects, and markers into timed, skippable sequences for cutscenes, tutorials, job intros, and mission briefings.

## Dependencies
- `hydra_core`

## API

### Scene Management
- `Register(name, definition)` -- Register a named scene definition. Definition contains `steps` (array of timed actions), `duration`, `skippable`, `onStart`, `onComplete`, `hud`, `freeze`.
- `Unregister(name)`
- `Play(name, data)` -- Play a registered scene with optional runtime data.
- `PlayInline(definition, data)` -- Play an unregistered scene definition directly.
- `Stop(skipCleanup)` -- Stop the active scene.
- `Skip()` -- Skip to the end of the active scene (if skippable).

### Query
- `IsPlaying()` -- Check if a scene is active.
- `GetCurrent()` -- Get info about the active scene.
- `GetRegistered()` -- List all registered scene names.

### Hooks
- `OnStart(fn)` / `OnComplete(fn)` -- Global lifecycle hooks.

### Step Types
Steps can control cameras (create, path, orbit), animations (play on player/NPC), audio (play/stop), objects (spawn/remove), NPCs (spawn/remove), markers, HUD visibility, screen fades, and custom functions.

## Exports
- `Register`, `Unregister`, `Play`, `PlayInline`, `Stop`, `Skip`
- `IsPlaying`, `GetCurrent`, `GetRegistered`
- `OnStart`, `OnComplete`

## Events
- `hydra:scenes:start` / `hydra:scenes:complete` -- Fired locally during scene lifecycle.

## Configuration
- `config/scenes.lua` -- Default scene settings, step timing, skip key configuration.
