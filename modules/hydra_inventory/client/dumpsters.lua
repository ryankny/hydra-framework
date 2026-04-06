--[[
    Hydra Inventory - Client Dumpsters

    Dumpster searching system. Detects nearby dumpster props,
    shows interaction prompts, plays search animation with progress
    bar, and triggers server-side loot generation.
]]

Hydra = Hydra or {}
Hydra.Inventory = Hydra.Inventory or {}

local cfg = HydraConfig.Inventory

-- Cache frequently used natives
local GetEntityCoords = GetEntityCoords
local PlayerPedId = PlayerPedId
local DoesEntityExist = DoesEntityExist
local GetEntityModel = GetEntityModel
local GetClosestObjectOfType = GetClosestObjectOfType
local IsControlJustPressed = IsControlJustPressed
local TaskPlayAnim = TaskPlayAnim
local RequestAnimDict = RequestAnimDict
local HasAnimDictLoaded = HasAnimDictLoaded
local StopAnimTask = StopAnimTask
local NetworkGetNetworkIdFromEntity = NetworkGetNetworkIdFromEntity
local GetGameTimer = GetGameTimer
local Wait = Citizen.Wait

-- State: [entityHandle] = timestamp (cooldown tracking)
local searchedDumpsters = {}
local isSearching = false

-- Optional module detection
local hasTarget = false
local hasProgressbar = false

CreateThread(function()
    Wait(1500)
    hasTarget = pcall(function() return exports['hydra_target'] end)
    hasProgressbar = pcall(function() return exports['hydra_progressbar'] end)
end)

-- Pre-hash dumpster models for fast comparison
local dumpsterHashes = {}

CreateThread(function()
    Wait(500)
    if cfg.dumpsters and cfg.dumpsters.models then
        for _, model in ipairs(cfg.dumpsters.models) do
            dumpsterHashes[GetHashKey(model)] = true
        end
    end
end)

-- =============================================
-- UTILITY
-- =============================================

--- Load an animation dictionary
--- @param dict string
--- @return boolean loaded
local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 3000 do
        Wait(10)
        t = t + 10
    end
    return HasAnimDictLoaded(dict)
end

--- Check if a dumpster is on cooldown
--- @param entity number
--- @return boolean
local function isOnCooldown(entity)
    local searched = searchedDumpsters[entity]
    if not searched then return false end
    local elapsed = (GetGameTimer() - searched) / 1000
    return elapsed < cfg.dumpsters.cooldown
end

--- Get remaining cooldown in seconds
--- @param entity number
--- @return number
local function getCooldownRemaining(entity)
    local searched = searchedDumpsters[entity]
    if not searched then return 0 end
    local elapsed = (GetGameTimer() - searched) / 1000
    local remaining = cfg.dumpsters.cooldown - elapsed
    return remaining > 0 and math.ceil(remaining) or 0
end

--- Find the closest dumpster entity within range
--- @param playerPos vector3
--- @param range number
--- @return number|nil entity
--- @return number distance
local function findNearbyDumpster(playerPos, range)
    local closestEntity = nil
    local closestDist = range + 1.0

    for hash, _ in pairs(dumpsterHashes) do
        local obj = GetClosestObjectOfType(playerPos.x, playerPos.y, playerPos.z, range, hash, false, false, false)
        if obj ~= 0 and DoesEntityExist(obj) then
            local objPos = GetEntityCoords(obj)
            local dist = #(playerPos - objPos)
            if dist < closestDist then
                closestDist = dist
                closestEntity = obj
            end
        end
    end

    return closestEntity, closestDist
end

-- =============================================
-- SEARCH ACTION
-- =============================================

--- Perform a dumpster search
--- @param entity number dumpster entity
local function searchDumpster(entity)
    if isSearching then return end
    if not entity or not DoesEntityExist(entity) then return end

    if isOnCooldown(entity) then
        local remaining = getCooldownRemaining(entity)
        TriggerEvent('hydra:notify:show', {
            type = 'error',
            message = ('Already searched. Try again in %ds.'):format(remaining),
            duration = 3000,
        })
        return
    end

    isSearching = true
    local ped = PlayerPedId()
    local animDict = 'anim@gangops@intcarjack@intro'
    local animClip = 'intro_driver'

    -- Play search animation
    loadAnimDict(animDict)
    TaskPlayAnim(ped, animDict, animClip, 4.0, -4.0, -1, 1, 0, false, false, false)

    -- Progress bar (with fallback)
    local completed = false

    if hasProgressbar then
        local ok, _ = pcall(function()
            local finished = false
            local result = false

            exports['hydra_progressbar']:ProgressStart({
                label = 'Searching dumpster...',
                duration = cfg.dumpsters.searchTime,
                canCancel = true,
                disable = {
                    move = true,
                    combat = true,
                },
            }, function(didComplete)
                result = didComplete
                finished = true
            end)

            -- Wait for progress to finish
            while not finished do
                Wait(100)
            end

            completed = result
        end)

        if not ok then
            -- Fallback if pcall fails
            Wait(cfg.dumpsters.searchTime)
            completed = true
        end
    else
        -- Fallback: simple wait
        Wait(cfg.dumpsters.searchTime)
        completed = true
    end

    -- Stop animation
    StopAnimTask(ped, animDict, animClip, 1.0)

    if completed then
        -- Mark as searched with current timestamp
        searchedDumpsters[entity] = GetGameTimer()

        -- Request server to calculate loot
        local netId = 0
        if NetworkGetEntityIsNetworked(entity) then
            netId = NetworkGetNetworkIdFromEntity(entity)
        end
        TriggerServerEvent('hydra:inventory:dumpster:search', netId)
    end

    isSearching = false
end

-- =============================================
-- SERVER RESULT EVENT
-- =============================================

--- Receive notification of what was found
RegisterNetEvent('hydra:inventory:client:dumpster:result')
AddEventHandler('hydra:inventory:client:dumpster:result', function(data)
    if not data then return end

    if data.found and data.items and #data.items > 0 then
        local itemNames = {}
        for _, entry in ipairs(data.items) do
            local label = Hydra.Inventory.GetItemLabel(entry.item) or entry.item
            itemNames[#itemNames + 1] = ('%dx %s'):format(entry.count or 1, label)
        end

        TriggerEvent('hydra:notify:show', {
            type = 'success',
            message = 'Found: ' .. table.concat(itemNames, ', '),
            duration = 5000,
        })
    else
        TriggerEvent('hydra:notify:show', {
            type = 'info',
            message = 'Nothing useful in here.',
            duration = 3000,
        })
    end
end)

-- =============================================
-- TARGET INTERACTION REGISTRATION
-- =============================================

CreateThread(function()
    Wait(2500) -- staggered start

    if not hasTarget then return end
    if not cfg.dumpsters or not cfg.dumpsters.enabled then return end

    local models = {}
    for _, model in ipairs(cfg.dumpsters.models) do
        models[#models + 1] = model
    end

    pcall(function()
        exports['hydra_target']:AddModel(models, {
            {
                label = 'Search Dumpster',
                icon = 'magnifying-glass',
                distance = cfg.dumpsters.searchDistance,
                canInteract = function(entity)
                    if isSearching then return false end
                    if isOnCooldown(entity) then return false end
                    return true
                end,
                onSelect = function(entity)
                    searchDumpster(entity)
                end,
            },
        })
    end)
end)

-- =============================================
-- FALLBACK KEYPRESS DETECTION THREAD
-- =============================================

CreateThread(function()
    Wait(3500) -- staggered start

    if not cfg.dumpsters or not cfg.dumpsters.enabled then return end

    while true do
        if not hasTarget and not isSearching then
            local ped = PlayerPedId()
            local playerPos = GetEntityCoords(ped)

            local dumpster, dist = findNearbyDumpster(playerPos, 20.0)

            if dumpster and dist <= cfg.dumpsters.searchDistance then
                -- Draw prompt
                Wait(0)

                local dumpsterPos = GetEntityCoords(dumpster)

                SetTextFont(4)
                SetTextScale(0.0, 0.32)
                SetTextColour(255, 255, 255, 220)
                SetTextDropshadow(1, 0, 0, 0, 200)
                SetTextOutline()
                SetTextCentre(true)
                SetTextEntry('STRING')

                if isOnCooldown(dumpster) then
                    local remaining = getCooldownRemaining(dumpster)
                    AddTextComponentString(('Searched (%ds)'):format(remaining))
                else
                    AddTextComponentString('[E] Search Dumpster')
                end

                SetDrawOrigin(dumpsterPos.x, dumpsterPos.y, dumpsterPos.z + 1.0, 0)
                DrawText(0.0, 0.0)
                ClearDrawOrigin()

                if not isOnCooldown(dumpster) and IsControlJustPressed(0, 38) then -- E key
                    searchDumpster(dumpster)
                end
            elseif dumpster and dist <= 20.0 then
                -- Nearby but not close enough, slow poll
                Wait(500)
            else
                -- No dumpster nearby, very slow poll
                Wait(500)
            end
        else
            Wait(500)
        end
    end
end)

-- =============================================
-- CLEANUP STALE COOLDOWNS
-- =============================================

CreateThread(function()
    Wait(60000) -- delayed start

    while true do
        Wait(30000)

        local now = GetGameTimer()
        local cooldownMs = cfg.dumpsters.cooldown * 1000

        for entity, timestamp in pairs(searchedDumpsters) do
            if (now - timestamp) > cooldownMs then
                searchedDumpsters[entity] = nil
            end
        end
    end
end)
