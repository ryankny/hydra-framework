# hydra_weather

Server-authoritative synced weather and time system. All players see identical weather with smooth transitions. Supports freeze time/weather, blackout mode, and wind control.

## Dependencies
- `hydra_core`

## API

### Client
- `Hydra.Weather.GetWeather()` -- Current weather type string.
- `Hydra.Weather.GetTime()` -- Returns `hour, minute`.
- `Hydra.Weather.IsTimeFrozen()` / `IsWeatherFrozen()` / `IsBlackout()`

### Server Exports
- `GetWeather()` / `GetTime()`
- `SetWeather(weatherType)` -- Change weather for all players.
- `SetTime(hour, minute)` -- Change the server time.
- `SetFreezeTime(bool)` / `SetFreezeWeather(bool)` / `SetBlackout(bool)`

## Exports

**Client:** `GetWeather`, `GetTime`, `IsTimeFrozen`, `IsWeatherFrozen`, `IsBlackout`

**Server:** `GetWeather`, `GetTime`, `SetWeather`, `SetTime`, `SetFreezeTime`, `SetFreezeWeather`, `SetBlackout`

## Events
- `hydra:weather:sync` -- Server pushes weather/time state to all clients.
- `hydra:weather:requestSync` -- Client requests current state on join.

## Configuration
- `config/weather.lua` -- `default_weather`, `default_hour`, `default_minute`, `freeze_time`, `freeze_weather`, `weather_transition_duration`.
