# hydra_data

Database and data management layer. Provides CRUD operations, caching, subscriptions, reactive client-side stores, and batch operations with adapter support for MySQL, PostgreSQL, SQLite, and MongoDB.

## Dependencies
- `hydra_core`
- `oxmysql`

## API (Server)

### CRUD
- `Create(collection, data)` -- Insert a record.
- `Read(collection, id)` / `Find(collection, query)` / `FindOne(collection, query)`
- `Update(collection, id, data)` / `Delete(collection, id)`
- `Count(collection, query)`
- `BulkCreate(collection, rows)` / `BulkUpdate(collection, updates)`

### Cache
- `CacheGet(key)` / `CacheSet(key, value, ttl)` / `CacheInvalidate(key)`

### Collections
- `CreateCollection(name, schema)` / `CollectionExists(name)`

### Subscriptions
- `Subscribe(collection, callback)` / `Unsubscribe(id)`

### Client Store (Server -> Client sync)
- `SetPlayerStore(src, storeName, key, value)`
- `GetPlayerStore(src, storeName)`

## Exports

**Client:**
- `GetStore(storeName)` -- Get all values in a named store.
- `GetStoreValue(storeName, key, default)` -- Get a single store value.

**Server:** `Create`, `Read`, `Update`, `Delete`, `Find`, `FindOne`, `Count`, `BulkCreate`, `BulkUpdate`, `CacheGet`, `CacheSet`, `CacheInvalidate`, `CreateCollection`, `CollectionExists`, `Subscribe`, `Unsubscribe`, `SetPlayerStore`, `GetPlayerStore`

## Events
- `hydra:store:sync` -- Server pushes a single store value to client.
- `hydra:store:syncBulk` -- Server pushes bulk store data to client.

## Configuration
- `config/default.lua`
- Database adapter is set in `hydra_core/config/default.lua` under `database.adapter`.
