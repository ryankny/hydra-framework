--[[
    Hydra World - Population Density Control

    Applies ped and vehicle density multipliers continuously.
    Supports per-zone overrides and time-of-day scaling.
]]

Hydra = Hydra or {}
Hydra.World = Hydra.World or {}

local cfg = HydraWorldConfig.population
if not cfg or not cfg.enabled then return end

local zoneOverrides = cfg.zone_overrides or {}
local currentZone = nil
local activePedMult = cfg.ped_density
local activeVehMult = cfg.vehicle_density

-- Cache natives
local SetPedDensityMultiplierThisFrame = SetPedDensityMultiplierThisFrame
local SetVehicleDensityMultiplierThisFrame = SetVehicleDensityMultiplierThisFrame
local SetParkedVehicleDensityMultiplierThisFrame = SetParkedVehicleDensityMultiplierThisFrame
local SetRandomVehicleDensityMultiplierThisFrame = SetRandomVehicleDensityMultiplierThisFrame
local SetScenarioPedDensityMultiplierThisFrame = SetScenarioPedDensityMultiplierThisFrame

--- Get time-of-day multiplier
local function getTimeMult()
    local hour = GetClockHours()
    if hour >= 6 and hour < 20 then
        return cfg.day_multiplier
    else
        return cfg.night_multiplier
    end
end

--- Update density based on current zone
local function updateZoneDensity()
    local ped = GetEntityCoords(PlayerPedId())
    local zone = GetNameOfZone(ped.x, ped.y, ped.z)

    if zone ~= currentZone then
        currentZone = zone
        local override = zoneOverrides[zone]
        if override then
            activePedMult = override.ped or cfg.ped_density
            activeVehMult = override.vehicle or cfg.vehicle_density
        else
            activePedMult = cfg.ped_density
            activeVehMult = cfg.vehicle_density
        end
    end
end

-- Main density application loop (every frame for *ThisFrame natives)
CreateThread(function()
    while true do
        local timeMult = getTimeMult()
        local pedFinal = activePedMult * timeMult
        local vehFinal = activeVehMult * timeMult

        SetPedDensityMultiplierThisFrame(pedFinal)
        SetVehicleDensityMultiplierThisFrame(vehFinal)
        SetParkedVehicleDensityMultiplierThisFrame(cfg.parked_vehicle_density * timeMult)
        SetRandomVehicleDensityMultiplierThisFrame(cfg.random_vehicle_density * timeMult)
        SetScenarioPedDensityMultiplierThisFrame(cfg.scenario_ped_density * timeMult)

        Wait(0) -- Must run every frame for ThisFrame natives
    end
end)

-- Zone override check (slower cadence - zones don't change fast)
CreateThread(function()
    while true do
        Wait(cfg.tick_rate or 2000)
        updateZoneDensity()
    end
end)

-- =============================================
-- API
-- =============================================

--- Override population density at runtime
--- @param pedDensity number
--- @param vehicleDensity number
function Hydra.World.SetDensity(pedDensity, vehicleDensity)
    if pedDensity then activePedMult = math.max(0.0, math.min(3.0, pedDensity)) end
    if vehicleDensity then activeVehMult = math.max(0.0, math.min(3.0, vehicleDensity)) end
end

--- Get current active density values
--- @return number pedDensity, number vehicleDensity
function Hydra.World.GetDensity()
    return activePedMult, activeVehMult
end

--- Get current zone name
--- @return string
function Hydra.World.GetCurrentZone()
    return currentZone or 'UNKNOWN'
end
