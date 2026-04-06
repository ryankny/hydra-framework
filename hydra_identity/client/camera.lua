--[[
    Hydra Identity - Camera Control

    Manages camera positioning for character selection,
    creation, and appearance screens. Uses hydra_camera
    when available, falls back to native GTA camera API.
]]

Hydra = Hydra or {}
Hydra.Identity = Hydra.Identity or {}

local activeCam = nil
local activeCamId = nil
local hasCamera = false

-- Detect hydra_camera availability
CreateThread(function()
    Wait(1000)
    hasCamera = pcall(function() return exports['hydra_camera'] end)
end)

--- Setup camera for a given screen
--- @param screen string 'selection' | 'creation' | 'appearance'
function Hydra.Identity.SetupCamera(screen)
    -- Destroy existing camera
    Hydra.Identity.DestroyCamera()

    local cfg = HydraIdentityConfig.camera
    local camCfg = cfg.creation -- default

    local camCoords = vector3(camCfg.coords.x, camCfg.coords.y, camCfg.coords.z)
    local pedCoords = vector3(camCfg.ped_coords.x, camCfg.ped_coords.y, camCfg.ped_coords.z)

    local fov = 45.0
    local position = camCoords

    if screen == 'appearance' then
        local offset = (pedCoords - camCoords) * 0.35
        position = camCoords + offset
        position = vector3(position.x, position.y, position.z + 0.3)
        fov = 35.0
    end

    -- Use hydra_camera if available
    if hasCamera then
        local ok, camId = pcall(function()
            return exports['hydra_camera']:Create({
                position = position,
                target = pedCoords,
                fov = fov,
                active = true,
                transition = 500,
                label = 'identity_' .. screen,
            })
        end)
        if ok and camId then
            activeCamId = camId
            return
        end
    end

    -- Fallback: native camera
    activeCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(activeCam, position.x, position.y, position.z)
    PointCamAtCoord(activeCam, pedCoords.x, pedCoords.y, pedCoords.z)
    SetCamFov(activeCam, fov)
    SetCamActive(activeCam, true)
    RenderScriptCams(true, true, 500, true, false)
end

--- Destroy the active camera
function Hydra.Identity.DestroyCamera()
    -- Destroy via hydra_camera
    if hasCamera and activeCamId then
        pcall(function() exports['hydra_camera']:Destroy(activeCamId) end)
        activeCamId = nil
    end

    -- Destroy native fallback
    if activeCam then
        SetCamActive(activeCam, false)
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(activeCam, false)
        activeCam = nil
    end
end

--- Get the active camera handle (native) or ID (hydra_camera)
--- @return number|string|nil
function Hydra.Identity.GetCamera()
    return activeCamId or activeCam
end
