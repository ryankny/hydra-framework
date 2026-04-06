# hydra_npc

NPC spawning and management system. Handles model loading, proximity-based spawn/despawn, behavior configuration, templates, and lifecycle tracking. Server can trigger NPC creation on specific or all clients.

## Dependencies
- `hydra_core`

## API

### Server
- `Hydra.NPC.CreateClient(src, options)` -- Spawn an NPC on a specific client. Options: `model`, `coords`, `heading`, `scenario`, `anim`, `invincible`, `frozen`, `tag`, `blocking`, `relationship`.
- `Hydra.NPC.CreateAll(options)` -- Spawn an NPC on all clients.
- `Hydra.NPC.RemoveClient(src, tag)` -- Remove NPCs for a player (optionally by tag).
- `Hydra.NPC.RemoveAll(tag)` -- Remove NPCs for all players.

## Exports

**Server:** `CreateClient`, `CreateAll`, `RemoveClient`, `RemoveAll`

## Commands
- `/npc info` -- Show NPC system config (admin only, `hydra.admin` ACE).
- `/npc clear [playerId]` -- Remove all managed NPCs.
- `/npc cleartag <tag> [playerId]` -- Remove NPCs by tag.

## Events
- `hydra:npc:create` -- Server tells client to spawn an NPC.
- `hydra:npc:removeByTag` / `hydra:npc:removeAll` -- Server tells client to clean up NPCs.

## Configuration
- `config/npc.lua` -- `max_npcs`, `spawn_distance`, `despawn_distance`, `model_timeout`, `default_invincible`, `default_frozen`, `enable_proximity_spawning`, `behavior` (flee, combat, relationship), `templates`.
