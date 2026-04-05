# hydra_players

Server-authoritative player management. Handles player data, accounts (money), jobs, groups, metadata, and character persistence. Client receives synced state via the data store system.

## Dependencies
- `hydra_core`
- `hydra_data`
- `hydra_bridge`

## API

### Server
- `GetPlayer(src)` / `GetAllPlayers()` / `GetAllPlayerIds()`
- `GetPlayerByIdentifier(identifier)`
- `AddMoney(src, account, amount)` / `RemoveMoney(src, account, amount)` / `SetMoney(src, account, amount)` / `GetMoney(src, account)`
- `SetJob(src, name, grade)` / `GetJob(src)`
- `SetGroup(src, group)` / `GetGroup(src)`
- `SetMetadata(src, key, value)` / `GetMetadata(src, key)`
- `SavePlayer(src)` / `SaveAllPlayers()`

### Client
- `Hydra.PlayerState.Get()` -- Full player data table.
- `Hydra.PlayerState.GetField(key)` / `GetMoney(accountType)` / `GetJob()` / `GetGroup()`
- `Hydra.PlayerState.IsLoaded()` -- Whether player data has been received.

## Exports
**Server:** `GetPlayer`, `GetAllPlayers`, `GetAllPlayerIds`, `GetPlayerByIdentifier`, `AddMoney`, `RemoveMoney`, `SetMoney`, `GetMoney`, `SetJob`, `GetJob`, `SetGroup`, `GetGroup`, `SetMetadata`, `GetMetadata`, `SavePlayer`, `SaveAllPlayers`

## Events
- `hydra:players:loaded` -- Server sends player data to client after load.
- `hydra:players:ready` -- Client-side event fired when player data is available.
- `hydra:players:accountsUpdated` / `hydra:players:jobUpdated` -- Fired on client when store values change.

## Configuration
- `config/default.lua` (server-side)
