# hydra_physics

Hyper-realistic vehicle handling, ragdoll physics, crash dynamics, and impact simulation. Modifies vehicle behavior at runtime and provides hooks for custom physics events.

## Dependencies
- `hydra_core`

## API

### Client
- `ApplyRagdoll(ped, forceX, forceY, forceZ, duration, source)` -- Apply ragdoll with force.
- `RefreshHandling()` -- Reapply handling modifications to current vehicle.
- `GetHandlingProfile(vehicle)` -- Get the current handling table for a vehicle.
- `SetHandlingValue(vehicle, key, value)` -- Override a single handling field.
- `GetAquaplaneLevel()` / `GetSinkDepth()` / `IsStuck()` / `GetEscapeProgress()` / `ForceUnstick()`

### Hooks
- `OnPreRagdoll(fn)` / `OnPostRagdoll(fn)` -- Before/after ragdoll application.
- `OnVehicleCrash(fn)` -- Fired on vehicle collision.
- `OnPreImpact(fn)` / `OnPostImpact(fn)` / `OnForceCalculated(fn)` -- Impact event hooks.

## Exports
- `ApplyRagdoll`, `RefreshHandling`, `GetHandlingProfile`, `SetHandlingValue`
- `OnPreRagdoll`, `OnPostRagdoll`, `OnVehicleCrash`
- `OnPreImpact`, `OnPostImpact`, `OnForceCalculated`
- `GetAquaplaneLevel`, `GetSinkDepth`, `IsStuck`, `GetEscapeProgress`, `ForceUnstick`

## Configuration
- `config/physics.lua` -- Handling profiles, ragdoll settings, impact thresholds, dynamics parameters.
