--[[
    Hydra Inventory - Client Rob & Search

    Rob and search other players. Robbery requires hands-up
    animation on the victim; searching opens the target inventory
    as a read-only secondary panel (for police use).
]]

Hydra = Hydra or {}
Hydra.Inventory = Hydra.Inventory or {}

local cfg = HydraConfig.Inventory

-- Cache frequently used natives
local GetEntityCoords = GetEntityCoords
local PlayerPedId = PlayerPedId
local GetPlayerPed = GetPlayerPed
local GetPlayerServerId = GetPlayerServerId
local GetClosestPlayer = nil -- defined below as helper
local IsEntityPlayingAnim = IsEntityPlayingAnim
local TaskPlayAnim = TaskPlayAnim
local RequestAnimDict = RequestAnimDict
local HasAnimDictLoaded = HasAnimDictLoaded
local StopAnimTask = StopAnimTask
local NetworkGetNetworkIdFromEntity = NetworkGetNetworkIdFromEntity
local GetPlayerFromServerId = GetPlayerFromServerId
local Wait = Citizen.Wait

-- State
local isRobbing = false
local isSearching = false

-- Optional module detection
local hasTarget = false
local hasProgressbar = false

CreateThread(function()
    Wait(1500)
    hasTarget = pcall(function() return exports['hydra_target'] end)
    hasProgressbar = pcall(function() return exports['hydra_progressbar'] end)
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

--- Find the closest player ped and their server ID
--- @param range number
--- @return number|nil serverId
--- @return number|nil ped
--- @return number distance
local function findClosestPlayer(range)
    local myPed = PlayerPedId()
    local myPos = GetEntityCoords(myPed)
    local closestId = nil
    local closestPed = nil
    local closestDist = range + 1.0

    local activePlayers = GetActivePlayers()
    for _, playerId in ipairs(activePlayers) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            if targetPed ~= 0 then
                local targetPos = GetEntityCoords(targetPed)
                local dist = #(myPos - targetPos)
                if dist < closestDist then
                    closestDist = dist
                    closestId = GetPlayerServerId(playerId)
                    closestPed = targetPed
                end
            end
        end
    end

    return closestId, closestPed, closestDist
end

--- Check if a ped has their hands up (surrender animation)
--- @param ped number
--- @return boolean
local function hasHandsUp(ped)
    if not ped or ped == 0 then return false end

    -- Check common hands-up / surrender animation dictionaries
    local handsUpAnims = {
        { dict = 'missminuteman_1ig_2', clip = 'handsup_base' },
        { dict = 'mp_am_hold_up', clip = 'handsup_base' },
        { dict = 'random@mugging3', clip = 'handsup_standing_base' },
        { dict = 'mp_surrender', clip = 'idle_a' },
        { dict = 'anim@move_m@surrender', clip = 'idle' },
    }

    for _, anim in ipairs(handsUpAnims) do
        if IsEntityPlayingAnim(ped, anim.dict, anim.clip, 3) then
            return true
        end
    end

    return false
end

--- Get ped from server ID
--- @param serverId number
--- @return number|nil ped
local function getPedFromServerId(serverId)
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return nil end
    local ped = GetPlayerPed(player)
    if ped == 0 then return nil end
    return ped
end

-- =============================================
-- ROB PLAYER
-- =============================================

--- Initiate robbery of another player
--- @param targetServerId number
function Hydra.Inventory.StartRob(targetServerId)
    if isRobbing or isSearching then return end
    if not cfg.rob or not cfg.rob.enabled then return end

    local targetPed = getPedFromServerId(targetServerId)
    if not targetPed then
        TriggerEvent('hydra:notify:show', {
            type = 'error',
            message = 'Player not found.',
            duration = 3000,
        })
        return
    end

    -- Distance check
    local myPed = PlayerPedId()
    local myPos = GetEntityCoords(myPed)
    local targetPos = GetEntityCoords(targetPed)
    local dist = #(myPos - targetPos)

    if dist > cfg.rob.distance then
        TriggerEvent('hydra:notify:show', {
            type = 'error',
            message = 'You are too far away.',
            duration = 3000,
        })
        return
    end

    -- Check hands-up requirement
    if cfg.rob.requireHandsUp and not hasHandsUp(targetPed) then
        TriggerEvent('hydra:notify:show', {
            type = 'error',
            message = 'Target must have their hands up.',
            duration = 3000,
        })
        return
    end

    isRobbing = true

    -- Play robbery animation on robber
    local animDict = 'random@shop_robbery'
    local animClip = 'robbery_action_b'
    loadAnimDict(animDict)
    TaskPlayAnim(myPed, animDict, animClip, 4.0, -4.0, -1, 1, 0, false, false, false)

    -- Progress bar
    local completed = false

    if hasProgressbar then
        local ok, _ = pcall(function()
            local finished = false
            local result = false

            exports['hydra_progressbar']:ProgressStart({
                label = 'Robbing...',
                duration = cfg.rob.duration,
                canCancel = true,
                disable = {
                    move = true,
                    combat = true,
                },
            }, function(didComplete)
                result = didComplete
                finished = true
            end)

            while not finished do
                Wait(100)
            end

            completed = result
        end)

        if not ok then
            Wait(cfg.rob.duration)
            completed = true
        end
    else
        -- Fallback: simple wait
        Wait(cfg.rob.duration)
        completed = true
    end

    -- Stop animation
    StopAnimTask(myPed, animDict, animClip, 1.0)

    if completed then
        -- Verify target still in range
        local finalPos = GetEntityCoords(PlayerPedId())
        local finalTargetPos = GetEntityCoords(targetPed)
        local finalDist = #(finalPos - finalTargetPos)

        if finalDist <= cfg.rob.distance + 1.0 then
            TriggerServerEvent('hydra:inventory:rob', targetServerId)
        else
            TriggerEvent('hydra:notify:show', {
                type = 'error',
                message = 'Target moved out of range.',
                duration = 3000,
            })
        end
    end

    isRobbing = false
end

-- =============================================
-- SEARCH PLAYER (Police)
-- =============================================

--- Search another player (opens their inventory as read-only)
--- @param targetServerId number
function Hydra.Inventory.SearchPlayer(targetServerId)
    if isRobbing or isSearching then return end

    local targetPed = getPedFromServerId(targetServerId)
    if not targetPed then
        TriggerEvent('hydra:notify:show', {
            type = 'error',
            message = 'Player not found.',
            duration = 3000,
        })
        return
    end

    -- Distance check
    local myPed = PlayerPedId()
    local myPos = GetEntityCoords(myPed)
    local targetPos = GetEntityCoords(targetPed)
    local dist = #(myPos - targetPos)

    if dist > cfg.rob.distance then
        TriggerEvent('hydra:notify:show', {
            type = 'error',
            message = 'You are too far away.',
            duration = 3000,
        })
        return
    end

    isSearching = true

    -- Play pat-down animation
    local animDict = 'random@arrests'
    local animClip = 'generic_search_ped_a'
    loadAnimDict(animDict)
    TaskPlayAnim(myPed, animDict, animClip, 4.0, -4.0, -1, 1, 0, false, false, false)

    -- Progress bar for search
    local completed = false
    local searchDuration = math.floor(cfg.rob.duration * 0.8) -- slightly shorter than rob

    if hasProgressbar then
        local ok, _ = pcall(function()
            local finished = false
            local result = false

            exports['hydra_progressbar']:ProgressStart({
                label = 'Searching player...',
                duration = searchDuration,
                canCancel = true,
                disable = {
                    move = true,
                    combat = true,
                },
            }, function(didComplete)
                result = didComplete
                finished = true
            end)

            while not finished do
                Wait(100)
            end

            completed = result
        end)

        if not ok then
            Wait(searchDuration)
            completed = true
        end
    else
        Wait(searchDuration)
        completed = true
    end

    -- Stop animation
    StopAnimTask(myPed, animDict, animClip, 1.0)

    if completed then
        -- Verify still in range
        local finalPos = GetEntityCoords(PlayerPedId())
        local finalTargetPos = GetEntityCoords(targetPed)
        local finalDist = #(finalPos - finalTargetPos)

        if finalDist <= cfg.rob.distance + 1.0 then
            TriggerServerEvent('hydra:inventory:search', targetServerId)
        else
            TriggerEvent('hydra:notify:show', {
                type = 'error',
                message = 'Target moved out of range.',
                duration = 3000,
            })
        end
    end

    isSearching = false
end

-- =============================================
-- SERVER EVENT HANDLERS
-- =============================================

--- Notify victim they were robbed
RegisterNetEvent('hydra:inventory:client:robbed')
AddEventHandler('hydra:inventory:client:robbed', function(data)
    if not data then return end

    local message = 'You have been robbed!'
    if data.items and #data.items > 0 then
        local stolen = {}
        for _, entry in ipairs(data.items) do
            local label = Hydra.Inventory.GetItemLabel(entry.item) or entry.item
            stolen[#stolen + 1] = ('%dx %s'):format(entry.count or 1, label)
        end
        message = 'You were robbed of: ' .. table.concat(stolen, ', ')
    end

    TriggerEvent('hydra:notify:show', {
        type = 'error',
        message = message,
        duration = 5000,
    })
end)

--- Notify target they were searched
RegisterNetEvent('hydra:inventory:client:searched')
AddEventHandler('hydra:inventory:client:searched', function(data)
    TriggerEvent('hydra:notify:show', {
        type = 'info',
        message = data and data.message or 'You are being searched.',
        duration = 4000,
    })
end)

--- Receive search results (opens target inventory as secondary)
RegisterNetEvent('hydra:inventory:client:search:open')
AddEventHandler('hydra:inventory:client:search:open', function(data)
    if not data then return end

    -- Open inventory UI with target's items as secondary panel (read-only)
    SendNUIMessage({
        module = 'inventory',
        action = 'openSecondary',
        data = {
            label = data.label or 'Player Inventory',
            items = data.items or {},
            slots = data.slots or cfg.player.slots,
            maxWeight = data.maxWeight or cfg.player.maxWeight,
            readOnly = true,
            type = 'search',
            targetId = data.targetId,
        },
    })

    SetNuiFocus(true, true)
end)

-- =============================================
-- TARGET INTERACTION REGISTRATION
-- =============================================

CreateThread(function()
    Wait(3000) -- staggered start

    if not hasTarget then return end
    if not cfg.rob then return end

    pcall(function()
        exports['hydra_target']:AddGlobalPlayer({
            {
                label = 'Rob Player',
                icon = 'mask',
                distance = cfg.rob.distance,
                canInteract = function(entity)
                    if not cfg.rob.enabled then return false end
                    if isRobbing or isSearching then return false end
                    if cfg.rob.requireHandsUp and not hasHandsUp(entity) then return false end
                    return true
                end,
                onSelect = function(entity)
                    -- Resolve server ID from the player ped
                    local players = GetActivePlayers()
                    for _, playerId in ipairs(players) do
                        if GetPlayerPed(playerId) == entity and playerId ~= PlayerId() then
                            Hydra.Inventory.StartRob(GetPlayerServerId(playerId))
                            return
                        end
                    end
                end,
            },
            {
                label = 'Search Player',
                icon = 'magnifying-glass',
                distance = cfg.rob.distance,
                canInteract = function(entity)
                    if isRobbing or isSearching then return false end
                    -- Optionally restrict to police - server will enforce
                    return true
                end,
                onSelect = function(entity)
                    local players = GetActivePlayers()
                    for _, playerId in ipairs(players) do
                        if GetPlayerPed(playerId) == entity and playerId ~= PlayerId() then
                            Hydra.Inventory.SearchPlayer(GetPlayerServerId(playerId))
                            return
                        end
                    end
                end,
            },
        })
    end)
end)

-- =============================================
-- FALLBACK KEYPRESS INTERACTION
-- =============================================

CreateThread(function()
    Wait(3500) -- staggered start

    if not cfg.rob then return end

    while true do
        if not hasTarget and not isRobbing and not isSearching then
            local serverId, targetPed, dist = findClosestPlayer(cfg.rob.distance + 1.0)

            if serverId and dist <= cfg.rob.distance then
                Wait(0)

                -- Draw prompt based on state
                SetTextFont(4)
                SetTextScale(0.0, 0.32)
                SetTextColour(255, 255, 255, 220)
                SetTextDropshadow(1, 0, 0, 0, 200)
                SetTextOutline()
                SetTextCentre(true)
                SetTextEntry('STRING')

                if cfg.rob.enabled and (not cfg.rob.requireHandsUp or hasHandsUp(targetPed)) then
                    AddTextComponentString('[E] Rob  |  [G] Search')
                else
                    AddTextComponentString('[G] Search Player')
                end

                DrawText(0.5, 0.9)

                -- Rob (E key)
                if cfg.rob.enabled and IsControlJustPressed(0, 38) then -- E key
                    Hydra.Inventory.StartRob(serverId)
                end

                -- Search (G key)
                if IsControlJustPressed(0, 47) then -- G key
                    Hydra.Inventory.SearchPlayer(serverId)
                end
            else
                Wait(500)
            end
        else
            Wait(500)
        end
    end
end)

-- =============================================
-- EXPORTS
-- =============================================

exports('StartRob', function(targetServerId) Hydra.Inventory.StartRob(targetServerId) end)
exports('SearchPlayer', function(targetServerId) Hydra.Inventory.SearchPlayer(targetServerId) end)
exports('IsRobbing', function() return isRobbing end)
exports('IsSearching', function() return isSearching end)
