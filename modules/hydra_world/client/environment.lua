--[[
    Hydra World - Environment & Object Control

    Controls ambient world elements: garbage trucks, trains,
    sirens, music, vehicle options, weapon blacklists,
    restricted zones, and performance cleanup.
]]

Hydra = Hydra or {}
Hydra.World = Hydra.World or {}

local envCfg = HydraWorldConfig.environment
local vehCfg = HydraWorldConfig.vehicles
local blackCfg = HydraWorldConfig.blacklist
local zoneCfg = HydraWorldConfig.restricted_zones
local perfCfg = HydraWorldConfig.performance

-- =============================================
-- ENVIRONMENT TOGGLES
-- =============================================

if envCfg and envCfg.enabled then
    CreateThread(function()
        Wait(500)

        -- One-time toggles
        if not envCfg.garbage_trucks then
            SetGarbageTrucks(false)
        end
        if not envCfg.random_boats then
            SetRandomBoats(false)
        end
        if not envCfg.random_trains then
            SetRandomTrains(false)
        end
        if not envCfg.distant_sirens then
            DistantCopCarSirens(false)
        end
        if not envCfg.ambient_sirens then
            SetAmbientZoneListStatePersistent('AZ_DISTANT_SASQUATCH', false, false)
        end
        if not envCfg.gta_online_music then
            StartAudioScene('CHARACTER_CHANGE_IN_SKY_SCENE')
        end
        if not envCfg.flight_music then
            StartAudioScene('FBI_HEIST_H5_YOUROUT_CHOPPER_SCENE')
        end
    end)

    -- Continuous toggles (some reset per frame)
    CreateThread(function()
        while true do
            if not envCfg.stunt_jumps then
                SetPlayerCanDoStuntJumps(PlayerId(), false)
            end

            Wait(5000)
        end
    end)
end

-- =============================================
-- VEHICLE OPTIONS
-- =============================================

if vehCfg and vehCfg.enabled then

    -- Auto-engine prevention
    if vehCfg.disable_auto_engine then
        CreateThread(function()
            while true do
                Wait(0)
                local ped = PlayerPedId()
                local veh = GetVehiclePedIsEntering(ped)

                -- When entering a vehicle, prevent auto-start
                if veh ~= 0 and not IsVehicleSeatFree(veh, -1) == false then
                    SetVehicleEngineOn(veh, false, true, true)
                    SetVehicleNeedsToBeHotwired(veh, false)
                end
            end
        end)

        -- Engine toggle keybind (via hydra_keybinds if available)
        local function toggleEngine()
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh == 0 then return end
            if GetPedInVehicleSeat(veh, -1) ~= ped then return end
            local running = GetIsVehicleEngineRunning(veh)
            SetVehicleEngineOn(veh, not running, false, true)
        end

        local kbOk = pcall(function()
            exports['hydra_keybinds']:Register('engine', {
                key = '',
                description = 'Toggle Engine',
                category = 'vehicle',
                module = 'hydra_world',
                onPress = toggleEngine,
            })
        end)
        if not kbOk then
            RegisterCommand('engine', function() toggleEngine() end, false)
            RegisterKeyMapping('engine', 'Toggle Engine', 'keyboard', '')
        end
    end

    -- Seatbelt ejection physics
    -- Seatbelt toggle command and HUD indicator live in hydra_hud.
    -- This module adds crash ejection when seatbelt is off.
    if vehCfg.seatbelt and vehCfg.seatbelt.enabled then
        --- Read seatbelt state from HUD module (single source of truth)
        local function isSeatbeltOn()
            -- Try HUD API first, then export fallback
            if Hydra.HUD and Hydra.HUD.GetSeatbelt then
                return Hydra.HUD.GetSeatbelt()
            end
            local ok, result = pcall(exports.hydra_hud.GetSeatbelt)
            if ok then return result end
            return false
        end

        -- Ejection check
        CreateThread(function()
            local lastSpeed = 0.0
            while true do
                Wait(100)
                local ped = PlayerPedId()
                local veh = GetVehiclePedIsIn(ped, false)

                if veh ~= 0 and not isSeatbeltOn() then
                    local speed = GetEntitySpeed(veh) * 3.6 -- to km/h
                    local decel = lastSpeed - speed

                    -- Sudden deceleration = crash
                    if decel > vehCfg.seatbelt.eject_speed * 0.3 and lastSpeed > vehCfg.seatbelt.eject_speed then
                        -- Eject player through windshield
                        local forceDir = GetEntityForwardVector(veh)
                        SetEntityCoords(ped, GetEntityCoords(ped).x, GetEntityCoords(ped).y, GetEntityCoords(ped).z + 1.0, false, false, false, false)
                        SetPedToRagdoll(ped, 3000, 3000, 0, true, true, false)
                        ApplyForceToEntityCenterOfMass(ped, 1,
                            forceDir.x * vehCfg.seatbelt.eject_force,
                            forceDir.y * vehCfg.seatbelt.eject_force,
                            vehCfg.seatbelt.eject_force * 0.5,
                            false, false, true, false)

                        -- Damage
                        local health = GetEntityHealth(ped)
                        SetEntityHealth(ped, math.max(100, health - vehCfg.seatbelt.eject_damage))

                        Wait(500) -- Cooldown after ejection
                    end

                    lastSpeed = speed
                else
                    lastSpeed = 0.0
                end
            end
        end)

        -- Public API reads from HUD
        function Hydra.World.HasSeatbelt()
            return isSeatbeltOn()
        end
    end

    -- Disable NPC horns
    if vehCfg.disable_npc_horns then
        CreateThread(function()
            while true do
                Wait(2000)
                local handle, veh = FindFirstVehicle()
                local found = handle ~= -1

                while found do
                    if DoesEntityExist(veh) then
                        local driver = GetPedInVehicleSeat(veh, -1)
                        if driver ~= 0 and not IsPedAPlayer(driver) then
                            SetHornEnabled(veh, false)
                        end
                    end
                    found, veh = FindNextVehicle(handle)
                end
                EndFindVehicle(handle)
            end
        end)
    end
end

-- =============================================
-- RESTRICTED ZONES
-- =============================================

if zoneCfg and zoneCfg.enabled and #zoneCfg.zones > 0 then
    local activeZoneRules = nil
    local activeZoneName = nil

    CreateThread(function()
        while true do
            Wait(500)
            local playerPos = GetEntityCoords(PlayerPedId())
            local inZone = false

            for _, zone in ipairs(zoneCfg.zones) do
                local dist = #(playerPos - zone.coords)
                if dist <= zone.radius then
                    inZone = true
                    local rules = zone.rules or {}

                    -- Entering new zone
                    if activeZoneName ~= zone.name then
                        activeZoneName = zone.name
                        activeZoneRules = rules

                        TriggerEvent('hydra:notify:show', {
                            type = 'info', title = 'Zone',
                            message = ('Entering: %s'):format(zone.label or zone.name),
                            duration = 3000,
                        })
                    end

                    -- Apply rules
                    local ped = PlayerPedId()

                    if rules.no_weapons then
                        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
                        DisablePlayerFiring(ped, true)
                    end

                    if rules.no_pvp then
                        SetCanAttackFriendly(ped, false, false)
                        NetworkSetFriendlyFireOption(false)
                    end

                    if rules.no_wanted then
                        if GetPlayerWantedLevel(PlayerId()) > 0 then
                            SetPlayerWantedLevel(PlayerId(), 0, false)
                            SetPlayerWantedLevelNow(PlayerId(), false)
                        end
                    end

                    if rules.speed_limit and rules.speed_limit > 0 then
                        local veh = GetVehiclePedIsIn(ped, false)
                        if veh ~= 0 then
                            local speed = GetEntitySpeed(veh) * 3.6
                            if speed > rules.speed_limit then
                                local maxMs = rules.speed_limit / 3.6
                                SetVehicleMaxSpeed(veh, maxMs)
                            end
                        end
                    end

                    break
                end
            end

            -- Exited zone
            if not inZone and activeZoneName then
                -- Restore settings
                if activeZoneRules then
                    if activeZoneRules.no_pvp then
                        NetworkSetFriendlyFireOption(true)
                    end
                    if activeZoneRules.speed_limit and activeZoneRules.speed_limit > 0 then
                        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                        if veh ~= 0 then
                            SetVehicleMaxSpeed(veh, 0.0) -- Reset (0 = no limit)
                        end
                    end
                end

                TriggerEvent('hydra:notify:show', {
                    type = 'info', title = 'Zone',
                    message = ('Leaving: %s'):format(activeZoneName),
                    duration = 2000,
                })

                activeZoneName = nil
                activeZoneRules = nil
            end
        end
    end)

    --- Check if player is in a restricted zone
    --- @return string|nil zoneName
    function Hydra.World.GetRestrictedZone()
        return activeZoneName
    end
end

-- =============================================
-- WEAPON / PED BLACKLIST
-- =============================================

if blackCfg and blackCfg.enabled then
    -- Weapon removal loop
    if blackCfg.weapons and #blackCfg.weapons > 0 then
        local weaponHashes = {}
        for _, name in ipairs(blackCfg.weapons) do
            weaponHashes[#weaponHashes + 1] = GetHashKey(name)
        end

        CreateThread(function()
            while true do
                Wait(blackCfg.tick_rate or 5000)
                local ped = PlayerPedId()
                for _, hash in ipairs(weaponHashes) do
                    if HasPedGotWeapon(ped, hash, false) then
                        RemoveWeaponFromPed(ped, hash)
                    end
                end
            end
        end)
    end

    -- Blacklisted ped model removal
    if blackCfg.ped_models and #blackCfg.ped_models > 0 then
        local modelHashes = {}
        for _, model in ipairs(blackCfg.ped_models) do
            modelHashes[#modelHashes + 1] = GetHashKey(model)
        end

        CreateThread(function()
            while true do
                Wait(5000)
                local handle, ped = FindFirstPed()
                local found = handle ~= -1

                while found do
                    if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                        local model = GetEntityModel(ped)
                        for _, hash in ipairs(modelHashes) do
                            if model == hash then
                                DeleteEntity(ped)
                                break
                            end
                        end
                    end
                    found, ped = FindNextPed(handle)
                end
                EndFindPed(handle)
            end
        end)
    end
end

-- =============================================
-- PERFORMANCE CLEANUP
-- =============================================

if perfCfg then
    -- Clear area on spawn
    if perfCfg.clear_area_on_spawn then
        CreateThread(function()
            Wait(5000) -- After spawn
            local pos = GetEntityCoords(PlayerPedId())
            ClearAreaOfPeds(pos.x, pos.y, pos.z, perfCfg.clear_area_radius or 50.0, 0)
            ClearAreaOfVehicles(pos.x, pos.y, pos.z, perfCfg.clear_area_radius or 50.0, false, false, false, false, false, false)
        end)
    end

    -- Abandoned vehicle cleanup
    if perfCfg.cleanup_abandoned_vehicles then
        CreateThread(function()
            while true do
                Wait(perfCfg.cleanup_interval or 60000)
                local playerPos = GetEntityCoords(PlayerPedId())
                local cleanDist = perfCfg.cleanup_distance or 150.0

                local handle, veh = FindFirstVehicle()
                local found = handle ~= -1

                while found do
                    if DoesEntityExist(veh) and not IsEntityAMissionEntity(veh) then
                        local vehPos = GetEntityCoords(veh)
                        local dist = #(playerPos - vehPos)

                        if dist > cleanDist then
                            local driver = GetPedInVehicleSeat(veh, -1)
                            if driver == 0 then
                                SetEntityAsMissionEntity(veh, true, true)
                                DeleteEntity(veh)
                            end
                        end
                    end
                    found, veh = FindNextVehicle(handle)
                end
                EndFindVehicle(handle)
            end
        end)
    end
end
