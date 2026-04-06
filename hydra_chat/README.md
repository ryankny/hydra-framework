# hydra_chat

Custom chat system with channels, command integration, formatting, and mute support. Replaces the default FiveM chat with a fully NUI-based implementation.

## Dependencies
- `hydra_core`

## API

### Client
- `Hydra.Chat.Open()` / `Close()` / `Toggle()` -- Control chat input visibility.

### Server
- `Hydra.Chat.SystemMessage(src, message, color)` -- Send a system message to a player.
- `Hydra.Chat.Announce(message)` -- Broadcast an announcement to all players.
- `Hydra.Chat.Mute(src, duration)` / `Unmute(src)` / `IsMuted(src)`
- `Hydra.Chat.RegisterCommand(name, handler, opts)` -- Register a chat command.

## Exports

**Client:** `OpenChat`, `CloseChat`, `IsChatOpen`

**Server:** `ChatSystemMessage`, `ChatAnnounce`, `ChatRegisterCommand`, `ChatMute`, `ChatUnmute`

## Keybinds
- `T` -- Open chat input (configurable via `hydra_keybinds`).

## Events
- `hydra:chat:receiveMessage` / `hydra:chat:systemMessage` -- Message delivery.
- `hydra:chat:switchChannel` / `hydra:chat:clear` / `hydra:chat:addSuggestion`

## Configuration
- `config/chat.lua` -- `default_channel`, `command_prefix`, `channels` (name, label, color, permission).
