--[[
    Hydra AntiCheat - Client Main

    Client-side coordinator: initialises monitors, handles server warnings,
    provides local state helpers, and manages the reporting pipeline.
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
local IsEntityOnScreen = IsEntityOnScreen
local GetFinalRenderedCamCoord = GetFinalRenderedCamCoord
local GetSelectedPedWeapon = GetSelectedPedWeapon
local GetAmmoInPedWeapon = GetAmmoInPedWeapon
local IsPedOnFoot = IsPedOnFoot
local IsPedFalling = IsPedFalling
local IsEntityInAir = IsEntityInAir
local IsControlPressed = IsControlPressed
local GetEntitySpeed = GetEntitySpeed
local IsPedSprinting = IsPedSprinting

local PlayerId = PlayerId
local NetworkIsPlayerActive = NetworkIsPlayerActive

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
    -- Throttle warnings to prevent spam
    local now = GetGameTimer()
    if (now - lastWarning) < 5000 then return end
    lastWarning = now

    -- Show via hydra_notify if available, otherwise native notification
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
-- Report helpers (sent to server for validation)
-- ---------------------------------------------------------------------------

local function reportPosition()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    local pos = GetEntityCoords(ped)
    local inVehicle = IsPedInAnyVehicle(ped, false)
    local onGround = not IsEntityInAir(ped) and not IsPedFalling(ped)
    local vehSpeed = 0.0

    if inVehicle then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh and veh ~= 0 then
            vehSpeed = GetEntitySpeed(veh)
        end
    end

    TriggerServerEvent('hydra:anticheat:report:position', pos, inVehicle, onGround, vehSpeed)
end

local function reportWeapon()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    local weapon = GetSelectedPedWeapon(ped)
    -- Unarmed hash
    if weapon == `WEAPON_UNARMED` then return end

    local ammo = GetAmmoInPedWeapon(ped, weapon)
    TriggerServerEvent('hydra:anticheat:report:weapon', weapon, ammo)
end

local function reportCamera()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    local camPos = GetFinalRenderedCamCoord()
    local pedPos = GetEntityCoords(ped)
    TriggerServerEvent('hydra:anticheat:report:camera', camPos, pedPos)
end

local function reportEntities()
    local ped = PlayerPedId()
    local playerId = PlayerId()

    local peds = 0
    local vehicles = 0
    local objects = 0

    -- Count entities owned by this player
    -- Use pool iteration for performance
    local allPeds = GetGamePool('CPed')
    for i = 1, #allPeds do
        local entity = allPeds[i]
        if entity ~= ped and NetworkGetEntityOwner(entity) == playerId then
            peds = peds + 1
        end
    end

    local allVehs = GetGamePool('CVehicle')
    for i = 1, #allVehs do
        if NetworkGetEntityOwner(allVehs[i]) == playerId then
            vehicles = vehicles + 1
        end
    end

    local allObjs = GetGamePool('CObject')
    for i = 1, #allObjs do
        if NetworkGetEntityOwner(allObjs[i]) == playerId then
            objects = objects + 1
        end
    end

    TriggerServerEvent('hydra:anticheat:report:entities', {
        peds = peds,
        vehicles = vehicles,
        objects = objects,
    })
end

local function reportPedFlags()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    local flags = {
        superJump = GetPedConfigFlag(ped, 14, true),        -- Super jump flag
        invisible = not IsEntityVisible(ped),
        noRagdoll = GetPedConfigFlag(ped, 166, true),       -- No ragdoll
        infiniteStamina = GetPedConfigFlag(ped, 7, true),   -- Never tired
    }

    TriggerServerEvent('hydra:anticheat:report:ped_flags', flags)
end

-- ---------------------------------------------------------------------------
-- Spawn notification
-- ---------------------------------------------------------------------------

function Hydra.AntiCheat.NotifySpawn()
    TriggerServerEvent('hydra:anticheat:report:spawn')
end

-- Listen for common spawn events
RegisterNetEvent('hydra:players:spawned', function()
    Hydra.AntiCheat.NotifySpawn()
end)
AddEventHandler('playerSpawned', function()
    Hydra.AntiCheat.NotifySpawn()
end)

-- ---------------------------------------------------------------------------
-- Weapon fire tracking
-- ---------------------------------------------------------------------------

local lastWeaponFire = 0
local lastWeaponHash = 0

-- This runs in monitors.lua render thread to detect shots fired
function Hydra.AntiCheat.CheckWeaponFire(ped)
    if IsPedShooting(ped) then
        local weapon = GetSelectedPedWeapon(ped)
        local now = GetGameTimer()
        TriggerServerEvent('hydra:anticheat:report:fire', weapon, now)
    end
end

-- ---------------------------------------------------------------------------
-- Damage tracking
-- ---------------------------------------------------------------------------

local lastHealth = 200

function Hydra.AntiCheat.CheckDamage(ped)
    local health = GetEntityHealth(ped)
    if health < lastHealth and lastHealth > 0 then
        local amount = lastHealth - health
        TriggerServerEvent('hydra:anticheat:report:damage', amount)
    end
    lastHealth = health
end

-- ---------------------------------------------------------------------------
-- Module registration & initialisation
-- ---------------------------------------------------------------------------

CreateThread(function()
    Wait(2000)

    -- Notify server we're ready
    TriggerServerEvent('hydra:anticheat:client:ready')
    isReady = true

    -- Register with module system
    pcall(function()
        Hydra.Modules.Register('hydra_anticheat', {
            priority = 95,
            dependencies = { 'hydra_core' },
            api = {
                NotifySpawn = Hydra.AntiCheat.NotifySpawn,
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
