--[[
    Hydra Scenes - Client
    Scripted sequence engine. Orchestrates camera, animations, audio,
    NPCs, objects, and markers into timed, skippable sequences.
]]

Hydra = Hydra or {}
Hydra.Scenes = {}

-- ---------------------------------------------------------------------------
-- Localize hot-path functions
-- ---------------------------------------------------------------------------
local type         = type
local pairs        = pairs
local ipairs       = ipairs
local tostring     = tostring
local math_min     = math.min
local math_max     = math.max
local math_floor   = math.floor
local table_sort   = table.sort
local table_insert = table.insert
local GetGameTimer = GetGameTimer

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------
local cfg            = HydraConfig.Scenes
local sceneRegistry  = {}     -- { [name] = definition }
local activeScene    = nil    -- { name, def, data, startTime, stepIndex }
local isPlaying      = false
local skipRequested  = false

-- Subtitle state
local subtitleText   = nil
local subtitleEnd    = 0
local subtitleColor  = { r = 255, g = 255, b = 255 }

-- Global hooks
local hooksStart    = {}
local hooksComplete = {}

-- Control hash for skip key (BACKSPACE = 194 / INPUT_FRONTEND_DELETE)
local SKIP_CONTROL  = 194

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function debugLog(msg, ...)
    if cfg.debug then
        Hydra.Utils.Log('debug', '[Scenes] ' .. msg, ...)
    end
end

--- Safely call an export from another Hydra module.
--- Returns nil on failure so the scene engine never hard-errors
--- when an optional module is missing.
local function safeExport(resource, fn, ...)
    local ok, result = pcall(function(...)
        return exports[resource][fn](exports[resource], ...)
    end, ...)
    if ok then return result end
    debugLog('Export call failed: %s:%s - %s', resource, fn, tostring(result))
    return nil
end

--- Resolve a ped reference. Accepts 'player', a number (entity handle),
--- or nil (defaults to player ped).
local function resolvePed(ref)
    if ref == 'player' or ref == nil then
        return PlayerPedId()
    end
    if type(ref) == 'number' then
        return ref
    end
    return PlayerPedId()
end

-- ---------------------------------------------------------------------------
-- Subtitle rendering
-- ---------------------------------------------------------------------------

local function drawSubtitle(text, color)
    local r = color and color.r or 255
    local g = color and color.g or 255
    local b = color and color.b or 255

    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.0, 0.45)
    SetTextColour(r, g, b, 255)
    SetTextDropshadow(1, 0, 0, 0, 200)
    SetTextEdge(1, 0, 0, 0, 200)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(0.5, 0.90)
end

CreateThread(function()
    while true do
        if subtitleText and GetGameTimer() < subtitleEnd then
            Wait(0)
            drawSubtitle(subtitleText, subtitleColor)
        else
            if subtitleText then
                subtitleText = nil
            end
            Wait(200)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Step handlers — dispatch individual step fields to framework modules
-- ---------------------------------------------------------------------------

--- Handle a camera step (single camera placement or transition).
local function handleCamera(cam, sceneData)
    if not cam then return end

    local opts = {
        position = cam.position,
        rotation = cam.rotation,
        fov = cam.fov or 50.0,
        target = cam.target,
        targetEntity = cam.targetEntity,
        active = true,
        transition = cam.transition or 0,
        label = 'scene',
    }

    -- If there is already a scene camera, transition from it
    local prevCamId = sceneData._cameraId
    local newCamId = safeExport('hydra_camera', 'Create', opts)

    if newCamId then
        if prevCamId and cam.transition and cam.transition > 0 then
            safeExport('hydra_camera', 'TransitionTo', prevCamId, newCamId, cam.transition, cam.ease)
            -- Destroy the old camera after transition completes
            SetTimeout(cam.transition + 50, function()
                safeExport('hydra_camera', 'Destroy', prevCamId)
            end)
        elseif prevCamId then
            safeExport('hydra_camera', 'Destroy', prevCamId)
        end
        sceneData._cameraId = newCamId
    end
end

--- Handle a camera path step.
local function handleCameraPath(path, sceneData)
    if not path or not path.points then return end

    -- Stop any existing scene camera first
    if sceneData._cameraId then
        safeExport('hydra_camera', 'Destroy', sceneData._cameraId)
        sceneData._cameraId = nil
    end

    local pathCamId = safeExport('hydra_camera', 'PlayPath', path.points, {
        ease = path.ease,
        loop = path.loop or false,
    })

    if pathCamId then
        sceneData._cameraId = pathCamId
    end
end

--- Handle an animation step.
local function handleAnim(anim, sceneData)
    if not anim then return end

    local ped = resolvePed(anim.ped)
    safeExport('hydra_anims', 'Play', ped, {
        dict = anim.dict,
        name = anim.name,
        flag = anim.flag,
        duration = anim.duration,
        blendIn = anim.blendIn,
        blendOut = anim.blendOut,
    })
end

--- Handle a scenario step.
local function handleScenario(scenario, sceneData)
    if not scenario then return end

    local ped = resolvePed(scenario.ped)
    safeExport('hydra_anims', 'PlayScenario', ped, scenario.name, {
        duration = scenario.duration,
    })
end

--- Handle an audio step.
local function handleAudio(audio, sceneData)
    if not audio then return end

    local soundId = nil
    local audioType = audio.type or 'frontend'

    if audioType == 'frontend' then
        soundId = safeExport('hydra_audio', 'PlayFrontend', {
            name = audio.name,
            soundSet = audio.soundSet,
            volume = audio.volume,
            category = 'scene',
        })
    elseif audioType == 'custom' then
        soundId = safeExport('hydra_audio', 'PlayCustom', {
            url = audio.url,
            volume = audio.volume,
            loop = audio.loop,
            category = 'scene',
        })
    elseif audioType == 'coord' then
        soundId = safeExport('hydra_audio', 'PlayAtCoord', {
            name = audio.name,
            soundSet = audio.soundSet,
            coords = audio.coords,
            volume = audio.volume,
            range = audio.range,
            category = 'scene',
        })
    end

    if soundId then
        table_insert(sceneData._audioIds, soundId)
    end

    -- Handle fade-in on the sound
    if audio.fadeIn and soundId then
        safeExport('hydra_audio', 'Fade', soundId, 0.0, audio.volume or 1.0, audio.fadeIn)
    end
end

--- Handle an NPC step.
local function handleNpc(npc, sceneData)
    if not npc then return end

    if npc.create then
        local opts = npc.create
        local npcId = safeExport('hydra_npc', 'Create', opts)
        if npcId then
            table_insert(sceneData._createdNpcs, npcId)
            debugLog('NPC created: %s', tostring(npcId))
        end
    end

    if npc.walkTo then
        local info = npc.walkTo
        safeExport('hydra_npc', 'WalkTo', info[1] or info.npcId, info[2] or info.coords, info[3] or info.speed)
    end

    if npc.lookAt then
        local info = npc.lookAt
        safeExport('hydra_npc', 'LookAt', info[1] or info.npcId, info[2] or info.coords)
    end

    if npc.remove then
        safeExport('hydra_npc', 'Remove', npc.remove)
        -- Remove from tracking list
        for i, id in ipairs(sceneData._createdNpcs) do
            if id == npc.remove then
                table.remove(sceneData._createdNpcs, i)
                break
            end
        end
    end
end

--- Handle an object/prop step.
local function handleObject(obj, sceneData)
    if not obj then return end

    if obj.create then
        local objId = safeExport('hydra_object', 'Create', obj.create)
        if objId then
            table_insert(sceneData._createdObjects, objId)
            debugLog('Object created: %s', tostring(objId))
        end
    end

    if obj.remove then
        safeExport('hydra_object', 'Remove', obj.remove)
        for i, id in ipairs(sceneData._createdObjects) do
            if id == obj.remove then
                table.remove(sceneData._createdObjects, i)
                break
            end
        end
    end
end

--- Handle a marker step.
local function handleMarker(marker, sceneData)
    if not marker then return end

    if marker.create then
        local markerId = safeExport('hydra_markers', 'Create', marker.create)
        if markerId then
            table_insert(sceneData._createdMarkers, markerId)
            debugLog('Marker created: %s', tostring(markerId))
        end
    end

    if marker.remove then
        safeExport('hydra_markers', 'Remove', marker.remove)
        for i, id in ipairs(sceneData._createdMarkers) do
            if id == marker.remove then
                table.remove(sceneData._createdMarkers, i)
                break
            end
        end
    end
end

--- Handle a subtitle step.
local function handleSubtitle(sub, sceneData)
    if not sub then return end

    subtitleText  = sub.text
    subtitleEnd   = GetGameTimer() + (sub.duration or 3000)
    subtitleColor = sub.color or { r = 255, g = 255, b = 255 }
end

--- Handle a screen effect step.
local function handleEffect(effect, sceneData)
    if not effect then return end

    if effect.fadeOut then
        safeExport('hydra_camera', 'FadeOut', effect.fadeOut)
    end

    if effect.fadeIn then
        safeExport('hydra_camera', 'FadeIn', effect.fadeIn)
    end

    if effect.flash then
        local f = effect.flash
        local r = f.r or f[1] or 255
        local g = f.g or f[2] or 255
        local b = f.b or f[3] or 255
        local dur = f.duration or f[4] or 200
        -- Use native screen flash
        AnimpostfxPlay('FocusOut', 0, false)
        SetTimeout(dur, function()
            AnimpostfxStop('FocusOut')
        end)
    end
end

--- Handle HUD visibility step.
local function handleHud(hud, sceneData)
    if not hud then return end
    pcall(function()
        exports['hydra_hud']:SetVisible(hud.visible)
    end)
end

--- Execute a single step by dispatching each field to its handler.
local function executeStep(step, sceneData)
    if step.camera     then handleCamera(step.camera, sceneData) end
    if step.cameraPath then handleCameraPath(step.cameraPath, sceneData) end
    if step.anim       then handleAnim(step.anim, sceneData) end
    if step.scenario   then handleScenario(step.scenario, sceneData) end
    if step.audio      then handleAudio(step.audio, sceneData) end
    if step.npc        then handleNpc(step.npc, sceneData) end
    if step.object     then handleObject(step.object, sceneData) end
    if step.marker     then handleMarker(step.marker, sceneData) end
    if step.subtitle   then handleSubtitle(step.subtitle, sceneData) end
    if step.effect     then handleEffect(step.effect, sceneData) end
    if step.hud        then handleHud(step.hud, sceneData) end
    if step.fn         then
        local ok, err = pcall(step.fn, sceneData)
        if not ok then
            debugLog('Step fn error: %s', tostring(err))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Scene lifecycle
-- ---------------------------------------------------------------------------

--- Clean up all resources created during a scene and restore player state.
local function finishScene(sceneData, wasSkipped)
    local def  = activeScene and activeScene.def
    local name = activeScene and activeScene.name or 'inline'

    debugLog('Finishing scene: %s (skipped=%s)', name, tostring(wasSkipped))

    -- Destroy scene camera
    if sceneData._cameraId then
        -- Stop any camera path first
        pcall(function() exports['hydra_camera']:StopPath() end)
        safeExport('hydra_camera', 'Deactivate', 500)
        safeExport('hydra_camera', 'Destroy', sceneData._cameraId)
        sceneData._cameraId = nil
    end

    -- Stop all audio spawned by this scene
    for _, soundId in ipairs(sceneData._audioIds or {}) do
        safeExport('hydra_audio', 'Stop', soundId)
    end
    sceneData._audioIds = {}

    -- Remove NPCs created during scene
    for _, npcId in ipairs(sceneData._createdNpcs or {}) do
        safeExport('hydra_npc', 'Remove', npcId)
    end
    sceneData._createdNpcs = {}

    -- Remove objects created during scene
    for _, objId in ipairs(sceneData._createdObjects or {}) do
        safeExport('hydra_object', 'Remove', objId)
    end
    sceneData._createdObjects = {}

    -- Remove markers created during scene
    for _, markerId in ipairs(sceneData._createdMarkers or {}) do
        safeExport('hydra_markers', 'Remove', markerId)
    end
    sceneData._createdMarkers = {}

    -- Hide cinematic bars
    if def and def.showBars ~= false and cfg.show_bars then
        safeExport('hydra_camera', 'HideBars', 500)
    end

    -- Restore HUD
    if def and def.hideHud ~= false and cfg.hide_hud then
        pcall(function() exports['hydra_hud']:SetVisible(true) end)
    end

    -- Clear subtitle
    subtitleText = nil

    -- Ensure screen is faded in
    if IsScreenFadedOut() then
        DoScreenFadeIn(500)
    end

    -- Stop player animation if one was playing
    local ped = PlayerPedId()
    if IsEntityPlayingAnim(ped, '', '', 3) then
        ClearPedTasks(ped)
    end

    -- Fire definition callbacks
    if def then
        if wasSkipped and def.onSkip then
            local ok, err = pcall(def.onSkip, sceneData)
            if not ok then debugLog('onSkip error: %s', tostring(err)) end
        end
        if def.cleanup then
            local ok, err = pcall(def.cleanup, sceneData, wasSkipped)
            if not ok then debugLog('cleanup error: %s', tostring(err)) end
        end
        if def.onComplete then
            local ok, err = pcall(def.onComplete, sceneData)
            if not ok then debugLog('onComplete error: %s', tostring(err)) end
        end
    end

    -- Fire global hooks
    for _, hook in ipairs(hooksComplete) do
        local ok, err = pcall(hook, name, sceneData, wasSkipped)
        if not ok then debugLog('OnComplete hook error: %s', tostring(err)) end
    end

    -- Reset state
    activeScene  = nil
    isPlaying    = false
    skipRequested = false
end

--- Execute all steps in order, waiting for the correct time offset.
local function executeSteps(def, sceneData)
    local startTime = GetGameTimer()
    local steps = def.steps or {}

    -- Build a sorted list by 'at' time so authors can define steps in any order
    local sorted = {}
    for i, step in ipairs(steps) do
        sorted[#sorted + 1] = { index = i, step = step }
    end
    table_sort(sorted, function(a, b) return (a.step.at or 0) < (b.step.at or 0) end)

    local stepIdx = 1

    while isPlaying and stepIdx <= #sorted do
        if skipRequested then break end

        local entry   = sorted[stepIdx]
        local step    = entry.step
        local target  = step.at or 0
        local elapsed = GetGameTimer() - startTime

        -- Wait until this step's trigger time
        while elapsed < target and isPlaying and not skipRequested do
            Wait(10)
            elapsed = GetGameTimer() - startTime
        end

        if skipRequested or not isPlaying then break end

        -- Update active scene tracking
        activeScene.stepIndex = entry.index

        debugLog('Executing step %d: %s (at %dms)', entry.index, step.label or '(unlabeled)', target)

        -- Fire per-step callback
        if def.onStep then
            local ok, err = pcall(def.onStep, entry.index, step, sceneData)
            if not ok then debugLog('onStep error: %s', tostring(err)) end
        end

        -- Dispatch step actions
        executeStep(step, sceneData)

        -- Additional wait if specified
        if step.wait and step.wait > 0 then
            local waitUntil = GetGameTimer() + step.wait
            while GetGameTimer() < waitUntil and isPlaying and not skipRequested do
                Wait(10)
            end
        end

        stepIdx = stepIdx + 1
    end

    -- If all steps completed naturally (no skip), wait for total duration if specified
    if not skipRequested and isPlaying and def.duration then
        local remaining = def.duration - (GetGameTimer() - startTime)
        if remaining > 0 then
            local waitUntil = GetGameTimer() + remaining
            while GetGameTimer() < waitUntil and isPlaying and not skipRequested do
                Wait(10)
            end
        end
    end

    -- Scene complete
    finishScene(sceneData, skipRequested)
end

--- Internal: begin scene playback from a definition table.
local function startScene(name, def, data)
    if not cfg.enabled then
        debugLog('Scene system is disabled')
        return false
    end

    if isPlaying then
        debugLog('Cannot play "%s" — a scene is already playing', name)
        return false
    end

    isPlaying     = true
    skipRequested = false

    -- Initialize scene data with tracking tables
    local sceneData = data or {}
    sceneData._createdNpcs    = {}
    sceneData._createdObjects = {}
    sceneData._createdMarkers = {}
    sceneData._cameraId       = nil
    sceneData._audioIds       = {}

    activeScene = {
        name      = name,
        def       = def,
        data      = sceneData,
        startTime = GetGameTimer(),
        stepIndex = 0,
    }

    debugLog('Starting scene: %s', name)

    -- Setup phase: hide HUD, show cinematic bars
    if def.hideHud ~= false and cfg.hide_hud then
        pcall(function() exports['hydra_hud']:SetVisible(false) end)
    end

    if def.showBars ~= false and cfg.show_bars then
        safeExport('hydra_camera', 'ShowBars', 500)
    end

    -- Run definition setup callback
    if def.setup then
        local ok, err = pcall(def.setup, sceneData)
        if not ok then debugLog('setup error: %s', tostring(err)) end
    end

    -- Run onStart callback
    if def.onStart then
        local ok, err = pcall(def.onStart, sceneData)
        if not ok then debugLog('onStart error: %s', tostring(err)) end
    end

    -- Fire global start hooks
    for _, hook in ipairs(hooksStart) do
        local ok, err = pcall(hook, name, sceneData)
        if not ok then debugLog('OnStart hook error: %s', tostring(err)) end
    end

    -- Step execution thread
    CreateThread(function()
        executeSteps(def, sceneData)
    end)

    -- Control disable + skip key listener thread
    local allowSkip = def.allowSkip ~= false and cfg.allow_skip
    local disableControls = def.disableControls ~= false and cfg.disable_controls

    if allowSkip or disableControls then
        CreateThread(function()
            while isPlaying do
                Wait(0)

                if disableControls then
                    DisableAllControlActions(0)
                    -- Re-enable mouse look so the player can at least look around
                    EnableControlAction(0, 1, true)   -- Look LR
                    EnableControlAction(0, 2, true)   -- Look UD
                    EnableControlAction(0, 245, true)  -- Chat (T)
                    EnableControlAction(0, 249, true)  -- Push to talk (N)
                end

                if allowSkip then
                    if IsDisabledControlJustPressed(0, SKIP_CONTROL) or
                       IsControlJustPressed(0, SKIP_CONTROL) then
                        Hydra.Scenes.Skip()
                    end
                end
            end
        end)
    end

    return true
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Register a named scene definition for later playback.
--- @param name string Unique scene name
--- @param definition table Scene definition table
function Hydra.Scenes.Register(name, definition)
    if not name or type(name) ~= 'string' then
        debugLog('Register: invalid name')
        return
    end
    if not definition or type(definition) ~= 'table' then
        debugLog('Register: invalid definition for "%s"', name)
        return
    end

    definition.name = name
    sceneRegistry[name] = definition
    debugLog('Registered scene: %s', name)
end

--- Unregister a scene definition.
--- @param name string Scene name to remove
function Hydra.Scenes.Unregister(name)
    if sceneRegistry[name] then
        sceneRegistry[name] = nil
        debugLog('Unregistered scene: %s', name)
    end
end

--- Play a previously registered scene by name.
--- @param name string Scene name
--- @param data table|nil Optional data table passed to all callbacks as sceneData
--- @return boolean success
function Hydra.Scenes.Play(name, data)
    local def = sceneRegistry[name]
    if not def then
        debugLog('Play: scene "%s" is not registered', name)
        return false
    end
    return startScene(name, def, data)
end

--- Play an inline (unregistered) scene definition directly.
--- @param definition table Scene definition table
--- @param data table|nil Optional data table
--- @return boolean success
function Hydra.Scenes.PlayInline(definition, data)
    if not definition or type(definition) ~= 'table' then
        debugLog('PlayInline: invalid definition')
        return false
    end
    local name = definition.name or ('inline_' .. GetGameTimer())
    return startScene(name, definition, data)
end

--- Stop the current scene. If skipCleanup is true, the cleanup phase is
--- bypassed entirely (use with caution — resources may leak).
--- @param skipCleanup boolean|nil
function Hydra.Scenes.Stop(skipCleanup)
    if not isPlaying then return end

    debugLog('Stop requested (skipCleanup=%s)', tostring(skipCleanup))

    if skipCleanup then
        -- Hard stop — reset state without cleanup
        activeScene   = nil
        isPlaying     = false
        skipRequested = false
        subtitleText  = nil
    else
        -- Graceful stop via the skip mechanism
        skipRequested = true
    end
end

--- Skip the current scene. Triggers the cleanup phase and fires onSkip.
function Hydra.Scenes.Skip()
    if not isPlaying then return end
    if skipRequested then return end -- already skipping

    debugLog('Skip requested')
    skipRequested = true
end

--- Check whether a scene is currently playing.
--- @return boolean
function Hydra.Scenes.IsPlaying()
    return isPlaying
end

--- Get information about the currently playing scene.
--- @return table|nil { name, startTime, stepIndex, data }
function Hydra.Scenes.GetCurrent()
    if not activeScene then return nil end
    return {
        name      = activeScene.name,
        startTime = activeScene.startTime,
        stepIndex = activeScene.stepIndex,
        data      = activeScene.data,
    }
end

--- Get a list of all registered scene names.
--- @return table Array of scene name strings
function Hydra.Scenes.GetRegistered()
    local names = {}
    for name in pairs(sceneRegistry) do
        names[#names + 1] = name
    end
    table_sort(names)
    return names
end

--- Register a global hook that fires when any scene starts.
--- @param fn function(sceneName, sceneData)
function Hydra.Scenes.OnStart(fn)
    if type(fn) == 'function' then
        hooksStart[#hooksStart + 1] = fn
    end
end

--- Register a global hook that fires when any scene completes or is skipped.
--- @param fn function(sceneName, sceneData, wasSkipped)
function Hydra.Scenes.OnComplete(fn)
    if type(fn) == 'function' then
        hooksComplete[#hooksComplete + 1] = fn
    end
end

-- ---------------------------------------------------------------------------
-- Server events
-- ---------------------------------------------------------------------------

RegisterNetEvent('hydra:scenes:play')
AddEventHandler('hydra:scenes:play', function(name, data)
    if not name or type(name) ~= 'string' then return end
    Hydra.Scenes.Play(name, data)
end)

RegisterNetEvent('hydra:scenes:stop')
AddEventHandler('hydra:scenes:stop', function()
    Hydra.Scenes.Stop()
end)

-- ---------------------------------------------------------------------------
-- Exports
-- ---------------------------------------------------------------------------

exports('Register',      function(name, def)     return Hydra.Scenes.Register(name, def) end)
exports('Unregister',    function(name)           return Hydra.Scenes.Unregister(name) end)
exports('Play',          function(name, data)     return Hydra.Scenes.Play(name, data) end)
exports('PlayInline',    function(def, data)      return Hydra.Scenes.PlayInline(def, data) end)
exports('Stop',          function(skipCleanup)    return Hydra.Scenes.Stop(skipCleanup) end)
exports('Skip',          function()               return Hydra.Scenes.Skip() end)
exports('IsPlaying',     function()               return Hydra.Scenes.IsPlaying() end)
exports('GetCurrent',    function()               return Hydra.Scenes.GetCurrent() end)
exports('GetRegistered', function()               return Hydra.Scenes.GetRegistered() end)
exports('OnStart',       function(fn)             return Hydra.Scenes.OnStart(fn) end)
exports('OnComplete',    function(fn)             return Hydra.Scenes.OnComplete(fn) end)

-- ---------------------------------------------------------------------------
-- Resource cleanup — ensure no leaked state if the resource restarts
-- ---------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if isPlaying and activeScene then
        finishScene(activeScene.data, true)
    end

    sceneRegistry = {}
    subtitleText  = nil
    hooksStart    = {}
    hooksComplete = {}
end)
