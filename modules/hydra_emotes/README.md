# hydra_emotes

Animation and emote system with scenario support, prop emotes, cancel-on-move, and context menu integration. Uses `hydra_anims` as the animation backend when available.

## Dependencies
- `hydra_core`

## API

### Client
- `Hydra.Emotes.Play(name)` -- Play an emote by its registered name.
- `Hydra.Emotes.Cancel(silent)` -- Cancel the current emote.
- `Hydra.Emotes.Register(name, def)` / `Unregister(name)` -- Add or remove emotes at runtime.
- `Hydra.Emotes.IsPlaying()` / `GetCurrent()` / `GetAll()`

### Emote Definition
```lua
{ type = 'anim', dict = '...', anim = '...', flag = 49, looping = true, props = {...} }
{ type = 'scenario', scenario = 'WORLD_HUMAN_...' }
```

## Keybinds
- Cancel key (configurable) -- Cancels the current emote. Default in `config/emotes.lua`.

## Events
- `hydra:notify:show` -- Used internally for emote feedback messages.

## Configuration
- `config/emotes.lua` -- Emote definitions, `cancel_on_move`, `allow_in_vehicle`, `cancel_key`.
