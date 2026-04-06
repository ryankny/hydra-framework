# hydra_death

Death, last stand, and respawn system. Handles downed state, EMS revive window, hospital respawn with cost deduction, and configurable hospital locations.

## Dependencies
- `hydra_core`
- `hydra_players`

## API

### Server
- `Hydra.Death.SetDead(src)` -- Force a player into the death state.
- `Hydra.Death.IsDead(src)` -- Check if a player is dead.
- `Hydra.Death.Revive(src, coords)` -- Revive a player at optional coordinates.
- `Hydra.Death.Respawn(src)` -- Respawn a player at a random hospital.

### Client
- `Hydra.Death.IsDead()` -- Local death check.
- `Hydra.Death.IsLastStandExpired()` -- Whether last stand timer has expired.

## Exports

**Client:** `IsDead`, `IsLastStandExpired`

**Server:** `IsDead`, `Revive`, `Respawn`

## Configuration
- `config/death.lua` -- `last_stand_duration`, `respawn_timer`, `allow_revive`, `respawn_cost`, `respawn_cost_account`, `hospitals` (array of spawn locations), `disable_while_dead`.
