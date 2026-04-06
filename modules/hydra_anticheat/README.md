# hydra_anticheat

Advanced server-authoritative anti-cheat system with client-side monitoring, strike-based punishment, and comprehensive detection coverage.

## Dependencies

- `hydra_core`
- `hydra_logs` (optional — Discord webhook logging)
- `hydra_notify` (optional — client-side warnings)
- `hydra_data` (optional — persistent ban storage)
- `hydra_commands` (optional — admin command registration)
- `screenshot-basic` (optional — screenshot capture on ban)

## Detection Modules

| Module | Coverage |
|--------|----------|
| **movement** | Speed hack, teleport, noclip detection via server-validated position reports |
| **godmode** | Health/armour ceiling checks, damage absorption tracking |
| **weapons** | Blacklisted weapons, rapid-fire detection, damage modifier validation |
| **entities** | Per-player entity caps (peds, vehicles, objects), blacklisted model spawns |
| **explosions** | Blocked explosion types (orbital, etc.), rate limiting per player |
| **events** | Event rate limiting, blocked event enforcement, argument validation, source verification |
| **resources** | Required resource monitoring, runtime injection detection, command blocking |
| **spectate** | Camera-to-ped distance anomaly detection (freecam/spectate menus) |
| **particles** | Particle effect spam rate limiting |
| **ped_flags** | Super jump, invisibility, no-ragdoll, infinite stamina flag monitoring |

## Strike System

Detections accumulate weighted strikes. When a player exceeds the threshold, an automatic ban is issued. Strikes decay over time (configurable). Each detection severity acts as a strike weight multiplier.

## Server API

```lua
-- Flag a player for a detection (called internally or by other modules)
exports['hydra_anticheat']:Flag(src, module, reason, severity, action, data)

-- Manual admin actions
exports['hydra_anticheat']:Ban(src, reason, duration)
exports['hydra_anticheat']:Unban(identifier)
exports['hydra_anticheat']:Kick(src, reason)

-- Strike management
exports['hydra_anticheat']:GetStrikes(src)
exports['hydra_anticheat']:ClearStrikes(src)
exports['hydra_anticheat']:GetHistory(src)

-- Runtime module control
exports['hydra_anticheat']:EnableModule(moduleName)
exports['hydra_anticheat']:DisableModule(moduleName)
exports['hydra_anticheat']:IsModuleEnabled(moduleName)

-- Event security helpers
exports['hydra_anticheat']:SecureEvent(eventName, handler)
exports['hydra_anticheat']:ValidateEvent(src, eventName, ...)
exports['hydra_anticheat']:RegisterEventValidator(eventName, validatorFn)
exports['hydra_anticheat']:CheckRateLimit(src)

-- Hooks
exports['hydra_anticheat']:OnDetection(fn)
exports['hydra_anticheat']:OnBan(fn)
exports['hydra_anticheat']:OnKick(fn)

-- Player data
exports['hydra_anticheat']:GetPlayer(src)
exports['hydra_anticheat']:IsTrustedResource(resource)
```

## Admin Commands

`/ac status` — Show active modules and player count
`/ac strikes [id]` — View player strikes
`/ac history [id]` — View detection history
`/ac ban [id] [reason]` — Ban a player
`/ac unban [identifier]` — Unban by identifier
`/ac clearstrikes [id]` — Clear player strikes
`/ac enable [module]` — Enable a detection module
`/ac disable [module]` — Disable a detection module

## Configuration

See `config/anticheat.lua` for all settings including per-module toggles, action types, thresholds, strike decay, exemptions, and trusted resources.

## Exemptions

Players with the `hydra.anticheat.exempt` ACE permission can be exempted from specific modules (configured in `exemptions.admin_exempt`).
