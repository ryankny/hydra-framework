--[[
    Hydra Identity - Client Main

    Smooth flow:
    1. Selection: Full NUI screen (gradient bg), no 3D world
    2. Creation: Full NUI screen (gradient bg), no 3D world
    3. Appearance: NUI panel on left, 3D ped preview on right
    4. Spawn: GTA Online satellite zoom-in via SwitchInPlayer
]]

Hydra = Hydra or {}
Hydra.Identity = Hydra.Identity or {}

local isActive = false
local currentScreen = nil
local selectedCharId = nil
local creationData = {}
local appearanceReady = false  -- true once ped/camera are set up for appearance

-- ==========================================
-- SHOW / HIDE
-- ==========================================

function Hydra.Identity.Show(data)
    if isActive then return end
    isActive = true
    currentScreen = 'selection'
    appearanceReady = false

    -- Ensure screen is visible (not faded out)
    if IsScreenFadedOut() or IsScreenFadingOut() then
        DoScreenFadeIn(0)
    end

    -- Hide player ped (stays at current pos, just invisible)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityAlpha(ped, 0, false)

    -- Send NUI data (renders the selection screen)
    SendNUIMessage({
        module = 'identity',
        action = 'show',
        data = {
            screen = 'selection',
            characters = data.characters,
            maxCharacters = data.maxCharacters,
            spawnLocations = data.spawnLocations,
            canDelete = data.canDelete,
            nationalities = HydraIdentityConfig.nationalities,
            creation = HydraIdentityConfig.creation,
        },
    })

    -- Enable cursor with delay on first load (FiveM NUI cursor needs game to settle)
    CreateThread(function()
        Wait(1000)
        if isActive then
            SetNuiFocus(true, true)
        end

        -- Hide HUD/radar
        while isActive do
            DisplayRadar(false)
            DisplayHud(false)
            HideHudAndRadarThisFrame()
            Wait(0)
        end
        DisplayRadar(true)
        DisplayHud(true)
    end)
end

function Hydra.Identity.Hide()
    if not isActive then return end
    isActive = false
    currentScreen = nil
    appearanceReady = false

    SendNUIMessage({ module = 'identity', action = 'hide' })
    SetNuiFocus(false, false)
    ClearFocus()

    Hydra.Identity.DestroyPreviewPed()
    Hydra.Identity.DestroyCamera()

    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    ResetEntityAlpha(ped)
end

-- ==========================================
-- SCREEN SWITCHING
-- ==========================================

function Hydra.Identity.SwitchScreen(screen, data)
    local prevScreen = currentScreen
    currentScreen = screen

    if screen == 'creation' then
        -- Creation is a form — clean up any appearance preview
        creationData = {}
        if appearanceReady then
            Hydra.Identity.DestroyPreviewPed()
            Hydra.Identity.DestroyCamera()
            ClearFocus()
            appearanceReady = false
        end

        -- Switch NUI immediately
        SendNUIMessage({
            module = 'identity',
            action = 'switchScreen',
            data = { screen = screen, extra = data },
        })

    elseif screen == 'appearance' then
        -- Show a loading state in NUI first
        SendNUIMessage({
            module = 'identity',
            action = 'switchScreen',
            data = { screen = screen, extra = data, loading = true },
        })

        -- Load the 3D preview in a thread
        CreateThread(function()
            local cfg = HydraIdentityConfig.camera.creation
            local px, py, pz = cfg.ped_coords.x, cfg.ped_coords.y, cfg.ped_coords.z

            -- Stream the preview area
            SetFocusPosAndVel(px, py, pz, 0.0, 0.0, 0.0)
            RequestCollisionAtCoord(px, py, pz)

            -- Wait for area to load
            local timeout = GetGameTimer() + 5000
            while GetGameTimer() < timeout do
                RequestCollisionAtCoord(px, py, pz)
                Wait(100)
            end

            -- Bail if user navigated away
            if currentScreen ~= 'appearance' then
                ClearFocus()
                return
            end

            -- Spawn preview ped and camera
            Hydra.Identity.SpawnPreviewPed(creationData.sex or 'male')
            Hydra.Identity.SetupCamera('appearance')
            appearanceReady = true

            -- Tell NUI the preview is ready (hides loading spinner)
            SendNUIMessage({
                module = 'identity',
                action = 'appearanceReady',
            })
        end)

    elseif screen == 'selection' then
        -- Clean up appearance preview
        if appearanceReady then
            Hydra.Identity.DestroyPreviewPed()
            Hydra.Identity.DestroyCamera()
            ClearFocus()
            appearanceReady = false
        end

        SendNUIMessage({
            module = 'identity',
            action = 'switchScreen',
            data = { screen = screen, extra = data },
        })
    end
end

-- ==========================================
-- EVENTS
-- ==========================================

RegisterNetEvent('hydra:identity:showSelection')
AddEventHandler('hydra:identity:showSelection', function(data)
    Hydra.Identity.Show(data)
end)

--- Character loaded — spawn into the world
RegisterNetEvent('hydra:identity:characterLoaded')
AddEventHandler('hydra:identity:characterLoaded', function(data)
    Hydra.Identity.Hide()

    -- Clean slate
    RenderScriptCams(false, false, 0, false, false)
    DestroyAllCams(true)
    DoScreenFadeOut(0)
    Wait(200)

    -- Spawn position
    local pos = data.position
    if not pos or not pos.x then
        pos = { x = 215.76, y = -810.12, z = 30.73, heading = 90.0 }
    end

    -- Set freemode model
    local sex = data.charinfo and data.charinfo.sex or 'male'
    local modelName = sex == 'female' and 'mp_f_freemode_01' or 'mp_m_freemode_01'
    local model = GetHashKey(modelName)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    local ped = PlayerPedId()

    -- Position
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, pos.heading or 0.0)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    ResetEntityAlpha(ped)

    -- Appearance
    if data.appearance and next(data.appearance) then
        Hydra.Identity.ApplyAppearance(ped, data.appearance)
        ped = PlayerPedId()
    end
    if data.clothing and next(data.clothing) then
        Hydra.Identity.ApplyClothing(ped, data.clothing)
    end
    if not data.appearance or not next(data.appearance) then
        SetPedDefaultComponentVariation(ped)
    end

    -- Load world
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    local timeout = GetGameTimer() + 10000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(100)
    end

    -- Clean state
    SetNuiFocusKeepInput(false)
    RenderScriptCams(false, false, 0, false, false)
    DestroyAllCams(true)
    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)

    -- GTA Online satellite zoom-in
    DoScreenFadeIn(0)
    SwitchInPlayer(ped)

    while GetPlayerSwitchState() ~= 12 do
        Wait(0)
    end
end)

RegisterNetEvent('hydra:identity:characterCreated')
AddEventHandler('hydra:identity:characterCreated', function(data)
    Hydra.Identity.SwitchScreen('selection', {
        characters = data.characters,
        newCharId = data.newCharId,
    })
end)

RegisterNetEvent('hydra:identity:characterDeleted')
AddEventHandler('hydra:identity:characterDeleted', function(data)
    SendNUIMessage({
        module = 'identity',
        action = 'updateCharacters',
        data = { characters = data.characters },
    })
end)

RegisterNetEvent('hydra:identity:error')
AddEventHandler('hydra:identity:error', function(msg)
    SendNUIMessage({
        module = 'identity',
        action = 'showError',
        data = { message = msg },
    })
end)

-- ==========================================
-- NUI Callbacks
-- ==========================================

RegisterNUICallback('identity:selectCharacter', function(data, cb)
    if not isActive then cb({ ok = false }) return end
    selectedCharId = data.characterId
    local spawnLocation = data.spawnLocation

    DoScreenFadeOut(500)
    Wait(600)

    TriggerServerEvent('hydra:identity:selectCharacter', selectedCharId, spawnLocation)
    cb({ ok = true })
end)

RegisterNUICallback('identity:startCreation', function(_, cb)
    if not isActive then cb({ ok = false }) return end
    Hydra.Identity.SwitchScreen('creation')
    cb({ ok = true })
end)

RegisterNUICallback('identity:changeSex', function(data, cb)
    if not isActive then cb({ ok = false }) return end
    if appearanceReady then
        Hydra.Identity.SpawnPreviewPed(data.sex or 'male')
    end
    cb({ ok = true })
end)

RegisterNUICallback('identity:submitCreation', function(data, cb)
    if not isActive then cb({ ok = false }) return end

    creationData = {
        firstname = data.firstname,
        lastname = data.lastname,
        sex = data.sex,
        dob = data.dob,
        nationality = data.nationality,
    }

    Hydra.Identity.SwitchScreen('appearance', { sex = data.sex })
    cb({ ok = true })
end)

RegisterNUICallback('identity:updateAppearance', function(data, cb)
    local ped = Hydra.Identity.GetPreviewPed()
    if ped then
        if data.appearance then
            Hydra.Identity.ApplyAppearance(ped, data.appearance)
        end
        if data.clothing then
            Hydra.Identity.ApplyClothing(ped, data.clothing)
        end
    end
    cb({ ok = true })
end)

RegisterNUICallback('identity:finishCreation', function(data, cb)
    if not isActive then cb({ ok = false }) return end
    creationData.appearance = data.appearance or {}
    creationData.clothing = data.clothing or {}
    TriggerServerEvent('hydra:identity:createCharacter', creationData)
    cb({ ok = true })
end)

RegisterNUICallback('identity:deleteCharacter', function(data, cb)
    if not isActive then cb({ ok = false }) return end
    TriggerServerEvent('hydra:identity:deleteCharacter', data.characterId)
    cb({ ok = true })
end)

RegisterNUICallback('identity:backToSelection', function(_, cb)
    if not isActive then cb({ ok = false }) return end
    Hydra.Identity.SwitchScreen('selection')
    cb({ ok = true })
end)

RegisterNUICallback('identity:rotatePed', function(data, cb)
    local ped = Hydra.Identity.GetPreviewPed()
    if ped then
        SetEntityHeading(ped, (GetEntityHeading(ped) + (data.direction or 0)) % 360.0)
    end
    cb({ ok = true })
end)

-- ==========================================
-- LOGOUT
-- ==========================================

RegisterNetEvent('hydra:identity:logout')
AddEventHandler('hydra:identity:logout', function(data)
    if Hydra.HUD and Hydra.HUD.SetVisible then
        Hydra.HUD.SetVisible(false)
    end
    SendNUIMessage({ module = 'hud', action = 'setVisible', data = { visible = false } })

    DoScreenFadeOut(500)
    Wait(600)

    RenderScriptCams(false, false, 0, false, false)
    DestroyAllCams(true)

    Hydra.Identity.Show(data)
end)

RegisterCommand('logout', function()
    TriggerServerEvent('hydra:identity:logout')
end, false)
