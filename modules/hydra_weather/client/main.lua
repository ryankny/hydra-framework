--[[
    Hydra Weather - Client

    Applies authoritative time and weather from the server.
    Smooth weather transitions. Overrides GTA native weather/time
    systems to ensure all players see the same conditions.
    Minimal tick usage - only runs disable natives in a 0ms loop,
    sync application runs on a slower cadence.
]]

Hydra = Hydra or {}
Hydra.Weather = {}

local cfg = HydraWeatherConfig

-- Synced state from server
local syncedWeather = cfg.default_weather
local syncedHour = cfg.default_hour
local syncedMinute = cfg.default_minute
local freezeTime = cfg.freeze_time
local freezeWeather = cfg.freeze_weather
local isBlackout = false
local windSpeed = 0.0
local windDirection = 0.0
local transitionDuration = cfg.weather_transition_duration or 30.0

-- Transition state
local currentWeatherHash = GetHashKey(cfg.default_weather)
local targetWeatherHash = currentWeatherHash
local isTransitioning = false
local transitionStart = 0
local transitionEnd = 0

-- Previous weather for smooth blend
local previousWeather = cfg.default_weather

-- Track if we've received initial sync
local hasSynced = false

--- Apply the weather immediately (no transition)
local function applyWeatherImmediate(weatherType)
    local hash = GetHashKey(weatherType)
    SetWeatherTypeNowPersist(weatherType)
    SetWeatherTypeNow(weatherType)
    SetOverrideWeather(weatherType)
    currentWeatherHash = hash
    targetWeatherHash = hash
    previousWeather = weatherType
    isTransitioning = false
end

--- Start a smooth weather transition
local function startWeatherTransition(newWeather)
    if newWeather == previousWeather then return end

    previousWeather = syncedWeather ~= newWeather and syncedWeather or previousWeather
    targetWeatherHash = GetHashKey(newWeather)

    -- Use native transition
    SetWeatherTypeOvertimePersist(newWeather, transitionDuration)

    isTransitioning = true
    transitionStart = GetGameTimer()
    transitionEnd = transitionStart + (transitionDuration * 1000)
end

--- Handle sync from server
RegisterNetEvent('hydra:weather:sync')
AddEventHandler('hydra:weather:sync', function(data)
    local weatherChanged = data.weather ~= syncedWeather

    syncedWeather = data.weather
    syncedHour = data.hour
    syncedMinute = data.minute
    freezeTime = data.freezeTime
    freezeWeather = data.freezeWeather
    isBlackout = data.blackout
    windSpeed = data.windSpeed or 0.0
    windDirection = data.windDirection or 0.0
    transitionDuration = data.transitionDuration or 30.0

    if not hasSynced then
        -- First sync: apply immediately
        hasSynced = true
        applyWeatherImmediate(syncedWeather)
    elseif weatherChanged then
        startWeatherTransition(syncedWeather)
    end
end)

-- Request sync on spawn
CreateThread(function()
    while not hasSynced do
        TriggerServerEvent('hydra:weather:requestSync')
        Wait(2000)
        if hasSynced then break end
    end
end)

-- =============================================
-- MAIN SYNC LOOP
-- Applies time and manages transition completion.
-- Runs every 100ms to reduce overhead.
-- =============================================

CreateThread(function()
    while true do
        Wait(100)

        if hasSynced then
            -- Apply time
            NetworkOverrideClockTime(syncedHour, syncedMinute, 0)

            -- Check transition completion
            if isTransitioning and GetGameTimer() >= transitionEnd then
                isTransitioning = false
                currentWeatherHash = targetWeatherHash
                previousWeather = syncedWeather
                SetWeatherTypeNowPersist(syncedWeather)
                SetOverrideWeather(syncedWeather)
            end

            -- Wind
            SetWind(windSpeed)
            SetWindDirection(windDirection)

            -- Blackout
            SetArtificialLightsState(isBlackout)
        end
    end
end)

-- =============================================
-- DISABLE NATIVE WEATHER/TIME SYSTEMS
-- Must run at 0ms to fully override
-- =============================================

CreateThread(function()
    while true do
        Wait(0)

        if hasSynced then
            -- Prevent GTA from changing weather on its own
            SetWeatherTypeNowPersist(syncedWeather)

            -- Freeze time if requested
            if freezeTime then
                NetworkOverrideClockTime(syncedHour, syncedMinute, 0)
            end
        end
    end
end)

-- =============================================
-- CLIENT API
-- =============================================

--- Get current weather type string
function Hydra.Weather.GetWeather()
    return syncedWeather
end

--- Get current time
function Hydra.Weather.GetTime()
    return syncedHour, syncedMinute
end

--- Is time frozen
function Hydra.Weather.IsTimeFrozen()
    return freezeTime
end

--- Is weather frozen
function Hydra.Weather.IsWeatherFrozen()
    return freezeWeather
end

--- Is blackout active
function Hydra.Weather.IsBlackout()
    return isBlackout
end

-- Client exports
exports('GetWeather', function() return syncedWeather end)
exports('GetTime', function() return syncedHour, syncedMinute end)
exports('IsTimeFrozen', function() return freezeTime end)
exports('IsWeatherFrozen', function() return freezeWeather end)
exports('IsBlackout', function() return isBlackout end)
