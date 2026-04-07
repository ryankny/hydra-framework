--[[
    Hydra Identity - Camera Control

    Interactive camera for character appearance preview.
    - Mouse scroll: zoom in/out
    - NUI buttons: rotate ped, move camera up/down
    - Smooth transitions between zoom levels
]]

Hydra = Hydra or {}
Hydra.Identity = Hydra.Identity or {}

local activeCam = nil
local cameraActive = false

-- Camera state
local camDistance = 1.8
local camHeight = 0.6       -- offset above ped feet
local pedHeading = 180.0

-- Limits
local MIN_DISTANCE = 0.5
local MAX_DISTANCE = 3.5
local MIN_HEIGHT = -0.2
local MAX_HEIGHT = 1.4

--- Get the ped position for the camera to look at
local function getPedOrigin()
    local cfg = HydraIdentityConfig.camera.creation
    return vector3(cfg.ped_coords.x, cfg.ped_coords.y, cfg.ped_coords.z)
end

--- Update camera position based on current state
local function updateCamera()
    if not activeCam then return end

    local origin = getPedOrigin()

    -- Camera orbits from the front of the ped (based on ped heading)
    local rad = math.rad(pedHeading)
    local camPos = vector3(
        origin.x + math.sin(rad) * camDistance,
        origin.y + math.cos(rad) * camDistance,
        origin.z + camHeight
    )

    -- Look at upper body
    local lookAt = vector3(origin.x, origin.y, origin.z + 0.55)

    SetCamCoord(activeCam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(activeCam, lookAt.x, lookAt.y, lookAt.z)

    -- Dynamic FOV based on distance (closer = narrower for less distortion)
    local fov = 30.0 + (camDistance - MIN_DISTANCE) * 5.0
    SetCamFov(activeCam, math.min(fov, 50.0))
end

--- Setup camera for character preview
--- @param screen string 'creation' | 'appearance'
function Hydra.Identity.SetupCamera(screen)
    Hydra.Identity.DestroyCamera()

    if screen == 'appearance' then
        -- Close-up for appearance
        camDistance = 1.0
        camHeight = 0.7
    else
        -- Full body for creation
        camDistance = 1.8
        camHeight = 0.6
    end

    activeCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    updateCamera()
    SetCamActive(activeCam, true)
    RenderScriptCams(true, false, 0, false, false)
    cameraActive = true
end

--- Destroy the active camera instantly
function Hydra.Identity.DestroyCamera()
    cameraActive = false
    if activeCam then
        SetCamActive(activeCam, false)
        RenderScriptCams(false, false, 0, false, false)
        DestroyCam(activeCam, true)
        activeCam = nil
    end
end

--- Rotate the ped
--- @param degrees number
function Hydra.Identity.RotatePed(degrees)
    local ped = Hydra.Identity.GetPreviewPed()
    if ped and DoesEntityExist(ped) then
        local heading = GetEntityHeading(ped) + degrees
        SetEntityHeading(ped, heading % 360.0)
    end
end

--- Zoom camera in/out
--- @param delta number positive = zoom in, negative = zoom out
function Hydra.Identity.ZoomCamera(delta)
    camDistance = math.max(MIN_DISTANCE, math.min(MAX_DISTANCE, camDistance - delta * 0.15))
    updateCamera()
end

--- Move camera up/down
--- @param delta number positive = up, negative = down
function Hydra.Identity.MoveCameraVertical(delta)
    camHeight = math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, camHeight + delta))
    updateCamera()
end

function Hydra.Identity.GetCamera()
    return activeCam
end

-- NUI callbacks
RegisterNUICallback('identity:rotatePed', function(data, cb)
    Hydra.Identity.RotatePed(tonumber(data.direction) or 0)
    cb({ ok = true })
end)

RegisterNUICallback('identity:cameraUp', function(_, cb)
    Hydra.Identity.MoveCameraVertical(0.05)
    cb({ ok = true })
end)

RegisterNUICallback('identity:cameraDown', function(_, cb)
    Hydra.Identity.MoveCameraVertical(-0.05)
    cb({ ok = true })
end)

RegisterNUICallback('identity:zoomIn', function(_, cb)
    Hydra.Identity.ZoomCamera(1)
    cb({ ok = true })
end)

RegisterNUICallback('identity:zoomOut', function(_, cb)
    Hydra.Identity.ZoomCamera(-1)
    cb({ ok = true })
end)

-- NUI scroll → zoom
RegisterNUICallback('identity:scroll', function(data, cb)
    if cameraActive then
        local delta = tonumber(data.delta) or 0
        Hydra.Identity.ZoomCamera(delta)
    end
    cb({ ok = true })
end)
