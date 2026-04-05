--[[
    Hydra World - Law Enforcement Control

    Manages wanted levels, dispatch services, and
    ambient police spawning.
]]

Hydra = Hydra or {}
Hydra.World = Hydra.World or {}

local cfg = HydraWorldConfig.law
if not cfg or not cfg.enabled then return end

-- Dispatch type enum mapping
local DISPATCH_TYPES = {
    police      = { 1, 2, 3 },    -- PoliceAutomobile, PoliceHelicopter, PoliceRoadBlock
    fire        = { 4 },           -- FireDepartment
    ambulance   = { 5 },           -- Ambulance
    swat        = { 6 },           -- SwatAutomobile
    army        = { 7 },           -- ArmyVehicle
    bias_police = { 8 },           -- BiasPoliceAutomobile
}

-- =============================================
-- WANTED LEVEL SUPPRESSION
-- =============================================

if cfg.disable_wanted_level then
    CreateThread(function()
        while true do
            local playerId = PlayerId()
            if GetPlayerWantedLevel(playerId) > 0 then
                SetPlayerWantedLevel(playerId, 0, false)
                SetPlayerWantedLevelNow(playerId, false)
            end

            -- Prevent wanted level from being set
            SetMaxWantedLevel(0)

            Wait(cfg.tick_rate or 1000)
        end
    end)
end

-- =============================================
-- DISPATCH SERVICE CONTROL
-- =============================================

if cfg.disable_dispatch then
    CreateThread(function()
        Wait(500)

        -- Disable all dispatch
        for i = 1, 15 do
            EnableDispatchService(i, false)
        end
    end)
elseif cfg.dispatch_services then
    -- Granular dispatch control
    CreateThread(function()
        Wait(500)

        for service, types in pairs(DISPATCH_TYPES) do
            local enabled = cfg.dispatch_services[service]
            if enabled == false then
                for _, typeId in ipairs(types) do
                    EnableDispatchService(typeId, false)
                end
            end
        end
    end)
end

-- =============================================
-- AMBIENT COP SUPPRESSION
-- =============================================

if cfg.disable_ambient_cops then
    CreateThread(function()
        while true do
            -- Prevent random cops from spawning
            SetCreateRandomCops(false)
            SetCreateRandomCopsNotOnScenarios(false)
            SetCreateRandomCopsOnScenarios(false)

            Wait(cfg.tick_rate or 1000)
        end
    end)
end

-- =============================================
-- COP BLIP REMOVAL
-- =============================================

if cfg.disable_cop_blips then
    CreateThread(function()
        while true do
            -- Remove all cop blips from the minimap
            local blip = GetFirstBlipInfoId(3) -- Blip sprite 3 = cop car
            while DoesBlipExist(blip) do
                RemoveBlip(blip)
                blip = GetFirstBlipInfoId(3)
            end

            -- Also remove helicopter blips
            blip = GetFirstBlipInfoId(64) -- Helicopter sprite
            while DoesBlipExist(blip) do
                local blipCoords = GetBlipCoords(blip)
                -- Only remove if it's likely a police heli (near police)
                RemoveBlip(blip)
                blip = GetFirstBlipInfoId(64)
            end

            Wait(2000)
        end
    end)
end

-- =============================================
-- API
-- =============================================

--- Clear wanted level for local player
function Hydra.World.ClearWanted()
    local playerId = PlayerId()
    SetPlayerWantedLevel(playerId, 0, false)
    SetPlayerWantedLevelNow(playerId, false)
    ClearPlayerWantedLevel(playerId)
end

--- Set wanted level (if not globally disabled)
--- @param level number 0-5
function Hydra.World.SetWanted(level)
    if cfg.disable_wanted_level then return end
    level = math.max(0, math.min(5, level))
    SetPlayerWantedLevel(PlayerId(), level, false)
    SetPlayerWantedLevelNow(PlayerId(), false)
end
