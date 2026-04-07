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

    -- Wait for loading screen to finish shutting down
    while GetIsLoadingScreenActive() do
        Wait(100)
    end
    -- Extra buffer for NUI shutdown animation
    Wait(2000)

    -- Freeze and hide player ped
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)

    -- For selection screen: keep game screen black, NUI provides the full UI
    -- The 3D ped preview only appears in creation/appearance screens
    if not IsScreenFadedOut() then
        DoScreenFadeOut(0)
        Wait(100)
    end

    -- Enable NUI cursor
    SetNuiFocus(true, true)

    -- Block all game input, hide HUD/radar while identity is active
    CreateThread(function()
        while isActive do
            -- Disable all player controls so clicks don't attack/shoot
            DisableControlAction(0, 24, true)   -- Attack
            DisableControlAction(0, 25, true)   -- Aim
            DisableControlAction(0, 37, true)   -- Select weapon
            DisableControlAction(0, 44, true)   -- Cover
            DisableControlAction(0, 47, true)   -- Detonate
            DisableControlAction(0, 58, true)   -- Throw grenade
            DisableControlAction(0, 69, true)   -- Vehicle attack
            DisableControlAction(0, 70, true)   -- Vehicle attack 2
            DisableControlAction(0, 92, true)   -- Vehicle passenger attack
            DisableControlAction(0, 114, true)  -- Fly attack
            DisableControlAction(0, 140, true)  -- Melee light
            DisableControlAction(0, 141, true)  -- Melee heavy
            DisableControlAction(0, 142, true)  -- Melee alternate
            DisableControlAction(0, 257, true)  -- Attack 2
            DisableControlAction(0, 263, true)  -- Melee attack 1
            DisableControlAction(0, 264, true)  -- Melee attack 2
            DisableControlAction(0, 30, true)   -- Move LR
            DisableControlAction(0, 31, true)   -- Move UD
            DisableControlAction(0, 21, true)   -- Sprint
            DisableControlAction(0, 22, true)   -- Jump
            DisableControlAction(0, 23, true)   -- Enter vehicle
            DisableControlAction(0, 75, true)   -- Exit vehicle
            DisableControlAction(0, 73, true)   -- Vehicle handbrake
            DisableControlAction(0, 1, true)    -- Camera LR
            DisableControlAction(0, 2, true)    -- Camera UD

            DisplayRadar(false)
            DisplayHud(false)
            Wait(0)
        end
        DisplayRadar(true)
        DisplayHud(true)
    end)

    -- Send data to NUI
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
end

--- Hide the identity UI
function Hydra.Identity.Hide()
    if not isActive then return end
    isActive = false
    currentScreen = nil

    SetNuiFocus(false, false)

    -- Destroy preview ped and camera
    Hydra.Identity.DestroyPreviewPed()
    Hydra.Identity.DestroyCamera()

    -- Unfreeze player
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)

    SendNUIMessage({
        module = 'identity',
        action = 'hide',
    })
end

--- Switch to a different screen
--- @param screen string
--- @param data table|nil
function Hydra.Identity.SwitchScreen(screen, data)
    currentScreen = screen

    if screen == 'creation' then
        creationData = {}
        -- Move player to preview location and fade in the 3D scene
        local cfg = HydraIdentityConfig.camera.creation
        local ped = PlayerPedId()
        SetEntityCoords(ped, cfg.ped_coords.x, cfg.ped_coords.y, cfg.ped_coords.z, false, false, false, false)
        RequestCollisionAtCoord(cfg.ped_coords.x, cfg.ped_coords.y, cfg.ped_coords.z)
        Wait(300)
        Hydra.Identity.SetupCamera('creation')
        Hydra.Identity.SpawnPreviewPed('male')
        DoScreenFadeIn(500)
    elseif screen == 'appearance' then
        Hydra.Identity.SetupCamera('appearance')
    elseif screen == 'selection' then
        Hydra.Identity.DestroyPreviewPed()
        Hydra.Identity.DestroyCamera()
        DoScreenFadeOut(300)
    end

    SendNUIMessage({
        module = 'identity',
        action = 'switchScreen',
        data = {
            screen = screen,
            extra = data,
        },
    })
end

--- Event: Server sends character selection data
RegisterNetEvent('hydra:identity:showSelection')
AddEventHandler('hydra:identity:showSelection', function(data)
    Hydra.Identity.Show(data)
end)

--- Event: Character loaded successfully
RegisterNetEvent('hydra:identity:characterLoaded')
AddEventHandler('hydra:identity:characterLoaded', function(data)
    Hydra.Identity.Hide()

    -- Apply appearance
    if data.appearance and next(data.appearance) then
        Hydra.Identity.ApplyAppearance(PlayerPedId(), data.appearance)
    end
    if data.clothing and next(data.clothing) then
        Hydra.Identity.ApplyClothing(PlayerPedId(), data.clothing)
    end

    -- Spawn at position
    if data.position and data.position.x then
        local ped = PlayerPedId()
        SetEntityCoords(ped, data.position.x, data.position.y, data.position.z, false, false, false, false)
        SetEntityHeading(ped, data.position.heading or 0.0)

        -- Wait for collision to load
        RequestCollisionAtCoord(data.position.x, data.position.y, data.position.z)
        while not HasCollisionLoadedAroundEntity(ped) do
            Wait(10)
        end
    end

    -- Fade in (use hydra_camera if available)
    local camOk = pcall(function() exports['hydra_camera']:FadeIn(1000) end)
    if not camOk then DoScreenFadeIn(1000) end
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
