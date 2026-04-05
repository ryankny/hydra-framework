# hydra_bridge

Framework compatibility bridge. Auto-detects and adapts to ESX, QBCore, QBox, or TMC so Hydra modules work alongside existing framework resources.

## Dependencies
- `hydra_core`
- `hydra_data`

## API

The bridge is mostly automatic. On server start, `server/detector.lua` identifies the active framework and loads the matching adapter from `bridges/`.

### Server
- `GetBridgeMode()` -- Returns the detected framework name (e.g. `'esx'`, `'qbcore'`, `'standalone'`).
- `IsBridgeActive()` -- Returns `true` if a bridge adapter is active.

### Client
The client receives the bridge mode from the server and initializes the matching client adapter.

## Exports

**Server-only:**
- `GetBridgeMode`
- `IsBridgeActive`

## Events
- `hydra:bridge:setMode` -- Server tells client which adapter to use.
- `hydra:bridge:requestMode` / `hydra:bridge:mode` -- Client requests and receives bridge mode.

## Configuration
No configuration file. Detection is automatic based on which framework resources are running.
