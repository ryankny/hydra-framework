# hydra_anticheat

Advanced server-authoritative anti-cheat system with 20+ detection modules, strike-based punishment, heartbeat integrity, honeypot traps, and comprehensive combat/vehicle/network analysis.

## Dependencies

- `hydra_core`
- `hydra_logs` (optional — Discord webhook logging)
- `hydra_notify` (optional — client-side warnings)
- `hydra_data` (optional — persistent ban storage)
- `hydra_commands` (optional — admin command registration)
- `hydra_bridge` (optional — job checks for vision detection)
- `screenshot-basic` (optional — screenshot evidence capture)

## Detection Modules

| Module | Coverage |
|--------|----------|
| **movement** | Speed hack, teleport, noclip, vehicle fly, out-of-bounds, underground, swim speed |
| **godmode** | Health/armour ceiling, damage absorption, regen rate, invincibility flag, vehicle god mode |
| **weapons** | Blacklist, rapid fire, aimbot (headshot ratio, snap angle, lock-on), no recoil, infinite ammo, no reload, one-hit kill, weapon give detection |
| **entities** | Per-player caps (peds/vehicles/objects), blacklisted models, spawn rate limiting, attached object detection, ownership validation |
| **explosions** | Blocked types, flood rate limiting, remote explosion distance check |
| **events** | Global + per-event rate limiting, blocked events, argument validation, source verification, payload size limits |
| **resources** | Required resource monitoring, injection detection, stop detection, command blocking |
| **spectate** | Camera-to-ped distance (freecam/spectate menus) with consecutive violation tracking |
| **particles** | Particle effect spam rate limiting |
| **ped_flags** | Super jump, invisibility, no-ragdoll, infinite stamina, invincible flag, task clear abuse, model change |
| **vehicles** | Handling modification, vehicle fly, torpedo speed, spawn rate, horn boost, speed modifier, vehicle god mode |
| **damage** | Single-hit cap, DPS cap, distance validation, self-heal detection, weaponDamageEvent filtering |
| **vision** | Thermal/night vision abuse with job whitelist |
| **menu_detection** | Global variable scanning, blacklisted resources, executor signatures, suspicious native patterns |
| **chat_protection** | Message/command rate limiting, injection pattern detection |
| **desync** | Ping monitoring, position desync detection |
| **pickups** | Collection rate limiting, distance validation |
| **honeypots** | Fake events that only cheaters trigger (instant ban) |
| **heartbeat** | Challenge-response integrity verification, detects AC bypass |
| **connection** | Required identifiers, HWID tracking, connection rate limiting |

## Systems

### Strike System
Detections accumulate weighted strikes (severity = weight). Configurable escalation thresholds with progressive punishment (warn -> kick -> ban). Strikes decay over time.

### Heartbeat
Server sends random challenge tokens; client must echo back within the interval. Missed heartbeats accumulate; exceeding tolerance triggers action. Detects client-side AC module being disabled/removed.

### Honeypot Events
Registers fake server events (e.g., `server:GiveMoney`, `admin:setJob`) that no legitimate client would trigger. Any client calling these is immediately flagged.

### Screenshot Evidence
Auto-captures screenshots on detections above configurable severity. Supports random periodic screenshots for monitoring. Respects per-session limits and cooldowns.

### Discord Webhooks
Posts detection embeds to Discord with player info, identifiers, module, severity. Rate-limited to avoid Discord API limits.

## Server API

```lua
-- Core
exports['hydra_anticheat']:Flag(src, module, reason, severity, action, data)
exports['hydra_anticheat']:Ban(src, reason, duration)
exports['hydra_anticheat']:Unban(identifier)
exports['hydra_anticheat']:Kick(src, reason)

-- Strikes
exports['hydra_anticheat']:GetStrikes(src)
exports['hydra_anticheat']:ClearStrikes(src)
exports['hydra_anticheat']:GetHistory(src)

-- Modules
exports['hydra_anticheat']:EnableModule(moduleName)
exports['hydra_anticheat']:DisableModule(moduleName)
exports['hydra_anticheat']:IsModuleEnabled(moduleName)

-- Events
exports['hydra_anticheat']:SecureEvent(eventName, handler)
exports['hydra_anticheat']:ValidateEvent(src, eventName, ...)
exports['hydra_anticheat']:RegisterEventValidator(eventName, fn)
exports['hydra_anticheat']:CheckRateLimit(src)

-- Hooks
exports['hydra_anticheat']:OnDetection(fn)
exports['hydra_anticheat']:OnBan(fn)
exports['hydra_anticheat']:OnKick(fn)

-- Evidence
exports['hydra_anticheat']:RequestScreenshot(src, reason)
exports['hydra_anticheat']:GetStats()

-- Teleport
exports['hydra_anticheat']:WhitelistTeleport(src)
exports['hydra_anticheat']:IsWhitelistedTeleport(src)

-- Combat
exports['hydra_anticheat']:WhitelistWeaponGive(src)

-- Info
exports['hydra_anticheat']:GetPlayer(src)
exports['hydra_anticheat']:IsTrustedResource(resource)
```

## Admin Commands

`/ac status` — Active modules and player count
`/ac strikes [id]` — Player strikes
`/ac history [id]` — Detection history
`/ac info [id]` — Full player info (identifiers, stats, join time)
`/ac ban [id] [reason]` — Ban player
`/ac unban [identifier]` — Unban by identifier
`/ac clearstrikes [id]` — Clear strikes
`/ac screenshot [id]` — Request screenshot
`/ac banlist` — Show active bans
`/ac stats` — Global AC statistics
`/ac enable [module]` — Enable detection module
`/ac disable [module]` — Disable detection module

## Configuration

See `config/anticheat.lua` — every module has independent enable/disable, severity, action, thresholds, and timing. Includes exemptions (ACE-based), trusted resources, teleport whitelist, and honeypot event list.
