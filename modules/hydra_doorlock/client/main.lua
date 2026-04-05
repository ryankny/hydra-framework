--[[
    Hydra Doorlock - Client

    Door state management, native door control,
    3D indicators, interaction, and keypad input.
]]

Hydra = Hydra or {}
Hydra.Doorlock = {}

local cfg = HydraDoorlockConfig

-- Local door registry: [id] = doorData (with .locked state)
local doors = {}
local lastAction = 0

-- =============================================
-- SYNC
-- =============================================

RegisterNetEvent('hydra:doorlock:fullSync')
AddEventHandler('hydra:doorlock:fullSync', function(data)
    for id, door in pairs(data) do
        doors[id] = {
            id = id,
            label = door.label,
            coords = vector3(door.coords.x, door.coords.y, door.coords.z),
            model = door.model or 0,
            heading = door.heading or 0.0,
            locked = door.locked,
            lock_type = door.lock_type,
            auto_lock = door.auto_lock or 0,
            double = door.double or 0,
        }
    end
    applyAllDoorStates()
end)

RegisterNetEvent('hydra:doorlock:stateUpdate')
AddEventHandler('hydra:doorlock:stateUpdate', function(id, locked)
    if doors[id] then
        doors[id].locked = locked
        applyDoorState(id)

        -- Play sound (use hydra_audio if available)
        local door = doors[id]
        local soundCfg = locked and cfg.sounds.lock or cfg.sounds.unlock
        local audioOk = pcall(function()
            exports['hydra_audio']:PlayAtCoord(soundCfg.name, soundCfg.set, door.coords, 5.0, 'sfx')
        end)
        if not audioOk then
            PlaySoundFromCoord(-1, soundCfg.name, door.coords.x, door.coords.y, door.coords.z, soundCfg.set, false, 5.0, false)
        end
    end
end)

RegisterNetEvent('hydra:doorlock:doorAdded')
AddEventHandler('hydra:doorlock:doorAdded', function(door)
    doors[door.id] = {
        id = door.id,
        label = door.label,
        coords = vector3(door.coords.x, door.coords.y, door.coords.z),
        model = door.model or 0,
        heading = door.heading or 0.0,
        locked = door.locked,
        lock_type = door.lock_type,
        auto_lock = door.auto_lock or 0,
        double = door.double or 0,
    }
    applyDoorState(door.id)
end)

RegisterNetEvent('hydra:doorlock:doorRemoved')
AddEventHandler('hydra:doorlock:doorRemoved', function(id)
    if doors[id] then
        -- Unlock the door before removing
        doors[id].locked = false
        applyDoorState(id)
        doors[id] = nil
    end
end)

RegisterNetEvent('hydra:doorlock:denied')
AddEventHandler('hydra:doorlock:denied', function(id, reason)
    local door = doors[id]
    if door then
        local soundCfg = cfg.sounds.denied
        local audioOk = pcall(function()
            exports['hydra_audio']:PlayAtCoord(soundCfg.name, soundCfg.set, door.coords, 5.0, 'sfx')
        end)
        if not audioOk then
            PlaySoundFromCoord(-1, soundCfg.name, door.coords.x, door.coords.y, door.coords.z, soundCfg.set, false, 5.0, false)
        end
    end

    TriggerEvent('hydra:notify:show', {
        type = 'error', title = 'Locked',
        message = reason or 'Access denied.',
        duration = 2000,
    })
end)

-- Request sync on start
CreateThread(function()
    Wait(1000)
    TriggerServerEvent('hydra:doorlock:requestSync')
end)

-- =============================================
-- NATIVE DOOR CONTROL
-- =============================================

--- Apply locked/unlocked state to a native door
--- @param id string
function applyDoorState(id)
    local door = doors[id]
    if not door or door.model == 0 then return end

    local hash = door.model
    local coords = door.coords

    if door.locked then
        -- Lock: freeze the door at its heading
        SetDoorClosedFrame(hash, coords.x, coords.y, coords.z, false, 0.0, 0.0, 0.0)

        -- Use native door system
        local doorHash = DoorSystemGetDoorPendingState(hash)
        DoorSystemSetDoorState(hash, 1, false, false) -- 1 = locked

        -- Try AddDoorToSystem for more reliable control
        local doorId = hash
        if not DoorSystemGetDoorState(hash) then
            AddDoorToSystem(hash, hash, coords.x, coords.y, coords.z, false, false, false)
        end
        DoorSystemSetDoorState(hash, 1, false, false)
    else
        -- Unlock: allow door to open
        DoorSystemSetDoorState(hash, 0, false, false) -- 0 = unlocked
    end

    -- Double door
    if door.double and door.double ~= 0 then
        local dHash = door.double
        if door.locked then
            if not DoorSystemGetDoorState(dHash) then
                AddDoorToSystem(dHash, dHash, coords.x, coords.y, coords.z, false, false, false)
            end
            DoorSystemSetDoorState(dHash, 1, false, false)
        else
            DoorSystemSetDoorState(dHash, 0, false, false)
        end
    end
end

function applyAllDoorStates()
    for id in pairs(doors) do
        applyDoorState(id)
    end
end

-- Re-apply door states periodically (doors can reset on stream-in)
-- Uses adaptive tick rate: faster when near doors, slower when far
CreateThread(function()
    while true do
        local playerPos = GetEntityCoords(PlayerPedId())
        local nearestDist = 999.0

        for id, door in pairs(doors) do
            if door.model ~= 0 and door.locked then
                local dist = #(playerPos - door.coords)
                if dist < nearestDist then nearestDist = dist end
                if dist < 50.0 then
                    applyDoorState(id)
                end
            end
        end

        -- Adaptive sleep: 1s if near doors, 5s if far
        Wait(nearestDist < 60.0 and 1000 or 5000)
    end
end)

-- =============================================
-- INTERACTION
-- =============================================

--- Find the nearest door within interaction range
--- @return string|nil doorId, table|nil doorData, number distance
function Hydra.Doorlock.GetNearestDoor()
    local playerPos = GetEntityCoords(PlayerPedId())
    local nearest = nil
    local nearestDoor = nil
    local nearestDist = cfg.interact_distance + 1

    for id, door in pairs(doors) do
        local dist = #(playerPos - door.coords)
        if dist < nearestDist then
            nearestDist = dist
            nearest = id
            nearestDoor = door
        end
    end

    return nearest, nearestDoor, nearestDist
end

-- Interaction via target system (if available)
CreateThread(function()
    Wait(2000)

    if Hydra.Target and Hydra.Target.AddCoord then
        -- Register all doors with the target system
        for id, door in pairs(doors) do
            registerTargetForDoor(id, door)
        end
    end
end)

function registerTargetForDoor(id, door)
    if not Hydra.Target or not Hydra.Target.AddCoord then return end

    Hydra.Target.AddCoord(door.coords, cfg.interact_distance, {
        {
            label = function()
                return doors[id] and doors[id].locked and ('Unlock: ' .. door.label) or ('Lock: ' .. door.label)
            end,
            icon = nil,
            onSelect = function()
                tryInteract(id)
            end,
        },
    })
end

--- Try to interact with a door
--- @param id string
function tryInteract(id)
    local door = doors[id]
    if not door then return end

    -- Cooldown
    local now = GetGameTimer()
    if now - lastAction < cfg.action_cooldown then return end
    lastAction = now

    -- Keypad lock type: open input dialog
    if door.lock_type == 'keypad' then
        openKeypadInput(id, door)
        return
    end

    -- All other types: let server decide
    TriggerServerEvent('hydra:doorlock:toggle', id)
end

--- Open keypad input for code entry
function openKeypadInput(id, door)
    if Hydra.Input and Hydra.Input.Show then
        Hydra.Input.Show({
            title = door.label or 'Keypad',
            description = 'Enter the access code',
            fields = {
                { type = 'password', name = 'code', label = 'Code', placeholder = '****', required = true },
            },
            submitText = 'Submit',
        }, function(result)
            if result and result.code then
                TriggerServerEvent('hydra:doorlock:keypadSubmit', id, result.code)
            end
        end)
    else
        -- Fallback: no input module
        TriggerServerEvent('hydra:doorlock:toggle', id)
    end
end

-- =============================================
-- 3D INDICATORS
-- =============================================

if cfg.draw_indicators then
    CreateThread(function()
        while true do
            local playerPos = GetEntityCoords(PlayerPedId())
            local sleep = 500

            for id, door in pairs(doors) do
                local dist = #(playerPos - door.coords)

                if dist < cfg.indicator_distance then
                    sleep = 0
                    local locked = door.locked

                    -- Draw 3D text
                    local r, g, b = 0, 184, 148 -- green (unlocked)
                    local icon = '~g~OPEN'
                    if locked then
                        r, g, b = 255, 118, 117 -- red (locked)
                        icon = '~r~LOCKED'
                    end

                    local z = door.coords.z + 1.0
                    DrawMarker(2, door.coords.x, door.coords.y, z,
                        0, 0, 0, 0, 0, 0,
                        0.02, 0.02, 0.02,
                        r, g, b, 180,
                        false, true, 2, nil, nil, false)

                    if dist < cfg.interact_distance then
                        -- Show interaction hint
                        SetTextFont(4)
                        SetTextScale(0.0, 0.3)
                        SetTextColour(255, 255, 255, 200)
                        SetTextDropshadow(0, 0, 0, 0, 200)
                        SetTextOutline()
                        SetTextCentre(true)
                        SetTextEntry('STRING')
                        AddTextComponentString(icon .. '~w~ - ' .. (door.label or id))
                        SetDrawOrigin(door.coords.x, door.coords.y, z + 0.15, 0)
                        DrawText(0.0, 0.0)
                        ClearDrawOrigin()
                    end
                end
            end

            Wait(sleep)
        end
    end)
end

-- =============================================
-- FALLBACK KEYBIND (if no target system)
-- =============================================

-- Doorlock interact keybind (via hydra_keybinds if available)
CreateThread(function()
    Wait(500)
    local function doorInteract()
        local id, door, dist = Hydra.Doorlock.GetNearestDoor()
        if id and dist <= cfg.interact_distance then
            tryInteract(id)
        end
    end

    local ok = pcall(function()
        exports['hydra_keybinds']:Register('doorlock_interact', {
            key = 'E',
            description = 'Interact with Door',
            category = 'interaction',
            module = 'hydra_doorlock',
            onPress = doorInteract,
        })
    end)
    if not ok then
        RegisterCommand('hydra_doorlock_interact', function() doorInteract() end, false)
        RegisterKeyMapping('hydra_doorlock_interact', 'Interact with Door', 'keyboard', 'E')
    end
end)

-- =============================================
-- EXPORTS
-- =============================================

exports('GetNearestDoor', function() return Hydra.Doorlock.GetNearestDoor() end)
exports('IsLocked', function(id) return doors[id] and doors[id].locked or false end)
exports('GetDoors', function() return doors end)
