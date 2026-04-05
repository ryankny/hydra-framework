--[[
    Hydra Weather - Server

    Authoritative time and weather state. Broadcasts to all
    clients on a tick. Handles admin commands and automatic
    weather cycling with weighted natural transitions.
]]

Hydra = Hydra or {}
Hydra.Weather = {}

local cfg = HydraWeatherConfig

-- Current state
local currentWeather = cfg.default_weather
local currentHour = cfg.default_hour
local currentMinute = cfg.default_minute
local freezeTime = cfg.freeze_time
local freezeWeather = cfg.freeze_weather
local blackout = false
local windSpeed = 0.0
local windDirection = 0.0

-- Timing
local timeAccumulator = 0.0  -- ms accumulated for time progression
local lastWeatherChange = 0  -- os.time of last weather change
local lastTick = GetGameTimer()

--- Pick a random next weather based on allowed transitions and weights
--- @return string
local function pickNextWeather()
    local current = cfg.weather_types[currentWeather]
    if not current or not current.allowed_next then
        return 'CLEAR'
    end

    -- Build weighted pool from allowed next types
    local pool = {}
    local totalWeight = 0

    for _, wType in ipairs(current.allowed_next) do
        local def = cfg.weather_types[wType]
        if def and def.weight > 0 then
            totalWeight = totalWeight + def.weight
            pool[#pool + 1] = { type = wType, weight = def.weight }
        end
    end

    if totalWeight == 0 then return 'CLEAR' end

    -- Weighted random selection
    local roll = math.random() * totalWeight
    local sum = 0
    for _, entry in ipairs(pool) do
        sum = sum + entry.weight
        if roll <= sum then
            return entry.type
        end
    end

    return pool[#pool].type
end

--- Randomise wind
local function randomiseWind()
    windSpeed = cfg.wind.min + math.random() * (cfg.wind.max - cfg.wind.min)
    windDirection = math.random() * 360.0
end

--- Get the current time multiplier based on day/night
local function getTimeMultiplier()
    if currentHour >= 6 and currentHour < 20 then
        return cfg.day_multiplier or 1.0
    else
        return cfg.night_multiplier or 1.0
    end
end

--- Build the sync payload
local function getSyncData()
    return {
        weather = currentWeather,
        hour = currentHour,
        minute = currentMinute,
        freezeTime = freezeTime,
        freezeWeather = freezeWeather,
        blackout = blackout,
        windSpeed = windSpeed,
        windDirection = windDirection,
        transitionDuration = cfg.weather_transition_duration,
    }
end

--- Broadcast current state to all clients
local function broadcastSync()
    TriggerClientEvent('hydra:weather:sync', -1, getSyncData())
end

--- Send sync to a specific player
local function syncPlayer(src)
    TriggerClientEvent('hydra:weather:sync', src, getSyncData())
end

-- =============================================
-- TIME PROGRESSION LOOP
-- =============================================

CreateThread(function()
    math.randomseed(os.time())
    randomiseWind()
    lastWeatherChange = os.time()

    while true do
        Wait(1000) -- Tick every second

        local now = GetGameTimer()
        local delta = now - lastTick
        lastTick = now

        -- Progress time
        if not freezeTime then
            local minsPerHour = cfg.minutes_per_hour
            local multiplier = getTimeMultiplier()
            local effectiveMinsPerHour = minsPerHour * multiplier

            -- Convert: 1 in-game minute = (effectiveMinsPerHour / 60) real seconds
            -- So per real second, we advance (60 / effectiveMinsPerHour) in-game seconds
            -- which is (1 / effectiveMinsPerHour) in-game minutes per real second
            local igMinutesPerRealSec = 1.0 / effectiveMinsPerHour
            local igMinutesElapsed = (delta / 1000.0) * igMinutesPerRealSec

            timeAccumulator = timeAccumulator + igMinutesElapsed

            while timeAccumulator >= 1.0 do
                timeAccumulator = timeAccumulator - 1.0
                currentMinute = currentMinute + 1

                if currentMinute >= 60 then
                    currentMinute = 0
                    currentHour = currentHour + 1

                    if currentHour >= 24 then
                        currentHour = 0
                    end
                end
            end
        end

        -- Auto weather change
        if not freezeWeather and cfg.weather_change_interval > 0 then
            local elapsed = os.time() - lastWeatherChange
            if elapsed >= cfg.weather_change_interval * 60 then
                local newWeather = pickNextWeather()
                if newWeather ~= currentWeather then
                    currentWeather = newWeather
                    randomiseWind()

                    -- Check blackout flag
                    local def = cfg.weather_types[currentWeather]
                    if def and def.blackout then
                        blackout = true
                    elseif not blackout then
                        -- Don't override manual blackout
                    end
                end
                lastWeatherChange = os.time()
            end
        end
    end
end)

-- Broadcast sync every 5 seconds (lightweight)
CreateThread(function()
    while true do
        Wait(5000)
        broadcastSync()
    end
end)

-- =============================================
-- PLAYER JOIN SYNC
-- =============================================

RegisterNetEvent('hydra:weather:requestSync')
AddEventHandler('hydra:weather:requestSync', function()
    local src = source
    syncPlayer(src)
end)

-- =============================================
-- ADMIN COMMANDS
-- =============================================

local cmdCfg = cfg.commands
local perm = cfg.admin_permission

--- /weather [type] - Set or view weather
RegisterCommand(cmdCfg.weather, function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, perm) then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'error', title = 'No Permission',
            message = 'You do not have permission to change weather.',
        })
        return
    end

    if #args == 0 then
        -- List available weather types
        local list = {}
        for wType, def in pairs(cfg.weather_types) do
            list[#list + 1] = ('%s (%s)%s'):format(wType, def.label, wType == currentWeather and ' [ACTIVE]' or '')
        end
        table.sort(list)

        local msg = 'Current: ' .. currentWeather .. '\nAvailable: ' .. table.concat(list, ', ')
        if src > 0 then
            TriggerClientEvent('hydra:notify:show', src, {
                type = 'info', title = 'Weather', message = msg, duration = 8000,
            })
        else
            print('[Hydra Weather] ' .. msg)
        end
        return
    end

    local newWeather = args[1]:upper()
    if not cfg.weather_types[newWeather] then
        local msg = 'Invalid weather type: ' .. newWeather
        if src > 0 then
            TriggerClientEvent('hydra:notify:show', src, { type = 'error', title = 'Weather', message = msg })
        else
            print('[Hydra Weather] ' .. msg)
        end
        return
    end

    currentWeather = newWeather
    lastWeatherChange = os.time()
    randomiseWind()

    local def = cfg.weather_types[newWeather]
    if def and def.blackout then
        blackout = true
    end

    broadcastSync()

    local label = def and def.label or newWeather
    local name = src > 0 and GetPlayerName(src) or 'Console'
    Hydra.Utils.Log('info', '%s set weather to %s (%s)', name, newWeather, label)

    if src > 0 then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'success', title = 'Weather',
            message = ('Weather set to %s'):format(label),
        })
    else
        print(('[Hydra Weather] Weather set to %s (%s)'):format(newWeather, label))
    end
end, false)

--- /time [hour] [minute] - Set or view time
RegisterCommand(cmdCfg.time, function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, perm) then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'error', title = 'No Permission',
            message = 'You do not have permission to change time.',
        })
        return
    end

    if #args == 0 then
        local msg = ('Current time: %02d:%02d'):format(currentHour, currentMinute)
        if src > 0 then
            TriggerClientEvent('hydra:notify:show', src, { type = 'info', title = 'Time', message = msg })
        else
            print('[Hydra Weather] ' .. msg)
        end
        return
    end

    local hour = tonumber(args[1])
    local minute = tonumber(args[2]) or 0

    if not hour or hour < 0 or hour > 23 then
        local msg = 'Invalid hour. Use 0-23.'
        if src > 0 then
            TriggerClientEvent('hydra:notify:show', src, { type = 'error', title = 'Time', message = msg })
        else
            print('[Hydra Weather] ' .. msg)
        end
        return
    end

    if minute < 0 or minute > 59 then
        minute = 0
    end

    currentHour = math.floor(hour)
    currentMinute = math.floor(minute)
    timeAccumulator = 0.0

    broadcastSync()

    local name = src > 0 and GetPlayerName(src) or 'Console'
    Hydra.Utils.Log('info', '%s set time to %02d:%02d', name, currentHour, currentMinute)

    if src > 0 then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'success', title = 'Time',
            message = ('Time set to %02d:%02d'):format(currentHour, currentMinute),
        })
    else
        print(('[Hydra Weather] Time set to %02d:%02d'):format(currentHour, currentMinute))
    end
end, false)

--- /freezetime - Toggle time freeze
RegisterCommand(cmdCfg.freezetime, function(src)
    if src > 0 and not IsPlayerAceAllowed(src, perm) then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'error', title = 'No Permission',
            message = 'You do not have permission.',
        })
        return
    end

    freezeTime = not freezeTime
    broadcastSync()

    local state = freezeTime and 'frozen' or 'unfrozen'
    local name = src > 0 and GetPlayerName(src) or 'Console'
    Hydra.Utils.Log('info', '%s %s time', name, state)

    if src > 0 then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'info', title = 'Time', message = ('Time is now %s'):format(state),
        })
    else
        print(('[Hydra Weather] Time is now %s'):format(state))
    end
end, false)

--- /freezeweather - Toggle weather freeze
RegisterCommand(cmdCfg.freezeweather, function(src)
    if src > 0 and not IsPlayerAceAllowed(src, perm) then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'error', title = 'No Permission',
            message = 'You do not have permission.',
        })
        return
    end

    freezeWeather = not freezeWeather
    broadcastSync()

    local state = freezeWeather and 'frozen' or 'unfrozen'
    local name = src > 0 and GetPlayerName(src) or 'Console'
    Hydra.Utils.Log('info', '%s %s weather', name, state)

    if src > 0 then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'info', title = 'Weather', message = ('Weather is now %s'):format(state),
        })
    else
        print(('[Hydra Weather] Weather is now %s'):format(state))
    end
end, false)

--- /blackout - Toggle blackout mode
RegisterCommand(cmdCfg.blackout, function(src)
    if src > 0 and not IsPlayerAceAllowed(src, perm) then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'error', title = 'No Permission',
            message = 'You do not have permission.',
        })
        return
    end

    blackout = not blackout
    broadcastSync()

    local state = blackout and 'enabled' or 'disabled'
    local name = src > 0 and GetPlayerName(src) or 'Console'
    Hydra.Utils.Log('info', '%s %s blackout', name, state)

    if src > 0 then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'info', title = 'Blackout', message = ('Blackout %s'):format(state),
        })
    else
        print(('[Hydra Weather] Blackout %s'):format(state))
    end
end, false)

-- =============================================
-- MODULE REGISTRATION
-- =============================================

Hydra.Modules.Register('weather', {
    label = 'Hydra Weather',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 50,
    dependencies = {},

    onLoad = function()
        Hydra.Utils.Log('info', 'Weather module loaded - %s at %02d:%02d', currentWeather, currentHour, currentMinute)
    end,

    onPlayerJoin = function(src)
        syncPlayer(src)
    end,

    api = {
        GetWeather = function() return currentWeather end,
        GetTime = function() return currentHour, currentMinute end,
        SetWeather = function(w)
            if cfg.weather_types[w] then
                currentWeather = w
                lastWeatherChange = os.time()
                broadcastSync()
                return true
            end
            return false
        end,
        SetTime = function(h, m)
            currentHour = math.floor(h) % 24
            currentMinute = math.floor(m or 0) % 60
            timeAccumulator = 0.0
            broadcastSync()
        end,
        SetFreezeTime = function(state) freezeTime = state; broadcastSync() end,
        SetFreezeWeather = function(state) freezeWeather = state; broadcastSync() end,
        SetBlackout = function(state) blackout = state; broadcastSync() end,
        IsTimeFrozen = function() return freezeTime end,
        IsWeatherFrozen = function() return freezeWeather end,
        IsBlackout = function() return blackout end,
    },
})

-- Server exports
exports('GetWeather', function() return currentWeather end)
exports('GetTime', function() return currentHour, currentMinute end)
exports('SetWeather', function(w)
    if cfg.weather_types[w] then
        currentWeather = w
        lastWeatherChange = os.time()
        broadcastSync()
        return true
    end
    return false
end)
exports('SetTime', function(h, m)
    currentHour = math.floor(h) % 24
    currentMinute = math.floor(m or 0) % 60
    timeAccumulator = 0.0
    broadcastSync()
end)
exports('SetFreezeTime', function(state) freezeTime = state; broadcastSync() end)
exports('SetFreezeWeather', function(state) freezeWeather = state; broadcastSync() end)
exports('SetBlackout', function(state) blackout = state; broadcastSync() end)
