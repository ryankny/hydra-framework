--[[
    Hydra Identity - Camera Control

    Manages camera positioning for character selection,
    creation, and appearance screens.
]]

Hydra = Hydra or {}
Hydra.Identity = Hydra.Identity or {}

local activeCam = nil

--- Setup camera for a given screen
--- @param screen string 'selection' | 'creation' | 'appearance'
function Hydra.Identity.SetupCamera(screen)
    -- Destroy existing camera
    Hydra.Identity.DestroyCamera()

    local cfg = HydraIdentityConfig.camera
    local camCfg = cfg.creation -- default

    local camCoords = vector3(camCfg.coords.x, camCfg.coords.y, camCfg.coords.z)
    local pedCoords = vector3(camCfg.ped_coords.x, camCfg.ped_coords.y, camCfg.ped_coords.z)

    activeCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(activeCam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(activeCam, pedCoords.x, pedCoords.y, pedCoords.z)
    SetCamFov(activeCam, 45.0)

    if screen == 'appearance' then
        -- Closer camera for appearance editing
        local offset = (pedCoords - camCoords) * 0.35
        local closerPos = camCoords + offset
        SetCamCoord(activeCam, closerPos.x, closerPos.y, closerPos.z + 0.3)
        SetCamFov(activeCam, 35.0)
    end

    SetCamActive(activeCam, true)
    RenderScriptCams(true, true, 500, true, false)
end

--- Destroy the active camera
function Hydra.Identity.DestroyCamera()
    if activeCam then
        SetCamActive(activeCam, false)
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(activeCam, false)
        activeCam = nil
    end
end

--- Get the active camera handle
--- @return number|nil
function Hydra.Identity.GetCamera()
    return activeCam
end
