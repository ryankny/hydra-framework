# hydra_world

World management module. Controls pedestrian/vehicle population density, law enforcement behavior, scenario groups, and environment settings.

## Dependencies
- `hydra_core`

## API

### Client Exports
- `SetDensity(ped, veh)` -- Set ped and vehicle population multipliers (0.0 to 1.0).
- `GetDensity()` -- Get current density values.
- `GetCurrentZone()` -- Get the player's current world zone name.
- `HasSeatbelt()` -- Check seatbelt state.
- `ClearWanted()` -- Clear the player's wanted level.
- `GetRestrictedZone()` -- Get info about current restricted zone (if any).
- `SetScenarioGroup(group, enabled)` -- Enable or disable a scenario group.

## Exports
- `SetDensity`, `GetDensity`, `GetCurrentZone`, `HasSeatbelt`
- `ClearWanted`, `GetRestrictedZone`, `SetScenarioGroup`

## Configuration
- `config/world.lua` -- Population density defaults, law enforcement settings, scenario group toggles, environment parameters.
