--[[
    Hydra Anims - Client

    Centralized animation engine: dict caching with LRU eviction,
    animation playback with priority, queuing, prop management,
    scenario support, hooks, and completion monitoring.
]]

Hydra = Hydra or {}
Hydra.Anims = {}

local cfg = HydraConfig.Anims

-- =============================================
-- INTERNAL STATE
-- =============================================

local dictCache    = {} -- { [dict] = { refCount, lastUsed, loaded } }
local activeAnims  = {} -- { [ped] = { animId, dict, anim, label, priority, startTime, duration, props, lockControl, lockPosition, onEnd, onStart, scenario } }
local animQueue    = {} -- { [ped] = { {options}, ... } }
local managedProps = {} -- { [ped] = { entity, ... } }
local hooksBefore  = {} -- pre-play hooks
local hooksAfter   = {} -- post-play hooks
local hooksCancel  = {} -- on-cancel hooks

local animCounter = 0

-- =============================================
-- DEBUG LOGGING
-- =============================================

local function dbg(msg, ...)
    if cfg.debug then
        print(('[Hydra Anims] ' .. msg):format(...))
    end
end

-- =============================================
-- LRU EVICTION
-- =============================================

local function evictLRU()
    local oldest = nil
    local oldestTime = math.huge

    for dict, entry in pairs(dictCache) do
        if entry.refCount <= 0 and entry.lastUsed < oldestTime then
            oldest = dict
            oldestTime = entry.lastUsed
        end
    end

    if oldest then
        dbg('Evicting dict from cache: %s', oldest)
        RemoveAnimDict(oldest)
        dictCache[oldest] = nil
    end
end

local function getCacheCount()
    local count = 0
    for _ in pairs(dictCache) do count = count + 1 end
    return count
end

-- =============================================
-- DICT CACHING
-- =============================================

--- Load an animation dictionary (cached, ref-counted)
--- @param dict string
--- @return boolean success
function Hydra.Anims.LoadDict(dict)
    if not dict or dict == '' then return false end

    local entry = dictCache[dict]
    if entry and entry.loaded then
        entry.refCount = entry.refCount + 1
        entry.lastUsed = GetGameTimer()
        dbg('Dict cache hit: %s (refCount=%d)', dict, entry.refCount)
        return true
    end

    RequestAnimDict(dict)
    local t = 0
    local timeout = cfg.dict_timeout
    while not HasAnimDictLoaded(dict) and t < timeout do
        Wait(10)
        t = t + 10
    end

    if not HasAnimDictLoaded(dict) then
        dbg('Dict load failed: %s (timeout %dms)', dict, timeout)
        return false
    end

    -- Evict if cache full
    if getCacheCount() >= cfg.dict_cache_size then
        evictLRU()
    end

    dictCache[dict] = { refCount = 1, lastUsed = GetGameTimer(), loaded = true }
    dbg('Dict loaded and cached: %s', dict)
    return true
end

--- Release a dictionary reference
--- @param dict string
function Hydra.Anims.ReleaseDict(dict)
    local entry = dictCache[dict]
    if not entry then return end

    entry.refCount = math.max(0, entry.refCount - 1)
    dbg('Dict released: %s (refCount=%d)', dict, entry.refCount)
end

-- =============================================
-- PROP MANAGEMENT
-- =============================================

local function spawnAndAttachProp(ped, def)
    local model = type(def.model) == 'string' and GetHashKey(def.model) or def.model
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 3000 do
        Wait(10)
        t = t + 10
    end
    if not HasModelLoaded(model) then
        dbg('Prop model load failed: %s', tostring(def.model))
        return nil
    end

    local coords = GetEntityCoords(ped)
    local prop = CreateObject(model, coords.x, coords.y, coords.z, def.isNetwork or false, true, false)
    local bone = GetPedBoneIndex(ped, def.bone or 57005)
    local offset = def.offset or vector3(0.0, 0.0, 0.0)
    local rotation = def.rotation or vector3(0.0, 0.0, 0.0)

    AttachEntityToEntity(prop, ped, bone,
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        true, true, false, true, 1, true)

    SetModelAsNoLongerNeeded(model)

    -- Track in managedProps
    if not managedProps[ped] then managedProps[ped] = {} end
    managedProps[ped][#managedProps[ped] + 1] = prop

    dbg('Prop attached to ped %d: entity=%d model=%s', ped, prop, tostring(def.model))
    return prop
end

local function cleanupProps(ped, props, delay)
    if not props or #props == 0 then return end

    CreateThread(function()
        if delay and delay > 0 then
            Wait(delay)
        end
        for _, prop in ipairs(props) do
            if DoesEntityExist(prop) then
                DetachEntity(prop, true, true)
                DeleteEntity(prop)
            end
        end
        -- Remove from managed tracking
        if managedProps[ped] then
            for _, prop in ipairs(props) do
                for i = #managedProps[ped], 1, -1 do
                    if managedProps[ped][i] == prop then
                        table.remove(managedProps[ped], i)
                        break
                    end
                end
            end
            if #managedProps[ped] == 0 then
                managedProps[ped] = nil
            end
        end
    end)
end

--- Attach a prop to a ped (standalone, not tied to animation)
--- @param ped number
--- @param options table { model, bone, offset, rotation, isNetwork }
--- @return number|nil propEntity
function Hydra.Anims.AttachProp(ped, options)
    if not ped or not options or not options.model then return nil end
    return spawnAndAttachProp(ped, options)
end

--- Detach and delete a prop entity
--- @param propEntity number
function Hydra.Anims.DetachProp(propEntity)
    if not propEntity or not DoesEntityExist(propEntity) then return end
    DetachEntity(propEntity, true, true)
    DeleteEntity(propEntity)

    -- Remove from tracking
    for ped, props in pairs(managedProps) do
        for i = #props, 1, -1 do
            if props[i] == propEntity then
                table.remove(props, i)
                if #props == 0 then managedProps[ped] = nil end
                return
            end
        end
    end
end

--- Detach and delete all managed props from a ped
--- @param ped number
function Hydra.Anims.DetachAllProps(ped)
    local props = managedProps[ped]
    if not props then return end

    for i = #props, 1, -1 do
        local prop = props[i]
        if DoesEntityExist(prop) then
            DetachEntity(prop, true, true)
            DeleteEntity(prop)
        end
    end
    managedProps[ped] = nil
end

-- =============================================
-- INTERNAL ANIMATION LIFECYCLE
-- =============================================

local function generateAnimId()
    animCounter = animCounter + 1
    return 'anim_' .. animCounter
end

local function finishAnim(ped, data, cancelled)
    if not data then return end
    dbg('Finishing anim %s on ped %d (cancelled=%s)', data.animId, ped, tostring(cancelled))

    -- Release dict
    if data.dict then
        Hydra.Anims.ReleaseDict(data.dict)
    end

    -- Cleanup props
    if data.props and #data.props > 0 then
        cleanupProps(ped, data.props, cfg.prop_cleanup_delay)
    end

    -- Unlock controls
    if data.lockControl then
        FreezeEntityPosition(ped, false)
    end
    if data.lockPosition then
        FreezeEntityPosition(ped, false)
    end

    -- Clear from active
    if activeAnims[ped] and activeAnims[ped].animId == data.animId then
        activeAnims[ped] = nil
    end

    -- Fire onEnd callback
    if data.onEnd then
        data.onEnd(ped, data.animId, cancelled)
    end

    -- Fire after hooks
    for _, hook in ipairs(hooksAfter) do
        hook(ped, data.animId, cancelled)
    end

    -- Fire cancel hooks
    if cancelled then
        for _, hook in ipairs(hooksCancel) do
            hook(ped, data.animId)
        end
    end

    -- Sync to server
    if cfg.sync_to_server then
        TriggerServerEvent('hydra:anims:syncState', nil)
    end
end

local function stopInternal(ped, data, cancelled)
    if not data then return end

    if data.scenario then
        ClearPedTasks(ped)
    elseif data.dict and data.anim then
        local blendOut = data.blendOut or cfg.default_blend_out
        StopAnimTask(ped, data.dict, data.anim, math.abs(blendOut))
    else
        ClearPedTasks(ped)
    end

    finishAnim(ped, data, cancelled)
end

local function processQueue(ped)
    local queue = animQueue[ped]
    if not queue or #queue == 0 then return end

    local nextOpts = table.remove(queue, 1)
    if #queue == 0 then animQueue[ped] = nil end

    dbg('Processing queue for ped %d, %d remaining', ped, animQueue[ped] and #animQueue[ped] or 0)
    Hydra.Anims.Play(ped, nextOpts)
end

local function monitorCompletion(ped, animId, data)
    CreateThread(function()
        local startTime = GetGameTimer()
        local duration = data.duration

        while true do
            Wait(100)
            local current = activeAnims[ped]
            if not current or current.animId ~= animId then return end

            if data.scenario then
                -- Scenarios run until stopped, no auto-completion
                if not IsPedUsingScenario(ped, data.scenario) then
                    finishAnim(ped, current, false)
                    processQueue(ped)
                    return
                end
            else
                -- Check if anim finished naturally
                if not IsEntityPlayingAnim(ped, current.dict, current.anim, 3) then
                    finishAnim(ped, current, false)
                    processQueue(ped)
                    return
                end

                -- Timeout safety for timed animations
                if duration and duration > 0 and GetGameTimer() - startTime > duration + 1000 then
                    finishAnim(ped, current, false)
                    processQueue(ped)
                    return
                end
            end
        end
    end)
end

local function playScenarioInternal(ped, options)
    local animId = generateAnimId()

    local data = {
        animId = animId,
        scenario = options.scenario,
        label = options.label,
        priority = options.priority or 1,
        startTime = GetGameTimer(),
        duration = -1,
        props = {},
        lockControl = options.lockControl,
        lockPosition = options.lockPosition,
        onEnd = options.onEnd,
        onStart = options.onStart,
    }

    -- Lock controls
    if options.lockControl then
        FreezeEntityPosition(ped, true)
    end

    TaskStartScenarioInPlace(ped, options.scenario, 0, true)

    activeAnims[ped] = data

    -- Sync to server
    if cfg.sync_to_server then
        TriggerServerEvent('hydra:anims:syncState', {
            animId = animId,
            scenario = options.scenario,
            label = options.label,
        })
    end

    -- Fire onStart
    if options.onStart then
        options.onStart(ped, animId)
    end

    -- Monitor for scenario end
    monitorCompletion(ped, animId, data)

    dbg('Playing scenario %s on ped %d (id=%s)', options.scenario, ped, animId)
    return animId
end

-- =============================================
-- CORE API
-- =============================================

--- Play an animation on a ped
--- @param ped number
--- @param options table
--- @return string|nil animId
function Hydra.Anims.Play(ped, options)
    if not cfg.enabled then return nil end
    if not ped or not DoesEntityExist(ped) then return nil end
    if not options then return nil end

    -- Validate: need either dict+anim or scenario
    if not options.scenario and (not options.dict or not options.anim) then
        dbg('Play called with missing dict/anim/scenario')
        return nil
    end

    -- Run before hooks (may modify options or cancel)
    for _, hook in ipairs(hooksBefore) do
        if hook(ped, options) == false then
            dbg('Play cancelled by before hook')
            return nil
        end
    end

    -- Priority check against current animation
    local current = activeAnims[ped]
    if current then
        local newPriority = options.priority or 1
        local curPriority = current.priority or 1
        if newPriority < curPriority then
            dbg('Play rejected: priority %d < current %d', newPriority, curPriority)
            return nil
        end
        stopInternal(ped, current, true)
    end

    -- Scenario path
    if options.scenario then
        return playScenarioInternal(ped, options)
    end

    -- Load dict
    if not Hydra.Anims.LoadDict(options.dict) then
        dbg('Play failed: could not load dict %s', options.dict)
        return nil
    end

    local animId = generateAnimId()

    -- Spawn props
    local props = {}
    if options.props then
        for _, propDef in ipairs(options.props) do
            local prop = spawnAndAttachProp(ped, propDef)
            if prop then props[#props + 1] = prop end
        end
    end

    -- Lock controls
    if options.lockControl then
        FreezeEntityPosition(ped, true)
    end
    if options.lockPosition then
        FreezeEntityPosition(ped, true)
    end

    -- Play
    local flag = options.flag or cfg.default_flag
    local duration = options.duration or -1
    local blendIn = options.blendIn or cfg.default_blend_in
    local blendOut = options.blendOut or cfg.default_blend_out

    TaskPlayAnim(ped, options.dict, options.anim,
        blendIn, blendOut, duration, flag,
        options.startPhase or 0.0, false, false, false)

    if options.playbackRate and options.playbackRate ~= 1.0 then
        SetEntityAnimSpeed(ped, options.dict, options.anim, options.playbackRate)
    end

    -- Store state
    local data = {
        animId = animId,
        dict = options.dict,
        anim = options.anim,
        label = options.label,
        priority = options.priority or 1,
        startTime = GetGameTimer(),
        duration = duration,
        blendOut = blendOut,
        props = props,
        lockControl = options.lockControl,
        lockPosition = options.lockPosition,
        onEnd = options.onEnd,
        onStart = options.onStart,
    }
    activeAnims[ped] = data

    -- Sync to server
    if cfg.sync_to_server then
        TriggerServerEvent('hydra:anims:syncState', {
            animId = animId,
            dict = options.dict,
            anim = options.anim,
            label = options.label,
        })
    end

    -- Fire onStart
    if options.onStart then
        options.onStart(ped, animId)
    end

    -- Monitor for completion
    monitorCompletion(ped, animId, data)

    dbg('Playing %s/%s on ped %d (id=%s, flag=%d, dur=%d)', options.dict, options.anim, ped, animId, flag, duration)
    return animId
end

--- Play a scenario on a ped
--- @param ped number
--- @param scenario string
--- @param options table|nil
--- @return string|nil animId
function Hydra.Anims.PlayScenario(ped, scenario, options)
    options = options or {}
    options.scenario = scenario
    return Hydra.Anims.Play(ped, options)
end

--- Stop an animation on a ped
--- @param ped number
--- @param animId string|nil (nil stops current)
--- @param blendOut number|nil
function Hydra.Anims.Stop(ped, animId, blendOut)
    local current = activeAnims[ped]
    if not current then return end

    if animId and current.animId ~= animId then return end

    if blendOut then
        current.blendOut = blendOut
    end

    stopInternal(ped, current, true)
    processQueue(ped)
end

--- Stop all animations on a ped and clear queue
--- @param ped number
--- @param blendOut number|nil
function Hydra.Anims.StopAll(ped, blendOut)
    -- Clear queue
    animQueue[ped] = nil

    -- Stop current
    local current = activeAnims[ped]
    if current then
        if blendOut then
            current.blendOut = blendOut
        end
        stopInternal(ped, current, true)
    end
end

--- Queue an animation to play after current finishes
--- @param ped number
--- @param options table (same as Play)
--- @return string|nil animId
function Hydra.Anims.Queue(ped, options)
    if not cfg.enabled then return nil end
    if not ped or not options then return nil end

    -- If nothing is playing, play immediately
    if not activeAnims[ped] then
        return Hydra.Anims.Play(ped, options)
    end

    -- Check queue size
    if not animQueue[ped] then animQueue[ped] = {} end
    if #animQueue[ped] >= cfg.max_queue_size then
        dbg('Queue full for ped %d (%d/%d)', ped, #animQueue[ped], cfg.max_queue_size)
        return nil
    end

    local animId = generateAnimId()
    options._queuedAnimId = animId
    animQueue[ped][#animQueue[ped] + 1] = options

    dbg('Queued anim for ped %d (id=%s, queue size=%d)', ped, animId, #animQueue[ped])
    return animId
end

--- Check if a ped is playing a managed animation
--- @param ped number
--- @param animId string|nil (nil checks any)
--- @return boolean
function Hydra.Anims.IsPlaying(ped, animId)
    local current = activeAnims[ped]
    if not current then return false end
    if animId then return current.animId == animId end
    return true
end

--- Get current animation info for a ped
--- @param ped number
--- @return table|nil
function Hydra.Anims.GetCurrent(ped)
    local current = activeAnims[ped]
    if not current then return nil end

    return {
        dict = current.dict,
        anim = current.anim,
        animId = current.animId,
        label = current.label,
        startTime = current.startTime,
        props = current.props,
        scenario = current.scenario,
    }
end

--- Get animation progress (0.0 to 1.0)
--- @param ped number
--- @return number
function Hydra.Anims.GetProgress(ped)
    local current = activeAnims[ped]
    if not current then return 0.0 end

    if current.scenario then
        return 0.0 -- scenarios have no progress
    end

    if current.dict and current.anim then
        return GetEntityAnimCurrentTime(ped, current.dict, current.anim)
    end

    return 0.0
end

--- Get animation duration from native
--- @param dict string
--- @param anim string
--- @return number duration in ms
function Hydra.Anims.GetDuration(dict, anim)
    if not Hydra.Anims.LoadDict(dict) then return 0 end
    local duration = GetAnimDuration(dict, anim) * 1000
    Hydra.Anims.ReleaseDict(dict)
    return duration
end

--- Preload multiple animation dictionaries
--- @param dicts table array of dict strings
function Hydra.Anims.Preload(dicts)
    if not dicts then return end
    CreateThread(function()
        for _, dict in ipairs(dicts) do
            Hydra.Anims.LoadDict(dict)
            Hydra.Anims.ReleaseDict(dict) -- preloaded but not actively referenced
            Wait(0) -- yield per dict
        end
        dbg('Preloaded %d dictionaries', #dicts)
    end)
end

-- =============================================
-- HOOKS
-- =============================================

--- Register a before-play hook
--- @param fn function(ped, options) -> bool|nil (return false to cancel)
function Hydra.Anims.OnBefore(fn)
    if type(fn) ~= 'function' then return end
    hooksBefore[#hooksBefore + 1] = fn
end

--- Register an after-play hook
--- @param fn function(ped, animId, cancelled)
function Hydra.Anims.OnAfter(fn)
    if type(fn) ~= 'function' then return end
    hooksAfter[#hooksAfter + 1] = fn
end

--- Register a cancel hook
--- @param fn function(ped, animId)
function Hydra.Anims.OnCancel(fn)
    if type(fn) ~= 'function' then return end
    hooksCancel[#hooksCancel + 1] = fn
end

-- =============================================
-- SERVER-TRIGGERED EVENTS
-- =============================================

RegisterNetEvent('hydra:anims:play')
AddEventHandler('hydra:anims:play', function(options)
    if not options then return end
    local ped = PlayerPedId()
    Hydra.Anims.Play(ped, options)
end)

RegisterNetEvent('hydra:anims:stop')
AddEventHandler('hydra:anims:stop', function(animId, blendOut)
    local ped = PlayerPedId()
    if animId then
        Hydra.Anims.Stop(ped, animId, blendOut)
    else
        Hydra.Anims.StopAll(ped, blendOut)
    end
end)

-- =============================================
-- CACHE CLEANUP THREAD
-- =============================================

CreateThread(function()
    while true do
        Wait(cfg.cleanup_interval)

        local evicted = 0
        local now = GetGameTimer()
        local staleThreshold = cfg.cleanup_interval * 2 -- dicts unused for 2x cleanup interval

        for dict, entry in pairs(dictCache) do
            if entry.refCount <= 0 and (now - entry.lastUsed) > staleThreshold then
                RemoveAnimDict(dict)
                dictCache[dict] = nil
                evicted = evicted + 1
            end
        end

        if evicted > 0 then
            dbg('Cache cleanup: evicted %d stale dicts, %d remaining', evicted, getCacheCount())
        end
    end
end)

-- =============================================
-- RESOURCE CLEANUP
-- =============================================

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- Stop all active animations and clean up props
    for ped, data in pairs(activeAnims) do
        if DoesEntityExist(ped) then
            stopInternal(ped, data, true)
        end
    end

    -- Clear any remaining managed props
    for ped, props in pairs(managedProps) do
        for _, prop in ipairs(props) do
            if DoesEntityExist(prop) then
                DetachEntity(prop, true, true)
                DeleteEntity(prop)
            end
        end
    end

    -- Release all cached dicts
    for dict, entry in pairs(dictCache) do
        if entry.loaded then
            RemoveAnimDict(dict)
        end
    end

    activeAnims = {}
    animQueue = {}
    managedProps = {}
    dictCache = {}
end)

-- =============================================
-- EXPORTS
-- =============================================

exports('Play', function(ped, options) return Hydra.Anims.Play(ped, options) end)
exports('Stop', function(ped, animId, blendOut) return Hydra.Anims.Stop(ped, animId, blendOut) end)
exports('StopAll', function(ped, blendOut) return Hydra.Anims.StopAll(ped, blendOut) end)
exports('Queue', function(ped, options) return Hydra.Anims.Queue(ped, options) end)
exports('IsPlaying', function(ped, animId) return Hydra.Anims.IsPlaying(ped, animId) end)
exports('GetCurrent', function(ped) return Hydra.Anims.GetCurrent(ped) end)
exports('GetProgress', function(ped) return Hydra.Anims.GetProgress(ped) end)
exports('AttachProp', function(ped, options) return Hydra.Anims.AttachProp(ped, options) end)
exports('DetachProp', function(prop) return Hydra.Anims.DetachProp(prop) end)
exports('DetachAllProps', function(ped) return Hydra.Anims.DetachAllProps(ped) end)
exports('LoadDict', function(dict) return Hydra.Anims.LoadDict(dict) end)
exports('ReleaseDict', function(dict) return Hydra.Anims.ReleaseDict(dict) end)
exports('GetDuration', function(dict, anim) return Hydra.Anims.GetDuration(dict, anim) end)
exports('Preload', function(dicts) return Hydra.Anims.Preload(dicts) end)
exports('PlayScenario', function(ped, scenario, opts) return Hydra.Anims.PlayScenario(ped, scenario, opts) end)
exports('OnBefore', function(fn) return Hydra.Anims.OnBefore(fn) end)
exports('OnAfter', function(fn) return Hydra.Anims.OnAfter(fn) end)
exports('OnCancel', function(fn) return Hydra.Anims.OnCancel(fn) end)
