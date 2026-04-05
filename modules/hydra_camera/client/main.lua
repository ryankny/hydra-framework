--[[
    Hydra Camera - Client
    Centralized camera management: scripted cameras, orbit, shake,
    cinematic bars, path interpolation, and transitions.
]]

Hydra = Hydra or {}
Hydra.Camera = {}

local cfg = HydraConfig.Camera
local cameras = {}          -- { [camId] = { handle, position, rotation, fov, label, active } }
local activeCamera = nil    -- currently rendering camId
local orbitState = nil       -- orbit camera state
local shakeState = nil       -- screen shake state
local barState = { visible = false, alpha = 0, targetAlpha = 0, fadeStart = 0, fadeDuration = 0 }
local pathState = nil        -- path interpolation state
local camCounter = 0
local hooksActivate = {}
local hooksDeactivate = {}
local frozenLook = false

-- ── Easing functions ──

local easings = {
    linear = function(t) return t end,
    smooth = function(t) return t * t * (3.0 - 2.0 * t) end,
    ease_in = function(t) return t * t end,
    ease_out = function(t) return 1.0 - (1.0 - t) * (1.0 - t) end,
    ease_in_out = function(t)
        if t < 0.5 then return 2.0 * t * t
        else return 1.0 - (-2.0 * t + 2.0) ^ 2 / 2.0 end
    end,
}

local function getEasing(name)
    return easings[name] or easings[cfg.default_ease] or easings.smooth
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpVec3(a, b, t)
    return vector3(lerp(a.x, b.x, t), lerp(a.y, b.y, t), lerp(a.z, b.z, t))
end

local function nextCamId()
    camCounter = camCounter + 1
    return 'cam_' .. camCounter
end

-- ── Camera Lifecycle ──

function Hydra.Camera.Create(options)
    if not cfg.enabled then return nil end
    if not options or not options.position then return nil end

    local count = 0
    for _ in pairs(cameras) do count = count + 1 end
    if count >= cfg.max_active_cameras then
        Hydra.Utils.Log('warn', 'Camera limit reached (%d)', cfg.max_active_cameras)
        return nil
    end

    local pos = options.position
    local rot = options.rotation or vector3(0.0, 0.0, 0.0)
    local fov = options.fov or cfg.default_fov

    local handle = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
        pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, fov, false, 0)

    if options.target then
        PointCamAtCoord(handle, options.target.x, options.target.y, options.target.z)
    elseif options.targetEntity and DoesEntityExist(options.targetEntity) then
        PointCamAtEntity(handle, options.targetEntity, 0.0, 0.0, options.offsetZ or 0.0, true)
    end

    local camId = nextCamId()
    cameras[camId] = {
        handle = handle,
        position = pos,
        rotation = rot,
        fov = fov,
        label = options.label,
        active = false,
    }

    if options.active then
        Hydra.Camera.Activate(camId, options.transition, options.ease)
    end

    if cfg.debug then
        Hydra.Utils.Log('debug', 'Camera created: %s', camId)
    end

    return camId
end

function Hydra.Camera.Destroy(camId)
    local cam = cameras[camId]
    if not cam then return end

    if cam.active then
        RenderScriptCams(false, false, 0, true, false)
        if activeCamera == camId then activeCamera = nil end
    end

    DestroyCam(cam.handle, false)
    cameras[camId] = nil

    if cfg.debug then
        Hydra.Utils.Log('debug', 'Camera destroyed: %s', camId)
    end
end

function Hydra.Camera.DestroyAll(transition)
    if activeCamera then
        Hydra.Camera.Deactivate(transition or 0)
    end
    for id, cam in pairs(cameras) do
        DestroyCam(cam.handle, false)
    end
    cameras = {}
    activeCamera = nil
end

function Hydra.Camera.Activate(camId, transitionMs, ease)
    local cam = cameras[camId]
    if not cam then return end

    local ms = transitionMs or cfg.default_transition_ms

    if activeCamera and activeCamera ~= camId then
        local prev = cameras[activeCamera]
        if prev then
            SetCamActiveWithInterp(cam.handle, prev.handle, ms, 1, 1)
            prev.active = false
        end
    else
        SetCamActive(cam.handle, true)
        RenderScriptCams(true, ms > 0, ms, true, false)
    end

    cam.active = true
    activeCamera = camId

    for _, hook in ipairs(hooksActivate) do
        hook(camId, cam)
    end
end

function Hydra.Camera.Deactivate(transitionMs)
    local ms = transitionMs or cfg.default_transition_ms

    if activeCamera then
        local cam = cameras[activeCamera]
        if cam then
            cam.active = false
            SetCamActive(cam.handle, false)
        end
        local prev = activeCamera
        activeCamera = nil
        RenderScriptCams(false, ms > 0, ms, true, false)

        for _, hook in ipairs(hooksDeactivate) do
            hook(prev)
        end
    end
end

function Hydra.Camera.TransitionTo(fromCamId, toCamId, durationMs, ease)
    local fromCam = cameras[fromCamId]
    local toCam = cameras[toCamId]
    if not fromCam or not toCam then return end

    local ms = durationMs or cfg.default_transition_ms

    SetCamActiveWithInterp(toCam.handle, fromCam.handle, ms, 1, 1)
    fromCam.active = false
    toCam.active = true
    activeCamera = toCamId

    for _, hook in ipairs(hooksActivate) do
        hook(toCamId, toCam)
    end
end

-- ── Camera Properties ──

function Hydra.Camera.SetPosition(camId, coords, transitionMs)
    local cam = cameras[camId]
    if not cam then return end

    if transitionMs and transitionMs > 0 then
        local startPos = cam.position
        local startTime = GetGameTimer()
        local easing = getEasing(cfg.default_ease)
        CreateThread(function()
            while true do
                local elapsed = GetGameTimer() - startTime
                local t = math.min(1.0, elapsed / transitionMs)
                local et = easing(t)
                local pos = lerpVec3(startPos, coords, et)
                SetCamCoord(cam.handle, pos.x, pos.y, pos.z)
                cam.position = pos
                if t >= 1.0 then break end
                Wait(0)
            end
        end)
    else
        SetCamCoord(cam.handle, coords.x, coords.y, coords.z)
        cam.position = coords
    end
end

function Hydra.Camera.SetRotation(camId, rotation, transitionMs)
    local cam = cameras[camId]
    if not cam then return end

    if transitionMs and transitionMs > 0 then
        local startRot = cam.rotation
        local startTime = GetGameTimer()
        local easing = getEasing(cfg.default_ease)
        CreateThread(function()
            while true do
                local elapsed = GetGameTimer() - startTime
                local t = math.min(1.0, elapsed / transitionMs)
                local et = easing(t)
                local rot = lerpVec3(startRot, rotation, et)
                SetCamRot(cam.handle, rot.x, rot.y, rot.z, 2)
                cam.rotation = rot
                if t >= 1.0 then break end
                Wait(0)
            end
        end)
    else
        SetCamRot(cam.handle, rotation.x, rotation.y, rotation.z, 2)
        cam.rotation = rotation
    end
end

function Hydra.Camera.PointAt(camId, coords)
    local cam = cameras[camId]
    if not cam then return end
    PointCamAtCoord(cam.handle, coords.x, coords.y, coords.z)
end

function Hydra.Camera.PointAtEntity(camId, entity, offsetZ)
    local cam = cameras[camId]
    if not cam then return end
    if DoesEntityExist(entity) then
        PointCamAtEntity(cam.handle, entity, 0.0, 0.0, offsetZ or 0.0, true)
    end
end

function Hydra.Camera.SetFov(camId, fov, transitionMs)
    local cam = cameras[camId]
    if not cam then return end

    if transitionMs and transitionMs > 0 then
        local startFov = cam.fov
        local startTime = GetGameTimer()
        local easing = getEasing(cfg.default_ease)
        CreateThread(function()
            while true do
                local elapsed = GetGameTimer() - startTime
                local t = math.min(1.0, elapsed / transitionMs)
                local et = easing(t)
                local f = lerp(startFov, fov, et)
                SetCamFov(cam.handle, f)
                cam.fov = f
                if t >= 1.0 then break end
                Wait(0)
            end
        end)
    else
        SetCamFov(cam.handle, fov)
        cam.fov = fov
    end
end

function Hydra.Camera.GetPosition(camId)
    local cam = cameras[camId]
    return cam and cam.position or nil
end

function Hydra.Camera.GetRotation(camId)
    local cam = cameras[camId]
    return cam and cam.rotation or nil
end

function Hydra.Camera.GetFov(camId)
    local cam = cameras[camId]
    return cam and cam.fov or nil
end

function Hydra.Camera.IsActive(camId)
    local cam = cameras[camId]
    return cam and cam.active or false
end

function Hydra.Camera.GetActive()
    return activeCamera
end

-- ── Orbit Camera ──

function Hydra.Camera.StartOrbit(options)
    if not options then return nil end

    -- Stop any existing orbit
    if orbitState then
        Hydra.Camera.StopOrbit(0)
    end

    local target = options.target or vector3(0.0, 0.0, 0.0)
    local distance = options.distance or 5.0
    local pitch = options.pitch or -20.0
    local heading = options.heading or 0.0
    local fov = options.fov or cfg.default_fov
    local minDist = options.minDistance or cfg.orbit_zoom_min
    local maxDist = options.maxDistance or cfg.orbit_zoom_max

    local camId = Hydra.Camera.Create({
        position = target + vector3(0.0, 0.0, distance),
        fov = fov,
        label = 'orbit',
    })
    if not camId then return nil end

    Hydra.Camera.Activate(camId, options.transition or 500)

    orbitState = {
        camId = camId,
        target = target,
        targetEntity = options.targetEntity,
        distance = distance,
        pitch = pitch,
        heading = heading,
        minDistance = minDist,
        maxDistance = maxDist,
        autoRotate = options.autoRotate or false,
        autoRotateSpeed = options.autoRotateSpeed or 0.5,
        lockPitch = options.lockPitch or false,
        lockZoom = options.lockZoom or false,
        onUpdate = options.onUpdate,
    }

    CreateThread(function()
        while orbitState and orbitState.camId == camId do
            Wait(0)
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true) -- N for push to talk

            local state = orbitState
            if not state then break end

            -- Mouse input
            local mouseX = GetDisabledControlNormal(0, 1) * cfg.orbit_speed
            local mouseY = GetDisabledControlNormal(0, 2) * cfg.orbit_speed

            state.heading = state.heading - mouseX
            if not state.lockPitch then
                state.pitch = math.max(cfg.orbit_min_pitch,
                    math.min(cfg.orbit_max_pitch, state.pitch - mouseY))
            end

            -- Scroll zoom
            if not state.lockZoom then
                if IsDisabledControlPressed(0, 241) then -- scroll up
                    state.distance = math.max(state.minDistance, state.distance - cfg.orbit_zoom_speed)
                end
                if IsDisabledControlPressed(0, 242) then -- scroll down
                    state.distance = math.min(state.maxDistance, state.distance + cfg.orbit_zoom_speed)
                end
            end

            -- Auto-rotate when no input
            if state.autoRotate and math.abs(mouseX) < 0.001 and math.abs(mouseY) < 0.001 then
                state.heading = state.heading + state.autoRotateSpeed * GetFrameTime() * 60.0
            end

            -- Follow entity
            if state.targetEntity and DoesEntityExist(state.targetEntity) then
                state.target = GetEntityCoords(state.targetEntity)
            end

            -- Spherical to cartesian
            local pitchRad = math.rad(state.pitch)
            local headRad = math.rad(state.heading)
            local cosP = math.cos(pitchRad)
            local offset = vector3(
                -math.sin(headRad) * cosP * state.distance,
                -math.cos(headRad) * cosP * state.distance,
                -math.sin(pitchRad) * state.distance
            )

            local pos = state.target + offset
            local cam = cameras[camId]
            if not cam then break end

            SetCamCoord(cam.handle, pos.x, pos.y, pos.z)
            PointCamAtCoord(cam.handle, state.target.x, state.target.y, state.target.z)
            cam.position = pos

            if state.onUpdate then
                state.onUpdate(pos, GetCamRot(cam.handle, 2), state.distance)
            end
        end
    end)

    return camId
end

function Hydra.Camera.StopOrbit(transitionMs)
    if not orbitState then return end
    local camId = orbitState.camId
    orbitState = nil
    Hydra.Camera.Deactivate(transitionMs or 500)
    Hydra.Camera.Destroy(camId)
end

function Hydra.Camera.GetOrbitState()
    if not orbitState then return nil end
    return {
        distance = orbitState.distance,
        pitch = orbitState.pitch,
        heading = orbitState.heading,
        target = orbitState.target,
    }
end

-- ── Screen Shake ──

function Hydra.Camera.Shake(intensity, durationMs, frequency)
    if not intensity or intensity <= 0 then return end

    shakeState = {
        intensity = math.min(1.0, intensity),
        duration = durationMs or 500,
        frequency = frequency or 15.0,
        startTime = GetGameTimer(),
        seed = math.random(1000),
    }

    CreateThread(function()
        local state = shakeState
        if not state then return end
        local startTime = state.startTime

        while shakeState and shakeState.startTime == startTime do
            Wait(0)
            local elapsed = GetGameTimer() - startTime
            if elapsed >= state.duration then
                shakeState = nil
                break
            end

            local progress = elapsed / state.duration
            local currentIntensity = state.intensity * (1.0 - progress) -- linear decay

            local time = elapsed / 1000.0
            local offsetX = math.sin(time * state.frequency) * currentIntensity * 0.5
            local offsetY = math.cos(time * state.frequency * 1.3) * currentIntensity * 0.5

            if activeCamera then
                local cam = cameras[activeCamera]
                if cam then
                    local baseRot = cam.rotation
                    SetCamRot(cam.handle,
                        baseRot.x + offsetX,
                        baseRot.y + offsetY,
                        baseRot.z, 2)
                end
            else
                -- Shake gameplay camera via small ped movement
                local ped = PlayerPedId()
                if DoesEntityExist(ped) then
                    SetCamShakeAmplitude(GetRenderingCam(), currentIntensity * 100.0)
                end
            end
        end
    end)
end

function Hydra.Camera.StopShake()
    shakeState = nil
    StopCamShaking(GetRenderingCam(), true)
end

-- ── Cinematic Bars ──

function Hydra.Camera.ShowBars(fadeMs)
    barState.visible = true
    barState.targetAlpha = 255
    barState.fadeStart = GetGameTimer()
    barState.fadeDuration = fadeMs or cfg.cinematic_fade_ms
    barState.startAlpha = barState.alpha
end

function Hydra.Camera.HideBars(fadeMs)
    barState.targetAlpha = 0
    barState.fadeStart = GetGameTimer()
    barState.fadeDuration = fadeMs or cfg.cinematic_fade_ms
    barState.startAlpha = barState.alpha
end

function Hydra.Camera.AreBarsVisible()
    return barState.visible and barState.alpha > 0
end

-- Bar render thread
CreateThread(function()
    while true do
        if barState.visible or barState.alpha > 0 then
            Wait(0)
            -- Update alpha
            if barState.fadeDuration > 0 then
                local elapsed = GetGameTimer() - barState.fadeStart
                local t = math.min(1.0, elapsed / barState.fadeDuration)
                barState.alpha = math.floor(lerp(barState.startAlpha, barState.targetAlpha, t))
                if t >= 1.0 and barState.targetAlpha == 0 then
                    barState.visible = false
                end
            else
                barState.alpha = barState.targetAlpha
            end

            if barState.alpha > 0 then
                local size = cfg.cinematic_bar_size
                local a = barState.alpha
                DrawRect(0.5, size / 2.0, 1.0, size, 0, 0, 0, a)
                DrawRect(0.5, 1.0 - size / 2.0, 1.0, size, 0, 0, 0, a)
            end
        else
            Wait(200)
        end
    end
end)

-- ── Screen Fades ──

function Hydra.Camera.FadeIn(durationMs, r, g, b)
    DoScreenFadeIn(durationMs or 1000)
end

function Hydra.Camera.FadeOut(durationMs, r, g, b)
    DoScreenFadeOut(durationMs or 1000)
end

function Hydra.Camera.IsFadedOut()
    return IsScreenFadedOut()
end

-- ── Path Interpolation ──

function Hydra.Camera.PlayPath(points, options)
    if not points or #points < 2 then return nil end

    options = options or {}
    local ease = getEasing(options.ease or cfg.default_ease)

    -- Stop existing path
    if pathState then
        Hydra.Camera.StopPath()
    end

    local camId = Hydra.Camera.Create({
        position = points[1].position,
        rotation = points[1].rotation or vector3(0.0, 0.0, 0.0),
        fov = points[1].fov or cfg.default_fov,
        active = true,
        transition = 0,
        label = 'path',
    })
    if not camId then return nil end

    pathState = { camId = camId, active = true }

    CreateThread(function()
        local running = true
        while running and pathState and pathState.camId == camId do
            for i = 1, #points - 1 do
                if not pathState or pathState.camId ~= camId then
                    running = false
                    break
                end

                local from = points[i]
                local to = points[i + 1]
                local duration = to.duration or 2000
                local startTime = GetGameTimer()

                local fromPos = from.position
                local toPos = to.position
                local fromRot = from.rotation or vector3(0.0, 0.0, 0.0)
                local toRot = to.rotation or vector3(0.0, 0.0, 0.0)
                local fromFov = from.fov or cfg.default_fov
                local toFov = to.fov or cfg.default_fov

                while true do
                    Wait(0)
                    if not pathState or pathState.camId ~= camId then
                        running = false
                        break
                    end

                    local elapsed = GetGameTimer() - startTime
                    local t = math.min(1.0, elapsed / duration)
                    local et = ease(t)

                    local pos = lerpVec3(fromPos, toPos, et)
                    local rot = lerpVec3(fromRot, toRot, et)
                    local fov = lerp(fromFov, toFov, et)

                    local cam = cameras[camId]
                    if not cam then running = false break end

                    SetCamCoord(cam.handle, pos.x, pos.y, pos.z)
                    SetCamRot(cam.handle, rot.x, rot.y, rot.z, 2)
                    SetCamFov(cam.handle, fov)
                    cam.position = pos
                    cam.rotation = rot
                    cam.fov = fov

                    if t >= 1.0 then break end
                end
            end

            if not options.loop then
                running = false
            end
        end

        -- Completed
        pathState = nil
        if options.onComplete then
            options.onComplete()
        end
    end)

    return camId
end

function Hydra.Camera.StopPath()
    if not pathState then return end
    local camId = pathState.camId
    pathState = nil
    Hydra.Camera.Deactivate(500)
    Hydra.Camera.Destroy(camId)
end

-- ── Freeze Look ──

function Hydra.Camera.FreezeLook(frozen)
    frozenLook = frozen
end

CreateThread(function()
    while true do
        if frozenLook then
            Wait(0)
            DisableControlAction(0, 1, true)   -- Look LR
            DisableControlAction(0, 2, true)   -- Look UD
            DisableControlAction(0, 25, true)  -- Aim
        else
            Wait(200)
        end
    end
end)

-- ── Hooks ──

function Hydra.Camera.OnActivate(fn)
    if type(fn) == 'function' then
        hooksActivate[#hooksActivate + 1] = fn
    end
end

function Hydra.Camera.OnDeactivate(fn)
    if type(fn) == 'function' then
        hooksDeactivate[#hooksDeactivate + 1] = fn
    end
end

-- ── Death Cleanup ──

if cfg.cleanup_on_death then
    CreateThread(function()
        while true do
            Wait(1000)
            local ped = PlayerPedId()
            if IsEntityDead(ped) and activeCamera then
                Hydra.Camera.DestroyAll(500)
                if orbitState then
                    orbitState = nil
                end
                if pathState then
                    pathState = nil
                end
                Hydra.Camera.HideBars(0)
            end
        end
    end)
end

-- ── Server Events ──

RegisterNetEvent('hydra:camera:create')
AddEventHandler('hydra:camera:create', function(data)
    if not data or not data.position then return end
    local camId = Hydra.Camera.Create(data)
    if camId and data.active then
        Hydra.Camera.Activate(camId, data.transition)
    end
end)

RegisterNetEvent('hydra:camera:destroy')
AddEventHandler('hydra:camera:destroy', function()
    Hydra.Camera.DestroyAll(500)
end)

RegisterNetEvent('hydra:camera:orbit')
AddEventHandler('hydra:camera:orbit', function(data)
    if not data then return end
    Hydra.Camera.StartOrbit(data)
end)

RegisterNetEvent('hydra:camera:override')
AddEventHandler('hydra:camera:override', function(key, value)
    if key and cfg[key] ~= nil then
        cfg[key] = value
    end
end)

-- ── Exports ──

exports('Create', function(opts) return Hydra.Camera.Create(opts) end)
exports('Destroy', function(id) return Hydra.Camera.Destroy(id) end)
exports('DestroyAll', function(t) return Hydra.Camera.DestroyAll(t) end)
exports('Activate', function(id, ms, e) return Hydra.Camera.Activate(id, ms, e) end)
exports('Deactivate', function(ms) return Hydra.Camera.Deactivate(ms) end)
exports('TransitionTo', function(a, b, ms, e) return Hydra.Camera.TransitionTo(a, b, ms, e) end)
exports('SetPosition', function(id, c, ms) return Hydra.Camera.SetPosition(id, c, ms) end)
exports('SetRotation', function(id, r, ms) return Hydra.Camera.SetRotation(id, r, ms) end)
exports('PointAt', function(id, c) return Hydra.Camera.PointAt(id, c) end)
exports('PointAtEntity', function(id, e, oz) return Hydra.Camera.PointAtEntity(id, e, oz) end)
exports('SetFov', function(id, f, ms) return Hydra.Camera.SetFov(id, f, ms) end)
exports('GetPosition', function(id) return Hydra.Camera.GetPosition(id) end)
exports('GetRotation', function(id) return Hydra.Camera.GetRotation(id) end)
exports('GetFov', function(id) return Hydra.Camera.GetFov(id) end)
exports('IsActive', function(id) return Hydra.Camera.IsActive(id) end)
exports('GetActive', function() return Hydra.Camera.GetActive() end)
exports('StartOrbit', function(opts) return Hydra.Camera.StartOrbit(opts) end)
exports('StopOrbit', function(ms) return Hydra.Camera.StopOrbit(ms) end)
exports('GetOrbitState', function() return Hydra.Camera.GetOrbitState() end)
exports('Shake', function(i, d, f) return Hydra.Camera.Shake(i, d, f) end)
exports('StopShake', function() return Hydra.Camera.StopShake() end)
exports('ShowBars', function(ms) return Hydra.Camera.ShowBars(ms) end)
exports('HideBars', function(ms) return Hydra.Camera.HideBars(ms) end)
exports('AreBarsVisible', function() return Hydra.Camera.AreBarsVisible() end)
exports('FadeIn', function(ms, r, g, b) return Hydra.Camera.FadeIn(ms, r, g, b) end)
exports('FadeOut', function(ms, r, g, b) return Hydra.Camera.FadeOut(ms, r, g, b) end)
exports('IsFadedOut', function() return Hydra.Camera.IsFadedOut() end)
exports('PlayPath', function(pts, opts) return Hydra.Camera.PlayPath(pts, opts) end)
exports('StopPath', function() return Hydra.Camera.StopPath() end)
exports('FreezeLook', function(f) return Hydra.Camera.FreezeLook(f) end)
exports('OnActivate', function(fn) return Hydra.Camera.OnActivate(fn) end)
exports('OnDeactivate', function(fn) return Hydra.Camera.OnDeactivate(fn) end)

-- ── Resource Cleanup ──

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Hydra.Camera.DestroyAll(0)
    barState.visible = false
    barState.alpha = 0
    shakeState = nil
    pathState = nil
    orbitState = nil
    frozenLook = false
end)
