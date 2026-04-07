--[[
    Hydra Identity - Client Main

    Orchestrates the character selection/creation flow.
    Manages transitions between selection, creation, and appearance screens.
]]

Hydra = Hydra or {}
Hydra.Identity = Hydra.Identity or {}

local isActive = false
local currentScreen = nil -- 'selection' | 'creation' | 'appearance'
local selectedCharId = nil
local creationData = {}

--- Show the identity UI
--- @param data table { characters, maxCharacters, spawnLocations, canDelete }
function Hydra.Identity.Show(data)
    if isActive then return end
    isActive = true
    currentScreen = 'selection'

    -- Make sure screen is faded IN
    if IsScreenFadedOut() or IsScreenFadingOut() then
        DoScreenFadeIn(0)
    end

    -- Hide and move the player ped
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityCoords(ped, 0.0, 0.0, -200.0, false, false, false, false)

    -- Send NUI data
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

    -- Set NUI focus in a thread with a small delay
    -- On first connect, FiveM's NUI cursor isn't ready immediately
    -- The /logout path works because the game is already fully loaded
    CreateThread(function()
        -- Wait for the game to be fully settled
        Wait(1000)
        if isActive then
            SetNuiFocus(true, true)
        end

        -- Hide HUD/radar while identity is active
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

--- Hide the identity UI
function Hydra.Identity.Hide()
    if not isActive then return end
    isActive = false
    currentScreen = nil

    -- Hide NUI and cursor FIRST (before releasing focus)
    SendNUIMessage({ module = 'identity', action = 'hide' })

    -- Release NUI focus
    SetNuiFocus(false, false)

    -- Clean up streaming
    ClearFocus()

    -- Destroy preview ped and camera
    Hydra.Identity.DestroyPreviewPed()
    Hydra.Identity.DestroyCamera()

    -- Make player ped visible
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
end

--- Switch to a different screen
--- @param screen string
--- @param data table|nil
function Hydra.Identity.SwitchScreen(screen, data)
    currentScreen = screen

    -- Switch NUI screen immediately
    SendNUIMessage({
        module = 'identity',
        action = 'switchScreen',
        data = {
            screen = screen,
            extra = data,
        },
    })

    if screen == 'creation' then
        creationData = {}
        -- Creation is just a form — game screen stays faded out, NUI is the background
    elseif screen == 'appearance' then
        -- Spawn ped and camera in a thread (has Wait calls)
        CreateThread(function()
            local cfg = HydraIdentityConfig.camera.creation
            local px, py, pz = cfg.ped_coords.x, cfg.ped_coords.y, cfg.ped_coords.z

            -- Stream in the area
            SetFocusPosAndVel(px, py, pz, 0.0, 0.0, 0.0)
            RequestCollisionAtCoord(px, py, pz)
            Wait(2000)

            Hydra.Identity.SpawnPreviewPed(creationData.sex or 'male')
            Hydra.Identity.SetupCamera('appearance')
            DoScreenFadeIn(500)
        end)
    elseif screen == 'selection' then
        Hydra.Identity.DestroyPreviewPed()
        Hydra.Identity.DestroyCamera()
        ClearFocus()
        -- Don't fade out — NUI background covers everything
        -- Player is underground so game world is black anyway
    end
end

--- Event: Server sends character selection data
RegisterNetEvent('hydra:identity:showSelection')
AddEventHandler('hydra:identity:showSelection', function(data)
    Hydra.Identity.Show(data)
end)

--- Event: Character loaded successfully
RegisterNetEvent('hydra:identity:characterLoaded')
AddEventHandler('hydra:identity:characterLoaded', function(data)
    -- Hide identity UI and cursor
    Hydra.Identity.Hide()

    -- Kill ALL scripted cameras immediately (no transition)
    RenderScriptCams(false, false, 0, false, false)
    DestroyAllCams(true)

    -- Fade out for clean transition
    DoScreenFadeOut(0)
    Wait(200)

    -- Spawn position (default to Legion Square)
    local pos = data.position
    if not pos or not pos.x then
        pos = { x = 215.76, y = -810.12, z = 30.73, heading = 90.0 }
    end

    -- Set the correct freemode model
    local sex = data.charinfo and data.charinfo.sex or 'male'
    local modelName = sex == 'female' and 'mp_f_freemode_01' or 'mp_m_freemode_01'
    local model = GetHashKey(modelName)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)

    -- Get fresh ped reference after model change
    local ped = PlayerPedId()

    -- Move to spawn position BEFORE applying appearance
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, pos.heading or 0.0)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)

    -- Apply appearance
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

    -- Wait for world to load
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    local timeout = GetGameTimer() + 10000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(100)
    end
    Wait(500)

    -- Final camera reset
    RenderScriptCams(false, false, 0, false, false)
    DestroyAllCams(true)

    -- Explicitly clear NUI focus keep input (in case anything leaked)
    SetNuiFocusKeepInput(false)

    -- Reset the gameplay camera to behind the player
    SetGameplayCamRelativeHeading(0.0)
    SetGameplayCamRelativePitch(0.0, 1.0)

    -- Unfreeze and fade in
    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
    DoScreenFadeIn(1000)
end)

--- Event: Character created, update list
RegisterNetEvent('hydra:identity:characterCreated')
AddEventHandler('hydra:identity:characterCreated', function(data)
    Hydra.Identity.SwitchScreen('selection', {
        characters = data.characters,
        newCharId = data.newCharId,
    })
end)

--- Event: Character deleted, update list
RegisterNetEvent('hydra:identity:characterDeleted')
AddEventHandler('hydra:identity:characterDeleted', function(data)
    SendNUIMessage({
        module = 'identity',
        action = 'updateCharacters',
        data = { characters = data.characters },
    })
end)

--- Event: Error from server
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

--- NUI: Select a character
RegisterNUICallback('identity:selectCharacter', function(data, cb)
    if not isActive then cb({ ok = false }) return end

    selectedCharId = data.characterId
    local spawnLocation = data.spawnLocation

    local camOk = pcall(function() exports['hydra_camera']:FadeOut(500) end)
    if not camOk then DoScreenFadeOut(500) end
    Wait(600)

    TriggerServerEvent('hydra:identity:selectCharacter', selectedCharId, spawnLocation)
    cb({ ok = true })
end)

--- NUI: Start character creation
RegisterNUICallback('identity:startCreation', function(_, cb)
    if not isActive then cb({ ok = false }) return end
    Hydra.Identity.SwitchScreen('creation')
    cb({ ok = true })
end)

--- NUI: Sex changed during creation (swap ped model)
RegisterNUICallback('identity:changeSex', function(data, cb)
    if not isActive then cb({ ok = false }) return end
    Hydra.Identity.SpawnPreviewPed(data.sex or 'male')
    cb({ ok = true })
end)

--- NUI: Submit character creation form, go to appearance
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

--- NUI: Appearance changed (live preview)
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

--- NUI: Finalize character (create on server with appearance)
RegisterNUICallback('identity:finishCreation', function(data, cb)
    if not isActive then cb({ ok = false }) return end

    creationData.appearance = data.appearance or {}
    creationData.clothing = data.clothing or {}

    TriggerServerEvent('hydra:identity:createCharacter', creationData)
    cb({ ok = true })
end)

--- NUI: Delete character
RegisterNUICallback('identity:deleteCharacter', function(data, cb)
    if not isActive then cb({ ok = false }) return end
    TriggerServerEvent('hydra:identity:deleteCharacter', data.characterId)
    cb({ ok = true })
end)

--- NUI: Go back to selection from creation/appearance
RegisterNUICallback('identity:backToSelection', function(_, cb)
    if not isActive then cb({ ok = false }) return end
    Hydra.Identity.SwitchScreen('selection')
    cb({ ok = true })
end)

--- NUI: Rotate preview ped
RegisterNUICallback('identity:rotatePed', function(data, cb)
    local ped = Hydra.Identity.GetPreviewPed()
    if ped then
        local heading = GetEntityHeading(ped) + (data.direction or 0)
        SetEntityHeading(ped, heading % 360.0)
    end
    cb({ ok = true })
end)

-- ==========================================
-- LOGOUT
-- ==========================================

--- Server tells us to go back to character selection
RegisterNetEvent('hydra:identity:logout')
AddEventHandler('hydra:identity:logout', function(data)
    -- Hide HUD
    if Hydra.HUD and Hydra.HUD.SetVisible then
        Hydra.HUD.SetVisible(false)
    end

    -- Reset characterLoaded flag in HUD (by sending a hide event)
    SendNUIMessage({ module = 'hud', action = 'setVisible', data = { visible = false } })

    -- Fade out
    DoScreenFadeOut(500)
    Wait(600)

    -- Reset camera
    RenderScriptCams(false, false, 0, true, false)

    -- Show character selection
    Hydra.Identity.Show(data)
end)

RegisterCommand('logout', function()
    TriggerServerEvent('hydra:identity:logout')
end, false)
