--[[
    Hydra Players - Client Spawn System

    Handles player spawning after loading.
    Supports last-position spawning and default spawn points.
]]

Hydra = Hydra or {}

local hasSpawned = false

-- If identity module handles spawning, skip the default spawn
local identityHandledSpawn = false

RegisterNetEvent('hydra:identity:characterLoaded')
AddEventHandler('hydra:identity:characterLoaded', function()
    identityHandledSpawn = true
    hasSpawned = true
    TriggerEvent('hydra:players:spawned')
    TriggerServerEvent('hydra:players:spawned')
end)

--- Spawn the player at the appropriate location (only used when identity module is NOT active)
--- @param data table player data with position
local function spawnPlayer(data)
    if hasSpawned then return end
    hasSpawned = true

    local pos = data.position or { x = -269.4, y = -955.3, z = 31.2, heading = 205.8 }

    -- Wait for model to be ready
    local model = `mp_m_freemode_01`
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)

    local ped = PlayerPedId()

    -- Freeze player during spawn
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    SetEntityHeading(ped, pos.heading or 0.0)

    -- Wait for collision to load
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    while not HasCollisionLoadedAroundEntity(ped) do
        Wait(0)
    end

    -- Short delay for world to settle
    Wait(500)

    -- Unfreeze
    FreezeEntityPosition(ped, false)

    -- Clear screen effects
    DoScreenFadeIn(500)

    -- Set default appearance
    SetPedDefaultComponentVariation(ped)

    Hydra.Utils.Log('info', 'Player spawned at %.1f, %.1f, %.1f', pos.x, pos.y, pos.z)
    TriggerEvent('hydra:players:spawned', pos)
    TriggerServerEvent('hydra:players:spawned')
end

--- Listen for player data load to trigger spawn
AddEventHandler('hydra:players:ready', function(data)
    -- Identity module already handled spawn — skip
    if identityHandledSpawn then return end

    -- Screen fade out for clean transition
    DoScreenFadeOut(0)

    -- Small delay to let things settle
    Wait(100)

    spawnPlayer(data)
end)

--- Handle death / respawn
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local isDead = args[4] == 1

        if victim == PlayerPedId() and isDead then
            TriggerEvent('hydra:players:died')
            TriggerServerEvent('hydra:players:died')
        end
    end
end)
