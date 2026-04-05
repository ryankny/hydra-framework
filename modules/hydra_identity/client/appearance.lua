--[[
    Hydra Identity - Appearance Application

    Applies appearance and clothing data to peds.
    Used both for preview ped and the player ped on spawn.
]]

Hydra = Hydra or {}
Hydra.Identity = Hydra.Identity or {}

--- Apply full appearance data to a ped
--- @param ped number
--- @param data table
function Hydra.Identity.ApplyAppearance(ped, data)
    if not ped or not DoesEntityExist(ped) then return end

    -- Model (if specified and different)
    if data.model then
        local model = GetHashKey(data.model)
        if GetEntityModel(ped) ~= model then
            RequestModel(model)
            local timeout = 0
            while not HasModelLoaded(model) and timeout < 5000 do
                Wait(10)
                timeout = timeout + 10
            end
            if HasModelLoaded(model) then
                SetPlayerModel(PlayerId(), model)
                SetModelAsNoLongerNeeded(model)
                ped = PlayerPedId()
            end
        end
    end

    -- Head blend / face shape
    if data.face then
        local f = data.face
        SetPedHeadBlendData(ped,
            f.shape_first or 0, f.shape_second or 0, f.shape_third or 0,
            f.skin_first or 0, f.skin_second or 0, f.skin_third or 0,
            f.shape_mix or 0.5, f.skin_mix or 0.5, f.third_mix or 0.0,
            false
        )
    end

    -- Face features (nose width, chin shape, etc.)
    if data.features then
        for i = 0, 19 do
            SetPedFaceFeature(ped, i, data.features[i] or 0.0)
        end
    end

    -- Hair
    if data.hair then
        SetPedComponentVariation(ped, 2, data.hair.style or 0, 0, 2)
        SetPedHairColor(ped, data.hair.color or 0, data.hair.highlight or 0)
    end

    -- Head overlays (beard, eyebrows, makeup, blemishes, etc.)
    if data.overlays then
        for _, overlay in ipairs(data.overlays) do
            if overlay.index then
                SetPedHeadOverlay(ped, overlay.index, overlay.style or 255, overlay.opacity or 1.0)
                if overlay.color ~= nil then
                    local colorType = overlay.colorType or 1
                    SetPedHeadOverlayColor(ped, overlay.index, colorType, overlay.color, overlay.color)
                end
            end
        end
    else
        -- Legacy format: individual beard/eyebrow fields
        if data.beard then
            local b = data.beard
            if b.style and b.style >= 0 then
                SetPedHeadOverlay(ped, 1, b.style, b.opacity or 1.0)
                SetPedHeadOverlayColor(ped, 1, 1, b.color or 0, b.color or 0)
            else
                SetPedHeadOverlay(ped, 1, 255, 1.0)
            end
        end

        if data.eyebrows then
            local e = data.eyebrows
            SetPedHeadOverlay(ped, 2, e.style or 0, e.opacity or 1.0)
            SetPedHeadOverlayColor(ped, 2, 1, e.color or 0, e.color or 0)
        end
    end

    -- Eye color
    if data.eyes then
        SetPedEyeColor(ped, data.eyes.color or 0)
    end
end

--- Apply clothing/components to a ped
--- @param ped number
--- @param data table
function Hydra.Identity.ApplyClothing(ped, data)
    if not ped or not DoesEntityExist(ped) then return end

    -- Standard components (0-11)
    if data.components then
        for _, comp in ipairs(data.components) do
            if comp.id then
                SetPedComponentVariation(ped, comp.id, comp.drawable or 0, comp.texture or 0, comp.palette or 2)
            end
        end
    end

    -- Props (hats, glasses, watches, etc.)
    if data.props then
        for _, prop in ipairs(data.props) do
            if prop.id then
                if prop.drawable == -1 then
                    ClearPedProp(ped, prop.id)
                else
                    SetPedPropIndex(ped, prop.id, prop.drawable or 0, prop.texture or 0, true)
                end
            end
        end
    end
end

--- Get appearance data from a ped (serialize current state)
--- @param ped number
--- @return table
function Hydra.Identity.GetAppearanceFromPed(ped)
    if not ped or not DoesEntityExist(ped) then return {} end

    local appearance = {}

    -- Model
    local model = GetEntityModel(ped)
    if model == GetHashKey('mp_m_freemode_01') then
        appearance.model = 'mp_m_freemode_01'
    elseif model == GetHashKey('mp_f_freemode_01') then
        appearance.model = 'mp_f_freemode_01'
    end

    -- Hair
    appearance.hair = {
        style = GetPedDrawableVariation(ped, 2),
        color = GetPedHairColor(ped),
        highlight = GetPedHairHighlightColor(ped),
    }

    -- Face features
    appearance.features = {}
    for i = 0, 19 do
        appearance.features[i] = GetPedFaceFeature(ped, i)
    end

    -- Eye color
    appearance.eyes = {
        color = GetPedEyeColor(ped),
    }

    -- Head overlays
    appearance.overlays = {}
    for i = 0, 12 do
        local success, value, colorType, firstColor, secondColor, opacity =
            GetPedHeadOverlayData(ped, i)
        if success then
            appearance.overlays[#appearance.overlays + 1] = {
                index = i,
                style = value,
                opacity = opacity,
                color = firstColor,
                colorType = colorType,
            }
        end
    end

    return appearance
end

--- Get clothing data from a ped (serialize current state)
--- @param ped number
--- @return table
function Hydra.Identity.GetClothingFromPed(ped)
    if not ped or not DoesEntityExist(ped) then return {} end

    local clothing = { components = {}, props = {} }

    -- Components (0-11)
    for i = 0, 11 do
        clothing.components[#clothing.components + 1] = {
            id = i,
            drawable = GetPedDrawableVariation(ped, i),
            texture = GetPedTextureVariation(ped, i),
            palette = GetPedPaletteVariation(ped, i),
        }
    end

    -- Props (0-8)
    for i = 0, 8 do
        clothing.props[#clothing.props + 1] = {
            id = i,
            drawable = GetPedPropIndex(ped, i),
            texture = GetPedPropTextureIndex(ped, i),
        }
    end

    return clothing
end
