--[[
    Hydra AntiCheat - Client Main

    Client-side coordinator: initialises monitors, handles server communications,
    heartbeat challenge-response, screenshot capture, and the reporting pipeline.
    All enforcement decisions are made server-side — the client only reports.
]]

Hydra = Hydra or {}
Hydra.AntiCheat = Hydra.AntiCheat or {}

local cfg = HydraConfig.AntiCheat

-- ---------------------------------------------------------------------------
-- Localise for performance
-- ---------------------------------------------------------------------------
local GetGameTimer = GetGameTimer
local PlayerPedId = PlayerPedId
local GetEntityCoords = GetEntityCoords
local GetEntityHealth = GetEntityHealth
local GetPedArmour = GetPedArmour
local IsPedInAnyVehicle = IsPedInAnyVehicle
local GetFinalRenderedCamCoord = GetFinalRenderedCamCoord
local GetSelectedPedWeapon = GetSelectedPedWeapon
local GetAmmoInPedWeapon = GetAmmoInPedWeapon
local IsPedFalling = IsPedFalling
local IsEntityInAir = IsEntityInAir
local GetEntitySpeed = GetEntitySpeed
local IsPedShooting = IsPedShooting
local PlayerId = PlayerId
local NetworkIsPlayerActive = NetworkIsPlayerActive
local TriggerServerEvent = TriggerServerEvent
local Wait = Wait

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local isReady = false
local lastWarning = 0

-- ---------------------------------------------------------------------------
-- Server warning handler
-- ---------------------------------------------------------------------------

RegisterNetEvent('hydra:anticheat:warn', function(reason)
    if not reason then return end
    local now = GetGameTimer()
    if (now - lastWarning) < 5000 then return end
    lastWarning = now

    local ok = pcall(function()
        exports['hydra_notify']:Show({
            title = 'Anti-Cheat Warning',
            message = reason,
            type = 'error',
            duration = 8000,
        })
    end)
    if not ok then
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName('~r~Anti-Cheat:~s~ ' .. reason)
        EndTextCommandThefeedPostTicker(true, false)
    end
end)

-- ---------------------------------------------------------------------------
-- Heartbeat challenge-response system
-- ---------------------------------------------------------------------------

if cfg.heartbeat and cfg.heartbeat.enabled then
    local pendingToken = nil

    RegisterNetEvent('hydra:anticheat:heartbeat:challenge', function(token)
        if not token then return end
        pendingToken = token
        -- Respond immediately with the token
        TriggerServerEvent('hydra:anticheat:heartbeat:response', token)
    end)

    -- Backup: if challenge is missed, periodic self-check
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(5000)

        while true do
            Wait(cfg.heartbeat.interval or 30000)
            -- Send a keep-alive even without challenge (proves client AC is running)
            TriggerServerEvent('hydra:anticheat:heartbeat:alive')
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Screenshot system
-- ---------------------------------------------------------------------------

RegisterNetEvent('hydra:anticheat:screenshot', function(reason)
    -- Try screenshot-basic first, then other common screenshot resources
    local captured = false

    pcall(function()
        exports['screenshot-basic']:requestScreenshot(function(data)
            TriggerServerEvent('hydra:anticheat:screenshot:result', data, reason)
            captured = true
        end)
    end)

    if not captured then
        -- Fallback: try discord-screenshot or similar
        pcall(function()
            exports['discord-screenshot']:requestScreenshot(function(data)
                TriggerServerEvent('hydra:anticheat:screenshot:result', data, reason)
            end)
        end)
    end
end)

-- ---------------------------------------------------------------------------
-- Spawn notification
-- ---------------------------------------------------------------------------

function Hydra.AntiCheat.NotifySpawn()
    TriggerServerEvent('hydra:anticheat:report:spawn')
end

RegisterNetEvent('hydra:players:spawned', function()
    Hydra.AntiCheat.NotifySpawn()
end)
AddEventHandler('playerSpawned', function()
    Hydra.AntiCheat.NotifySpawn()
end)

-- ---------------------------------------------------------------------------
-- Teleport whitelist notification (when legitimate teleport occurs)
-- ---------------------------------------------------------------------------

function Hydra.AntiCheat.NotifyTeleport()
    TriggerServerEvent('hydra:anticheat:report:teleport_whitelist')
end

-- Listen for framework teleport events
if cfg.teleport_whitelist then
    for _, eventName in ipairs(cfg.teleport_whitelist.events or {}) do
        RegisterNetEvent(eventName, function()
            Hydra.AntiCheat.NotifyTeleport()
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Chat reporting (for chat protection)
-- ---------------------------------------------------------------------------

function Hydra.AntiCheat.ReportChat(message, isCommand)
    if not cfg.chat_protection or not cfg.chat_protection.enabled then return end
    TriggerServerEvent('hydra:anticheat:report:chat', message, isCommand or false)
end

-- Hook into chat if available
AddEventHandler('chatMessage', function(src, name, message)
    Hydra.AntiCheat.ReportChat(message, false)
end)

-- ---------------------------------------------------------------------------
-- Entity ownership change tracking
-- ---------------------------------------------------------------------------

if cfg.entities and cfg.entities.ownership_check then
    local trackedOwnership = {}

    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(12000)

        local playerId = PlayerId()

        while true do
            Wait(5000)

            -- Check for entities we've taken control of
            local currentOwned = {}
            local takeoverCount = 0

            for _, pool in ipairs({'CPed', 'CVehicle', 'CObject'}) do
                local entities = GetGamePool(pool)
                for i = 1, #entities do
                    local ent = entities[i]
                    if NetworkGetEntityOwner(ent) == playerId then
                        local netId = NetworkGetNetworkIdFromEntity(ent)
                        if netId and netId > 0 then
                            currentOwned[netId] = true
                            if not trackedOwnership[netId] then
                                takeoverCount = takeoverCount + 1
                            end
                        end
                    end
                end
            end

            if takeoverCount > 10 then
                TriggerServerEvent('hydra:anticheat:report:entity_takeover', takeoverCount)
            end

            trackedOwnership = currentOwned
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Module registration & initialisation
-- ---------------------------------------------------------------------------

CreateThread(function()
    Wait(2000)

    TriggerServerEvent('hydra:anticheat:client:ready')
    isReady = true

    pcall(function()
        Hydra.Modules.Register('hydra_anticheat', {
            priority = 95,
            dependencies = { 'hydra_core' },
            api = {
                NotifySpawn = Hydra.AntiCheat.NotifySpawn,
                NotifyTeleport = Hydra.AntiCheat.NotifyTeleport,
                ReportChat = Hydra.AntiCheat.ReportChat,
            },
            hooks = {
                onLoad = function()
                    if cfg.debug then
                        print('[AC] Client anti-cheat monitors active')
                    end
                end,
            },
        })
    end)
end)

-- ---------------------------------------------------------------------------
-- Exports
-- ---------------------------------------------------------------------------

exports('NotifySpawn', Hydra.AntiCheat.NotifySpawn)
exports('NotifyTeleport', Hydra.AntiCheat.NotifyTeleport)
exports('ReportChat', Hydra.AntiCheat.ReportChat)
