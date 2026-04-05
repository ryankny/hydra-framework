--[[
    Hydra Status - Client

    Receives synced status values, applies gameplay effects
    (health drain, screen effects), and detects stress triggers.
    Sends status data to HUD for display.
]]

Hydra = Hydra or {}
Hydra.Status = {}

local cfg = HydraStatusConfig

-- Local cached statuses
local statuses = {}
local isReady = false

-- =============================================
-- SYNC FROM SERVER
-- =============================================

RegisterNetEvent('hydra:status:sync')
AddEventHandler('hydra:status:sync', function(data)
    statuses = data
    isReady = true

    -- Push to HUD via store if available
    TriggerEvent('hydra:store:syncBulk', 'playerStatus', statuses)
end)

-- =============================================
-- GAMEPLAY EFFECTS
-- =============================================

RegisterNetEvent('hydra:status:effect')
AddEventHandler('hydra:status:effect', function(effectType, amount)
    if effectType == 'health_drain' then
        local ped = PlayerPedId()
        local health = GetEntityHealth(ped)
        SetEntityHealth(ped, math.max(100, health - (amount or 1)))
    end
end)

-- Screen effects for low status
CreateThread(function()
    while true do
        Wait(5000)
        if not isReady then goto continue end

        for name, value in pairs(statuses) do
            local def = cfg.statuses[name]
            if def and def.effects then
                for _, effect in ipairs(def.effects) do
                    if effect.type == 'screen_effect' then
                        if value <= effect.threshold then
                            if effect.effect == 'low_hunger' or effect.effect == 'low_thirst' then
                                -- Subtle screen wobble at low hunger/thirst
                                if not IsScreenEffectActive('FocusOut') then
                                    StartScreenEffect('FocusOut', 2000, false)
                                end
                            elseif effect.effect == 'high_stress' then
                                if not IsScreenEffectActive('DrugsMichaelAliensFight') then
                                    StartScreenEffect('DrugsMichaelAliensFight', 3000, false)
                                end
                            end
                        end
                    end
                end
            end
        end

        ::continue::
    end
end)

-- =============================================
-- STRESS TRIGGERS (client-side detection)
-- =============================================

local stressCfg = cfg.stress_triggers
local lastShot = 0

CreateThread(function()
    while true do
        Wait(1000)
        if not isReady then goto continue end

        local ped = PlayerPedId()

        -- Shooting stress
        if IsPedShooting(ped) then
            local now = GetGameTimer()
            if now - lastShot > 500 then
                lastShot = now
                TriggerServerEvent('hydra:status:clientAdd', 'stress', stressCfg.shooting)
            end
        end

        -- Speeding stress
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            local speed = GetEntitySpeed(veh) * 3.6 -- m/s to km/h
            if speed > stressCfg.speed_threshold then
                TriggerServerEvent('hydra:status:clientAdd', 'stress', stressCfg.speeding)
            end
        end

        ::continue::
    end
end)

-- =============================================
-- CLIENT API
-- =============================================

--- Get a status value (cached)
--- @param name string
--- @return number|nil
function Hydra.Status.Get(name)
    return statuses[name]
end

--- Get all statuses (cached)
--- @return table
function Hydra.Status.GetAll()
    return statuses
end

exports('GetStatus', function(name) return Hydra.Status.Get(name) end)
exports('GetAllStatuses', function() return Hydra.Status.GetAll() end)
