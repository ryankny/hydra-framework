# hydra_commands

Centralized command system with argument parsing, type coercion, cooldowns, aliases, chat suggestions, and server/client command registration.

## Dependencies
- `hydra_core`

## API

### Client
- `Hydra.Commands.RegisterLocal(name, handler, options)` -- Register a client-only command. Options: `description`, `category`, `cooldown`, `aliases`, `args`, `module`, `hidden`.
- `Hydra.Commands.GetAll()` -- List all known commands (local + server-registered).

### Argument Definitions
Each arg: `{ name, type, required, default, help }`. Supported types: `string`, `number`, `playerId`, `boolean`.

### Server
The server registers commands and pushes them to the client via the `hydra:commands:register` event. The client registers the FiveM command, provides chat suggestions, and handles cooldowns.

## Exports

**Client:** `RegisterLocal`, `GetAll`

## Commands
- `/keybinds` -- (from hydra_keybinds, listed here as example)

## Events
- `hydra:commands:register` -- Server sends command registration to client.
- `hydra:commands:execute` -- Server requests client to run a command handler.
- `hydra:commands:clientExecute` -- Client asks server to run a command.
- `hydra:commands:suggestions` -- Server sends chat suggestion data.

## Configuration
- `config/commands.lua` -- `enabled`, `max_args`, `cooldown_default`, `cooldown_message`, `debug`.
