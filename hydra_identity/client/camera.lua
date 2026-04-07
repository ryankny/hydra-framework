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

    -- Camera at chest level (ped_coords.z is feet), head is ~1.7m up
    local lookAt = vector3(pedCoords.x, pedCoords.y, pedCoords.z + 1.0)
    local position = vector3(camCoords.x, camCoords.y, camCoords.z + 1.0)
    local fov = 35.0

    if screen == 'selection' then
        fov = 40.0
    elseif screen == 'appearance' then
        -- Closer shot focused on face
        local dir = lookAt - position
        position = position + dir * 0.5
        position = vector3(position.x, position.y, position.z + 0.3)
        lookAt = vector3(pedCoords.x, pedCoords.y, pedCoords.z + 1.5)
        fov = 25.0
    end

    -- Use hydra_camera if available
    if hasCamera then
        local ok, camId = pcall(function()
            return exports['hydra_camera']:Create({
                position = position,
                target = lookAt,
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
    PointCamAtCoord(activeCam, lookAt.x, lookAt.y, lookAt.z)
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
