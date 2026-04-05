# hydra_logs

Server-side logging system with Discord webhook integration. Provides typed logging functions for common events (connections, deaths, money, admin actions, anti-cheat).

## Dependencies
- `hydra_core`

## API (Server-only)

### Core
- `Hydra.Logs.Send(channel, data)` -- Send a custom log entry to a channel.
- `Hydra.Logs.Quick(channel, title, description, src)` -- Quick one-liner log.

### Typed Loggers
- `Hydra.Logs.Connection(src, message)` / `Disconnection(src, reason)`
- `Hydra.Logs.Chat(src, channel, message)`
- `Hydra.Logs.Death(src, killerId, cause)`
- `Hydra.Logs.Money(src, action, account, amount, newBalance)`
- `Hydra.Logs.Admin(src, action, details)`
- `Hydra.Logs.Job(src, oldJob, newJob)`
- `Hydra.Logs.AntiCheat(src, detection, details)`

## Exports
- `LogSend`, `LogQuick`, `LogConnection`, `LogDisconnection`, `LogChat`
- `LogDeath`, `LogMoney`, `LogAdmin`, `LogJob`, `LogAntiCheat`

## Configuration
- `config/logs.lua` -- Webhook URLs per channel, log formatting options, enabled channels.
