--[[
    Hydra Identity - Camera Control

    Interactive camera that orbits around the preview ped.
    - Mouse scroll / NUI buttons: rotate ped left/right
    - NUI buttons: move camera up/down
    - Automatically adjusts for creation vs appearance screens
]]

Hydra = Hydra or {}
Hydra.Identity = Hydra.Identity or {}

local activeCam = nil
local currentAngle = 0.0    -- horizontal orbit angle in degrees
local currentHeight = 0.5   -- camera height offset from ped feet
local currentScreen = nil
local cameraActive = false

--- Get camera config for current screen
local function getCamParams()
    local cfg = HydraIdentityConfig.camera.creation
    if currentScreen == 'appearance' then
        return {
            distance = cfg.appearance_distance or 0.9,
            height = cfg.appearance_height or 0.65,
            fov = cfg.appearance_fov or 28.0,
        }
    end
    return {
        distance = cfg.distance or 1.8,
        height = currentHeight,
        fov = cfg.fov or 35.0,
    }
end

--- Update camera position based on current angle and height
local function updateCamera()
    if not activeCam then return end

    local cfg = HydraIdentityConfig.camera.creation
    local pedCoords = vector3(cfg.ped_coords.x, cfg.ped_coords.y, cfg.ped_coords.z)
    local params = getCamParams()

    -- Calculate camera position orbiting around the ped
    local rad = math.rad(currentAngle)
    local camX = pedCoords.x + math.sin(rad) * params.distance
    local camY = pedCoords.y + math.cos(rad) * params.distance
    local camZ = pedCoords.z + params.height

    -- Look at ped upper body
    local lookZ = pedCoords.z + 0.6
    if currentScreen == 'appearance' then
        lookZ = pedCoords.z + 0.65
    end

    SetCamCoord(activeCam, camX, camY, camZ)
    PointCamAtCoord(activeCam, pedCoords.x, pedCoords.y, lookZ)
    SetCamFov(activeCam, params.fov)
end

--- Setup camera for a given screen
--- @param screen string 'creation' | 'appearance'
function Hydra.Identity.SetupCamera(screen)
    Hydra.Identity.DestroyCamera()

    currentScreen = screen
    local cfg = HydraIdentityConfig.camera.creation

    -- Reset angle and height
    currentAngle = 0.0
    currentHeight = cfg.height_offset or 0.5

    -- Create native camera
    activeCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    updateCamera()
    SetCamActive(activeCam, true)
    RenderScriptCams(true, true, 500, true, false)
    cameraActive = true
end

--- Destroy the active camera
function Hydra.Identity.DestroyCamera()
    cameraActive = false
    if activeCam then
        SetCamActive(activeCam, false)
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(activeCam, false)
        activeCam = nil
    end
end

--- Rotate the ped (called from NUI buttons or scroll)
--- @param degrees number positive = clockwise, negative = counter-clockwise
function Hydra.Identity.RotatePed(degrees)
    local ped = Hydra.Identity.GetPreviewPed()
    if ped and DoesEntityExist(ped) then
        local heading = GetEntityHeading(ped) + degrees
        SetEntityHeading(ped, heading % 360.0)
    end
end

--- Move camera up/down (constrained)
--- @param delta number positive = up, negative = down
function Hydra.Identity.MoveCamera(delta)
    if currentScreen == 'appearance' then return end -- fixed for appearance

    local cfg = HydraIdentityConfig.camera.creation
    local minH = cfg.min_height or -0.3
    local maxH = cfg.max_height or 1.2

    currentHeight = math.max(minH, math.min(maxH, currentHeight + delta))
    updateCamera()
end

--- Get the active camera handle
--- @return number|nil
function Hydra.Identity.GetCamera()
    return activeCam
end

-- NUI callbacks for camera controls
RegisterNUICallback('identity:rotatePed', function(data, cb)
    local dir = tonumber(data.direction) or 0
    Hydra.Identity.RotatePed(dir)
    cb({ ok = true })
end)

RegisterNUICallback('identity:cameraUp', function(_, cb)
    Hydra.Identity.MoveCamera(0.1)
    cb({ ok = true })
end)

RegisterNUICallback('identity:cameraDown', function(_, cb)
    Hydra.Identity.MoveCamera(-0.1)
    cb({ ok = true })
end)

-- NUI scroll callback — JS sends wheel events through here
RegisterNUICallback('identity:scroll', function(data, cb)
    if cameraActive then
        local dir = tonumber(data.delta) or 0
        if dir > 0 then
            Hydra.Identity.RotatePed(15.0)
        elseif dir < 0 then
            Hydra.Identity.RotatePed(-15.0)
        end
    end
    cb({ ok = true })
end)
