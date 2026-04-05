--[[
    Hydra Audio - Client Main

    Centralized audio management system. Handles GTA native sounds,
    custom NUI-based audio (HTML5), 3D spatial audio, ambient soundscapes,
    and volume management with cascading volume control.
]]

Hydra = Hydra or {}
Hydra.Audio = Hydra.Audio or {}

-- ---------------------------------------------------------------------------
-- Localize hot-path functions
-- ---------------------------------------------------------------------------
local type = type
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local math_min = math.min
local math_max = math.max
local math_sqrt = math.sqrt
local table_insert = table.insert
local table_remove = table.remove
local GetGameTimer = GetGameTimer

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------
local cfg = HydraConfig.Audio
local activeSounds = {}      -- { [id] = { type='native', soundRef, soundSet, name, category, startTime, loop } }
local activeCustom = {}      -- { [id] = { category, startTime, loop, url } }
local ambientSounds = {}     -- { [id] = { zone, soundId, active } }
local soundCounter = 0
local masterVolume = cfg.master_volume
local categoryVolumes = {}
local soundbanks = {}
local hooksPlay = {}
local hooksStop = {}

-- Initialize category volumes from config
for cat, vol in pairs(cfg.categories) do
    categoryVolumes[cat] = vol
end

-- Pre-register configured soundbanks
for _, bank in ipairs(cfg.soundbanks) do
    if bank.name and bank.sounds then
        soundbanks[bank.name] = bank.sounds
    end
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Generate a sequential sound ID
--- @return string
local function nextId()
    soundCounter = soundCounter + 1
    return 'snd_' .. soundCounter
end

--- Debug log helper
--- @param msg string
local function debugLog(msg, ...)
    if cfg.debug then
        Hydra.Utils.Log('debug', '[Audio] ' .. msg, ...)
    end
end

--- Get effective volume for a category
--- @param category string
--- @return number
local function getCategoryMult(category)
    return categoryVolumes[category or 'sfx'] or 1.0
end

--- Compute final volume: base * category * master
--- @param base number
--- @param category string
--- @return number clamped 0-1
local function computeVolume(base, category)
    return math_min(1.0, math_max(0.0, (base or 1.0) * getCategoryMult(category) * masterVolume))
end

--- Count total active sounds (native + custom)
--- @param category string|nil
--- @return number
local function countActive(category)
    local count = 0
    for _, s in pairs(activeSounds) do
        if not category or s.category == category then
            count = count + 1
        end
    end
    for _, s in pairs(activeCustom) do
        if not category or s.category == category then
            count = count + 1
        end
    end
    return count
end

--- Enforce max concurrent sounds — evict oldest non-looping sound
local function enforceLimit()
    local total = countActive()
    if total < cfg.max_concurrent_sounds then return end

    -- Find oldest non-looping sound
    local oldestId, oldestTime = nil, math.huge
    for id, s in pairs(activeSounds) do
        if not s.loop and s.startTime < oldestTime then
            oldestId, oldestTime = id, s.startTime
        end
    end
    if not oldestId then
        for id, s in pairs(activeCustom) do
            if not s.loop and s.startTime < oldestTime then
                oldestId, oldestTime = id, s.startTime
            end
        end
    end

    if oldestId then
        debugLog('Evicting sound %s (limit reached)', oldestId)
        Hydra.Audio.Stop(oldestId)
    end
end

--- Fire play hooks
--- @param id string
--- @param data table
local function firePlayHooks(id, data)
    for _, hook in ipairs(hooksPlay) do
        pcall(hook, id, data)
    end
end

--- Fire stop hooks
--- @param id string
local function fireStopHooks(id)
    for _, hook in ipairs(hooksStop) do
        pcall(hook, id)
    end
end

-- ---------------------------------------------------------------------------
-- Native GTA Sound API
-- ---------------------------------------------------------------------------

--- Play a GTA native frontend sound
--- @param name string Sound name
--- @param soundSet string Sound set name
--- @param category string|nil Volume category (default 'ui')
--- @return string soundId
function Hydra.Audio.PlayFrontend(name, soundSet, category)
    if not cfg.enabled then return '' end
    enforceLimit()

    category = category or 'ui'
    local id = nextId()

    PlaySoundFrontend(-1, name, soundSet, false)
    local ref = GetSoundId()

    activeSounds[id] = {
        type = 'native',
        soundRef = ref,
        soundSet = soundSet,
        name = name,
        category = category,
        startTime = GetGameTimer(),
        loop = false,
    }

    debugLog('PlayFrontend: %s/%s -> %s', soundSet, name, id)
    firePlayHooks(id, { type = 'frontend', name = name, soundSet = soundSet, category = category })
    return id
end

--- Play a GTA native sound at world coordinates (3D spatial)
--- @param name string Sound name
--- @param soundSet string Sound set name
--- @param coords vector3 World position
--- @param range number|nil Audio range in metres
--- @param category string|nil Volume category (default 'sfx')
--- @return string soundId
function Hydra.Audio.PlayAtCoord(name, soundSet, coords, range, category)
    if not cfg.enabled then return '' end
    enforceLimit()

    category = category or 'sfx'
    range = range or cfg.spatial_falloff
    local id = nextId()
    local ref = GetSoundId()

    PlaySoundFromCoord(ref, name, coords.x, coords.y, coords.z, soundSet, false, range, false)

    activeSounds[id] = {
        type = 'native',
        soundRef = ref,
        soundSet = soundSet,
        name = name,
        category = category,
        startTime = GetGameTimer(),
        loop = false,
        coords = coords,
    }

    debugLog('PlayAtCoord: %s/%s at (%.1f,%.1f,%.1f) -> %s', soundSet, name, coords.x, coords.y, coords.z, id)
    firePlayHooks(id, { type = 'coord', name = name, soundSet = soundSet, coords = coords, category = category })
    return id
end

--- Play a GTA native sound on an entity
--- @param name string Sound name
--- @param soundSet string Sound set name
--- @param entity number Entity handle
--- @param category string|nil Volume category (default 'sfx')
--- @return string soundId
function Hydra.Audio.PlayOnEntity(name, soundSet, entity, category)
    if not cfg.enabled then return '' end
    enforceLimit()

    category = category or 'sfx'
    local id = nextId()
    local ref = GetSoundId()

    PlaySoundFromEntity(ref, name, entity, soundSet, false, 0)

    activeSounds[id] = {
        type = 'native',
        soundRef = ref,
        soundSet = soundSet,
        name = name,
        category = category,
        startTime = GetGameTimer(),
        loop = false,
        entity = entity,
    }

    debugLog('PlayOnEntity: %s/%s on entity %d -> %s', soundSet, name, entity, id)
    firePlayHooks(id, { type = 'entity', name = name, soundSet = soundSet, entity = entity, category = category })
    return id
end

-- ---------------------------------------------------------------------------
-- Custom Sound API (NUI / HTML5 Audio)
-- ---------------------------------------------------------------------------

--- Play a custom sound via NUI HTML5 Audio
--- @param url string Sound file URL (relative to resource or absolute)
--- @param options table|nil { volume, loop, category, fadeIn, id }
--- @return string soundId
function Hydra.Audio.PlayCustom(url, options)
    if not cfg.enabled then return '' end
    enforceLimit()

    options = options or {}
    local category = options.category or 'sfx'
    local volume = options.volume or 1.0
    local loop = options.loop or false
    local fadeIn = options.fadeIn
    local id = options.id or nextId()

    -- If a custom sound with this id is already playing, stop it first
    if activeCustom[id] then
        Hydra.Audio.Stop(id)
    end

    activeCustom[id] = {
        category = category,
        startTime = GetGameTimer(),
        loop = loop,
        url = url,
        baseVolume = volume,
    }

    SendNUIMessage({
        action = 'play',
        id = id,
        url = url,
        volume = computeVolume(volume, category),
        loop = loop,
        category = category,
        fadeIn = fadeIn,
    })

    debugLog('PlayCustom: %s -> %s (vol=%.2f, loop=%s)', url, id, volume, tostring(loop))
    firePlayHooks(id, { type = 'custom', url = url, category = category, volume = volume, loop = loop })
    return id
end

--- Play a sound from a registered soundbank
--- @param bankName string Soundbank name
--- @param soundName string Sound key within the bank
--- @param options table|nil Same options as PlayCustom
--- @return string soundId
function Hydra.Audio.PlayBank(bankName, soundName, options)
    local bank = soundbanks[bankName]
    if not bank then
        debugLog('PlayBank: unknown bank "%s"', bankName)
        return ''
    end

    local file = bank[soundName]
    if not file then
        debugLog('PlayBank: unknown sound "%s" in bank "%s"', soundName, bankName)
        return ''
    end

    return Hydra.Audio.PlayCustom(file, options)
end

-- ---------------------------------------------------------------------------
-- Stop / Pause / Resume
-- ---------------------------------------------------------------------------

--- Stop a sound by ID, with optional fade-out
--- @param soundId string
--- @param fadeOut number|nil Fade-out duration in ms
function Hydra.Audio.Stop(soundId, fadeOut)
    if not soundId or soundId == '' then return end

    -- Native GTA sound
    local native = activeSounds[soundId]
    if native then
        StopSound(native.soundRef)
        ReleaseSoundId(native.soundRef)
        activeSounds[soundId] = nil
        debugLog('Stop native: %s', soundId)
        fireStopHooks(soundId)
        return
    end

    -- Custom NUI sound
    local custom = activeCustom[soundId]
    if custom then
        SendNUIMessage({
            action = 'stop',
            id = soundId,
            fadeOut = fadeOut,
        })
        -- If no fade, remove tracking immediately; fade cleanup handled by audioEnded callback
        if not fadeOut or fadeOut <= 0 then
            activeCustom[soundId] = nil
            fireStopHooks(soundId)
        end
        debugLog('Stop custom: %s (fade=%s)', soundId, tostring(fadeOut))
        return
    end

    -- Ambient sound
    local ambient = ambientSounds[soundId]
    if ambient then
        Hydra.Audio.StopAmbient(soundId, fadeOut)
    end
end

--- Stop all sounds, optionally filtered by category
--- @param category string|nil Category filter
--- @param fadeOut number|nil Fade-out duration in ms
function Hydra.Audio.StopAll(category, fadeOut)
    -- Stop native sounds
    for id, s in pairs(activeSounds) do
        if not category or s.category == category then
            StopSound(s.soundRef)
            ReleaseSoundId(s.soundRef)
            activeSounds[id] = nil
            fireStopHooks(id)
        end
    end

    -- Stop custom sounds via NUI
    SendNUIMessage({
        action = 'stopAll',
        category = category,
        fadeOut = fadeOut,
    })

    if not fadeOut or fadeOut <= 0 then
        for id, s in pairs(activeCustom) do
            if not category or s.category == category then
                activeCustom[id] = nil
                fireStopHooks(id)
            end
        end
    end

    debugLog('StopAll (category=%s, fade=%s)', tostring(category), tostring(fadeOut))
end

--- Pause a custom sound
--- @param soundId string
function Hydra.Audio.Pause(soundId)
    if activeCustom[soundId] then
        SendNUIMessage({ action = 'pause', id = soundId })
        debugLog('Pause: %s', soundId)
    end
end

--- Resume a paused custom sound
--- @param soundId string
function Hydra.Audio.Resume(soundId)
    if activeCustom[soundId] then
        SendNUIMessage({ action = 'resume', id = soundId })
        debugLog('Resume: %s', soundId)
    end
end

-- ---------------------------------------------------------------------------
-- Volume Control
-- ---------------------------------------------------------------------------

--- Set volume of an active custom sound
--- @param soundId string
--- @param volume number 0.0 to 1.0
function Hydra.Audio.SetVolume(soundId, volume)
    local custom = activeCustom[soundId]
    if custom then
        custom.baseVolume = volume
        SendNUIMessage({
            action = 'setVolume',
            id = soundId,
            volume = computeVolume(volume, custom.category),
        })
    end
end

--- Fade a custom sound between two volumes
--- @param soundId string
--- @param fromVol number
--- @param toVol number
--- @param durationMs number
function Hydra.Audio.Fade(soundId, fromVol, toVol, durationMs)
    if activeCustom[soundId] then
        SendNUIMessage({
            action = 'fade',
            id = soundId,
            from = fromVol,
            to = toVol,
            duration = durationMs or cfg.fade_default_duration,
        })
    end
end

--- Set master volume (0.0 to 1.0)
--- @param volume number
function Hydra.Audio.SetMasterVolume(volume)
    masterVolume = math_min(1.0, math_max(0.0, volume))
    SendNUIMessage({ action = 'setMasterVolume', volume = masterVolume })
    debugLog('Master volume set to %.2f', masterVolume)
end

--- Get current master volume
--- @return number
function Hydra.Audio.GetMasterVolume()
    return masterVolume
end

--- Set category volume (0.0 to 1.0)
--- @param category string
--- @param volume number
function Hydra.Audio.SetCategoryVolume(category, volume)
    categoryVolumes[category] = math_min(1.0, math_max(0.0, volume))
    SendNUIMessage({ action = 'setCategoryVolume', category = category, volume = categoryVolumes[category] })
    debugLog('Category "%s" volume set to %.2f', category, categoryVolumes[category])
end

--- Get category volume
--- @param category string
--- @return number
function Hydra.Audio.GetCategoryVolume(category)
    return categoryVolumes[category] or 1.0
end

-- ---------------------------------------------------------------------------
-- Ambient Zone Management
-- ---------------------------------------------------------------------------

--- Start an ambient sound (typically looping, proximity-based)
--- @param name string Ambient identifier
--- @param options table { url, soundName, soundSet, coords, radius, volume, category, fadeIn, loop }
--- @return string ambientId
function Hydra.Audio.StartAmbient(name, options)
    if not cfg.enabled then return '' end

    -- Enforce ambient limit
    local ambientCount = 0
    for _ in pairs(ambientSounds) do ambientCount = ambientCount + 1 end
    if ambientCount >= cfg.max_concurrent_ambient then
        debugLog('Ambient limit reached (%d), cannot start "%s"', cfg.max_concurrent_ambient, name)
        return ''
    end

    options = options or {}
    local category = options.category or 'ambient'
    local volume = options.volume or 0.5
    local loop = options.loop ~= false -- default true
    local fadeIn = options.fadeIn or cfg.fade_default_duration
    local id = 'amb_' .. name

    -- Stop existing ambient with same name
    if ambientSounds[id] then
        Hydra.Audio.StopAmbient(id)
    end

    local soundId
    if options.url then
        soundId = Hydra.Audio.PlayCustom(options.url, {
            volume = volume,
            loop = loop,
            category = category,
            fadeIn = fadeIn,
            id = id .. '_snd',
        })
    elseif options.soundName and options.soundSet then
        if options.coords then
            soundId = Hydra.Audio.PlayAtCoord(options.soundName, options.soundSet, options.coords, options.radius, category)
        else
            soundId = Hydra.Audio.PlayFrontend(options.soundName, options.soundSet, category)
        end
    else
        debugLog('StartAmbient: "%s" missing url or native sound info', name)
        return ''
    end

    ambientSounds[id] = {
        zone = name,
        soundId = soundId,
        active = true,
        options = options,
    }

    debugLog('StartAmbient: "%s" -> %s', name, id)
    return id
end

--- Stop an ambient sound
--- @param ambientId string
--- @param fadeOut number|nil Fade-out duration in ms
function Hydra.Audio.StopAmbient(ambientId, fadeOut)
    local ambient = ambientSounds[ambientId]
    if not ambient then return end

    fadeOut = fadeOut or cfg.fade_default_duration

    if ambient.soundId and ambient.soundId ~= '' then
        Hydra.Audio.Stop(ambient.soundId, fadeOut)
    end

    ambientSounds[ambientId] = nil
    debugLog('StopAmbient: %s', ambientId)
end

--- Stop all ambient sounds
--- @param fadeOut number|nil Fade-out duration in ms
function Hydra.Audio.StopAllAmbient(fadeOut)
    for id in pairs(ambientSounds) do
        Hydra.Audio.StopAmbient(id, fadeOut)
    end
    debugLog('StopAllAmbient')
end

-- ---------------------------------------------------------------------------
-- Query API
-- ---------------------------------------------------------------------------

--- Check if a sound is currently playing
--- @param soundId string
--- @return boolean
function Hydra.Audio.IsPlaying(soundId)
    return activeSounds[soundId] ~= nil or activeCustom[soundId] ~= nil
end

--- Get count of active sounds, optionally by category
--- @param category string|nil
--- @return number
function Hydra.Audio.GetActiveCount(category)
    return countActive(category)
end

--- Register a soundbank at runtime
--- @param name string Bank name
--- @param sounds table { [soundName] = 'file.ogg', ... }
function Hydra.Audio.RegisterBank(name, sounds)
    soundbanks[name] = sounds
    debugLog('RegisterBank: "%s" with %d sounds', name, Hydra.Utils and #sounds or 0)
end

-- ---------------------------------------------------------------------------
-- Hooks
-- ---------------------------------------------------------------------------

--- Register a callback that fires when any sound starts playing
--- @param callback function(soundId, data)
function Hydra.Audio.OnPlay(callback)
    if type(callback) == 'function' then
        table_insert(hooksPlay, callback)
    end
end

--- Register a callback that fires when any sound stops
--- @param callback function(soundId)
function Hydra.Audio.OnStop(callback)
    if type(callback) == 'function' then
        table_insert(hooksStop, callback)
    end
end

-- ---------------------------------------------------------------------------
-- NUI Callbacks
-- ---------------------------------------------------------------------------

--- Handle NUI notification that a custom sound ended naturally
RegisterNUICallback('audioEnded', function(data, cb)
    local id = data.id
    if activeCustom[id] then
        activeCustom[id] = nil
        debugLog('audioEnded (NUI): %s', id)
        fireStopHooks(id)
    end
    cb('ok')
end)

-- ---------------------------------------------------------------------------
-- Server Events
-- ---------------------------------------------------------------------------

--- Server requests client to play a frontend sound
RegisterNetEvent('hydra:audio:playClient')
AddEventHandler('hydra:audio:playClient', function(data)
    if not data then return end

    if data.type == 'frontend' then
        Hydra.Audio.PlayFrontend(data.name, data.soundSet, data.category)
    elseif data.type == 'custom' then
        Hydra.Audio.PlayCustom(data.url, data.options)
    elseif data.type == 'coord' then
        Hydra.Audio.PlayAtCoord(data.name, data.soundSet, data.coords, data.range, data.category)
    end
end)

--- Server requests client to stop all sounds
RegisterNetEvent('hydra:audio:stopClient')
AddEventHandler('hydra:audio:stopClient', function(data)
    if not data then
        Hydra.Audio.StopAll(nil, cfg.fade_default_duration)
        return
    end
    if data.soundId then
        Hydra.Audio.Stop(data.soundId, data.fadeOut)
    else
        Hydra.Audio.StopAll(data.category, data.fadeOut)
    end
end)

-- ---------------------------------------------------------------------------
-- Ambient Zone Auto-Play Thread
-- ---------------------------------------------------------------------------

--- Proximity-based ambient zone management
--- Checks player distance to configured ambient_zones and auto-starts/stops
CreateThread(function()
    -- Wait for framework readiness
    while not Hydra.IsReady() do Wait(100) end

    if #cfg.ambient_zones == 0 then return end

    local activeZones = {} -- { [zoneName] = ambientId }

    while true do
        Wait(1000)

        if not cfg.enabled then goto continue end

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        for _, zone in ipairs(cfg.ambient_zones) do
            local dist = #(pos - zone.coords)
            local isInRange = dist <= (zone.radius or 50.0)
            local wasActive = activeZones[zone.name] ~= nil

            if isInRange and not wasActive then
                -- Enter zone: start ambient sound
                local ambId = Hydra.Audio.StartAmbient(zone.name, {
                    url = zone.sound,
                    coords = zone.coords,
                    radius = zone.radius,
                    volume = zone.volume or 0.3,
                    category = zone.category or 'ambient',
                    fadeIn = cfg.fade_default_duration,
                    loop = true,
                })
                activeZones[zone.name] = ambId
                debugLog('Ambient zone entered: "%s"', zone.name)
            elseif not isInRange and wasActive then
                -- Leave zone: stop ambient sound
                Hydra.Audio.StopAmbient(activeZones[zone.name], cfg.fade_default_duration)
                activeZones[zone.name] = nil
                debugLog('Ambient zone left: "%s"', zone.name)
            end
        end

        ::continue::
    end
end)

-- ---------------------------------------------------------------------------
-- Cleanup Thread
-- ---------------------------------------------------------------------------

--- Periodic cleanup of stale sound entries
CreateThread(function()
    while not Hydra.IsReady() do Wait(100) end

    while true do
        Wait(cfg.cleanup_interval)

        if not cfg.enabled then goto continue end

        local now = GetGameTimer()

        -- Clean up native sounds that may have ended without notification
        -- Native one-shot sounds typically last a few seconds; consider stale after 30s
        for id, s in pairs(activeSounds) do
            if not s.loop and (now - s.startTime > 30000) then
                -- Check if sound has actually finished via native
                if HasSoundFinished(s.soundRef) then
                    ReleaseSoundId(s.soundRef)
                    activeSounds[id] = nil
                    debugLog('Cleanup stale native: %s', id)
                    fireStopHooks(id)
                end
            end
        end

        ::continue::
    end
end)

-- ---------------------------------------------------------------------------
-- Resource Cleanup
-- ---------------------------------------------------------------------------

--- Clean up all sounds when this resource stops
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Release all native sounds
    for id, s in pairs(activeSounds) do
        StopSound(s.soundRef)
        ReleaseSoundId(s.soundRef)
    end
    activeSounds = {}

    -- Stop all custom sounds
    SendNUIMessage({ action = 'stopAll' })
    activeCustom = {}

    -- Clear ambient
    ambientSounds = {}
end)

-- ---------------------------------------------------------------------------
-- Exports
-- ---------------------------------------------------------------------------

exports('PlayFrontend', function(...) return Hydra.Audio.PlayFrontend(...) end)
exports('PlayAtCoord', function(...) return Hydra.Audio.PlayAtCoord(...) end)
exports('PlayOnEntity', function(...) return Hydra.Audio.PlayOnEntity(...) end)
exports('PlayCustom', function(...) return Hydra.Audio.PlayCustom(...) end)
exports('PlayBank', function(...) return Hydra.Audio.PlayBank(...) end)
exports('Stop', function(...) return Hydra.Audio.Stop(...) end)
exports('StopAll', function(...) return Hydra.Audio.StopAll(...) end)
exports('Pause', function(...) return Hydra.Audio.Pause(...) end)
exports('Resume', function(...) return Hydra.Audio.Resume(...) end)
exports('SetVolume', function(...) return Hydra.Audio.SetVolume(...) end)
exports('Fade', function(...) return Hydra.Audio.Fade(...) end)
exports('SetMasterVolume', function(...) return Hydra.Audio.SetMasterVolume(...) end)
exports('GetMasterVolume', function() return Hydra.Audio.GetMasterVolume() end)
exports('SetCategoryVolume', function(...) return Hydra.Audio.SetCategoryVolume(...) end)
exports('GetCategoryVolume', function(...) return Hydra.Audio.GetCategoryVolume(...) end)
exports('StartAmbient', function(...) return Hydra.Audio.StartAmbient(...) end)
exports('StopAmbient', function(...) return Hydra.Audio.StopAmbient(...) end)
exports('StopAllAmbient', function(...) return Hydra.Audio.StopAllAmbient(...) end)
exports('IsPlaying', function(...) return Hydra.Audio.IsPlaying(...) end)
exports('GetActiveCount', function(...) return Hydra.Audio.GetActiveCount(...) end)
exports('RegisterBank', function(...) return Hydra.Audio.RegisterBank(...) end)
exports('OnPlay', function(...) return Hydra.Audio.OnPlay(...) end)
exports('OnStop', function(...) return Hydra.Audio.OnStop(...) end)
