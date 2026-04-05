--[[
    Hydra World - Scenario & Ambient Ped Control

    Manages GTA scenario groups, ambient activities,
    and NPC behavior configuration.
]]

Hydra = Hydra or {}
Hydra.World = Hydra.World or {}

local scenarioCfg = HydraWorldConfig.scenarios
local npcCfg = HydraWorldConfig.npc_behavior

-- =============================================
-- SCENARIO GROUP MANAGEMENT
-- =============================================

if scenarioCfg and scenarioCfg.enabled then
    CreateThread(function()
        Wait(1000)

        if scenarioCfg.disable_all then
            -- Disable all known scenario groups
            for group in pairs(scenarioCfg.groups) do
                SetScenarioGroupEnabled(group, false)
            end
        else
            -- Apply per-group settings
            for group, enabled in pairs(scenarioCfg.groups) do
                SetScenarioGroupEnabled(group, enabled)
            end
        end

        -- Suppress specific scenario types
        if scenarioCfg.suppress_types then
            for _, scenarioType in ipairs(scenarioCfg.suppress_types) do
                SetScenarioTypeEnabled(scenarioType, false)
            end
        end
    end)
end

-- =============================================
-- NPC BEHAVIOR
-- =============================================

if npcCfg and npcCfg.enabled then

    -- NPC phone calls (calling cops)
    if npcCfg.disable_phone_calls then
        CreateThread(function()
            while true do
                -- Block peds from using phones to report crimes
                SetPlayerCanBeHassledByGangs(PlayerId(), false)
                BlockPlayerVehicleInPhotoPiggyBack(PlayerId(), true)

                Wait(5000)
            end
        end)
    end

    -- NPC accuracy
    if npcCfg.npc_accuracy and npcCfg.npc_accuracy ~= 1.0 then
        CreateThread(function()
            while true do
                Wait(2000)
                local playerPos = GetEntityCoords(PlayerPedId())

                -- Apply to nearby combat peds
                local handle, ped = FindFirstPed()
                local found = handle ~= -1

                while found do
                    if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                        if IsEntityNearEntity(ped, PlayerPedId(), 100.0, 100.0, 100.0, false, true) then
                            if IsPedInCombat(ped, 0) then
                                SetPedAccuracy(ped, math.floor(npcCfg.npc_accuracy * 100))
                            end
                        end
                    end
                    found, ped = FindNextPed(handle)
                end
                EndFindPed(handle)
            end
        end)
    end

    -- NPC flee behavior
    if npcCfg.disable_flee then
        CreateThread(function()
            while true do
                Wait(2000)

                local handle, ped = FindFirstPed()
                local found = handle ~= -1

                while found do
                    if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                        if IsEntityNearEntity(ped, PlayerPedId(), 80.0, 80.0, 80.0, false, true) then
                            SetPedFleeAttributes(ped, 0, false)
                            SetBlockingOfNonTemporaryEvents(ped, true)
                        end
                    end
                    found, ped = FindNextPed(handle)
                end
                EndFindPed(handle)
            end
        end)
    end

    -- NPC combat suppression
    if npcCfg.disable_combat then
        CreateThread(function()
            while true do
                Wait(2000)

                local handle, ped = FindFirstPed()
                local found = handle ~= -1

                while found do
                    if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                        if IsEntityNearEntity(ped, PlayerPedId(), 80.0, 80.0, 80.0, false, true) then
                            SetPedCombatAttributes(ped, 46, true)  -- BF_CanFightArmedPedsWhenNotArmed = disabled
                            DisablePedPainAudio(ped, npcCfg.disable_critical_hits)
                        end
                    end
                    found, ped = FindNextPed(handle)
                end
                EndFindPed(handle)
            end
        end)
    end

    -- Default attitude toward player
    if npcCfg.default_attitude == 'passive' then
        CreateThread(function()
            Wait(1000)
            -- Hash for PLAYER relationship group
            local playerGroup = `PLAYER`
            local civGroup = `CIVMALE`
            local civFGroup = `CIVFEMALE`

            SetRelationshipBetweenGroups(1, civGroup, playerGroup)   -- Respect
            SetRelationshipBetweenGroups(1, civFGroup, playerGroup)
        end)
    elseif npcCfg.default_attitude == 'hostile' then
        CreateThread(function()
            Wait(1000)
            local playerGroup = `PLAYER`
            local civGroup = `CIVMALE`
            local civFGroup = `CIVFEMALE`

            SetRelationshipBetweenGroups(5, civGroup, playerGroup)   -- Hate
            SetRelationshipBetweenGroups(5, civFGroup, playerGroup)
        end)
    end
end

-- =============================================
-- API
-- =============================================

--- Enable/disable a scenario group at runtime
--- @param group string group name
--- @param enabled boolean
function Hydra.World.SetScenarioGroup(group, enabled)
    SetScenarioGroupEnabled(group, enabled)
end

--- Suppress a specific scenario type
--- @param scenarioType string
function Hydra.World.SuppressScenario(scenarioType)
    SetScenarioTypeEnabled(scenarioType, false)
end

--- Restore a specific scenario type
--- @param scenarioType string
function Hydra.World.RestoreScenario(scenarioType)
    SetScenarioTypeEnabled(scenarioType, true)
end

--- Set NPC accuracy at runtime (0.0 - 1.0)
--- @param accuracy number
function Hydra.World.SetNPCAccuracy(accuracy)
    if npcCfg then
        npcCfg.npc_accuracy = math.max(0.0, math.min(1.0, accuracy))
    end
end
