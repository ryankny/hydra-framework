--[[
    Hydra Identity - Ped Preview

    Spawns and manages the preview ped used during
    character creation and appearance customisation.
]]

Hydra = Hydra or {}
Hydra.Identity = Hydra.Identity or {}

local previewPed = nil

--- Spawn a preview ped for character creation
--- @param sex string 'male' | 'female'
function Hydra.Identity.SpawnPreviewPed(sex)
    -- Destroy existing preview ped
    Hydra.Identity.DestroyPreviewPed()

    local cfg = HydraIdentityConfig.camera.creation
    local defaults = HydraIdentityConfig.default_appearance
    local appearance = defaults[sex] or defaults.male

    local model = GetHashKey(appearance.model)
    RequestModel(model)

    local timeout = 0
    while not HasModelLoaded(model) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    if not HasModelLoaded(model) then
        return
    end

    local coords = cfg.ped_coords
    previewPed = CreatePed(2, model, coords.x, coords.y, coords.z, cfg.ped_heading or 0.0, false, true)

    SetEntityInvincible(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    FreezeEntityPosition(previewPed, true)
    SetEntityAlpha(previewPed, 255, false)
    TaskStandStill(previewPed, -1)

    -- Apply default appearance
    Hydra.Identity.ApplyDefaultAppearance(previewPed, appearance)

    SetModelAsNoLongerNeeded(model)
end

--- Get the preview ped handle
--- @return number|nil
function Hydra.Identity.GetPreviewPed()
    return previewPed
end

--- Destroy the preview ped
function Hydra.Identity.DestroyPreviewPed()
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    previewPed = nil
end

--- Apply default appearance values to a ped
--- @param ped number
--- @param appearance table
function Hydra.Identity.ApplyDefaultAppearance(ped, appearance)
    if not ped or not DoesEntityExist(ped) then return end

    -- Set head blend (face shape)
    local face = appearance.face or {}
    SetPedHeadBlendData(ped,
        face.shape_first or 0, face.shape_second or 0, face.shape_third or 0,
        face.skin_first or 0, face.skin_second or 0, face.skin_third or 0,
        face.shape_mix or 0.5, face.skin_mix or 0.5, face.third_mix or 0.0,
        false
    )

    -- Hair
    local hair = appearance.hair or {}
    SetPedComponentVariation(ped, 2, hair.style or 0, 0, 2)
    SetPedHairColor(ped, hair.color or 0, hair.highlight or 0)

    -- Beard / facial hair
    local beard = appearance.beard or {}
    if beard.style and beard.style >= 0 then
        SetPedHeadOverlay(ped, 1, beard.style, beard.opacity or 1.0)
        SetPedHeadOverlayColor(ped, 1, 1, beard.color or 0, beard.color or 0)
    else
        SetPedHeadOverlay(ped, 1, 255, 1.0)
    end

    -- Eyebrows
    local brows = appearance.eyebrows or {}
    SetPedHeadOverlay(ped, 2, brows.style or 0, brows.opacity or 1.0)
    SetPedHeadOverlayColor(ped, 2, 1, brows.color or 0, brows.color or 0)

    -- Eye color
    local eyes = appearance.eyes or {}
    SetPedEyeColor(ped, eyes.color or 0)
end
