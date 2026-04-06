--[[
    Hydra Inventory - Client Main

    Core client-side inventory logic: opening/closing the UI, NUI
    callbacks for item operations, consumable animations, screen
    effects, hotbar keybinds, and real-time slot updates.
]]

Hydra = Hydra or {}
Hydra.Inventory = Hydra.Inventory or {}

local cfg = HydraConfig.Inventory

-- Localize frequently used natives
local PlayerPedId = PlayerPedId
local PlayerId = PlayerId
local GetPlayerServerId = GetPlayerServerId
local GetEntityCoords = GetEntityCoords
local GetActivePlayers = GetActivePlayers
local GetPlayerPed = GetPlayerPed
local IsEntityDead = IsEntityDead
local DoesEntityExist = DoesEntityExist
local DeleteEntity = DeleteEntity
local CreateObject = CreateObject
local AttachEntityToEntity = AttachEntityToEntity
local GetPedBoneIndex = GetPedBoneIndex
local RequestModel = RequestModel
local HasModelLoaded = HasModelLoaded
local SetModelAsNoLongerNeeded = SetModelAsNoLongerNeeded
local RequestAnimDict = RequestAnimDict
local HasAnimDictLoaded = HasAnimDictLoaded
local TaskPlayAnim = TaskPlayAnim
local StopAnimTask = StopAnimTask
local StartScreenEffect = StartScreenEffect
local StopScreenEffect = StopScreenEffect
local SetTimecycleModifier = SetTimecycleModifier
local ClearTimecycleModifier = ClearTimecycleModifier
local GetEntityHealth = GetEntityHealth
local GetVehiclePedIsIn = GetVehiclePedIsIn
local GetClosestVehicle = GetClosestVehicle
local IsControlJustPressed = IsControlJustPressed
local Wait = Citizen.Wait

-- =========================================================================
-- STATE
-- =========================================================================

local isOpen = false
local currentInventory = nil
local secondaryInventory = nil
local isConsuming = false

-- Active consume cleanup references
local consumePropEntity = nil
local consumeAnimDict = nil
local consumeAnimClip = nil

-- Optional module detection flags
local hasKeybinds = false
local hasAnims = false
local hasObject = false
local hasProgressbar = false

CreateThread(function()
    Wait(1500)
    hasKeybinds = pcall(function() return exports['hydra_keybinds'] end)
    hasAnims = pcall(function() return exports['hydra_anims'] end)
    hasObject = pcall(function() return exports['hydra_object'] end)
    hasProgressbar = pcall(function() return exports['hydra_progressbar'] end)
end)

-- =========================================================================
-- HELPERS
-- =========================================================================

--- Find the nearest player within a given distance
--- @param distance number Maximum search radius
--- @return number|nil serverId, number|nil ped
function Hydra.Inventory.GetNearestPlayer(distance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closest = nil
    local closestDist = distance or 3.0
    local closestPed = nil

    local players = GetActivePlayers()
    for i = 1, #players do
        local target = players[i]
        if target ~= PlayerId() then
            local targetPed = GetPlayerPed(target)
            if DoesEntityExist(targetPed) then
                local targetCoords = GetEntityCoords(targetPed)
                local dist = #(coords - targetCoords)
                if dist < closestDist then
                    closestDist = dist
                    closest = GetPlayerServerId(target)
                    closestPed = targetPed
                end
            end
        end
    end

    return closest, closestPed
end

--- Find the nearest vehicle within a given distance
--- @param distance number Maximum search radius
--- @return number|nil vehicleEntity
function Hydra.Inventory.GetNearestVehicle(distance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local maxDist = distance or cfg.vehicle.accessDistance

    -- Check if player is already in a vehicle
    local currentVehicle = GetVehiclePedIsIn(ped, false)
    if currentVehicle ~= 0 then
        return currentVehicle
    end

    -- Search nearby vehicles
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, maxDist, 0, 70)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        return vehicle
    end

    return nil
end

--- Load an animation dictionary with timeout
--- @param dict string
--- @return boolean loaded
local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 3000 do
        Wait(10)
        t = t + 10
    end
    return HasAnimDictLoaded(dict)
end

--- Load a model with timeout
--- @param model string|number
--- @return boolean loaded, number hash
local function LoadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if HasModelLoaded(hash) then return true, hash end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 3000 do
        Wait(10)
        t = t + 10
    end
    return HasModelLoaded(hash), hash
end

--- Debug/info logging helpers
local function DebugLog(msg, ...)
    if Hydra.Utils and Hydra.Utils.Log then
        Hydra.Utils.Log('debug', '[Inventory] ' .. msg, ...)
    end
end

local function WarnLog(msg, ...)
    if Hydra.Utils and Hydra.Utils.Log then
        Hydra.Utils.Log('warn', '[Inventory] ' .. msg, ...)
    else
        print(('[HYDRA][WARN][Inventory] ' .. msg):format(...))
    end
end

--- Send a notification (uses hydra_notify if available)
--- @param msg string
--- @param notifType string 'info'|'success'|'error'|'warning'
local function Notify(msg, notifType)
    if Hydra.Notify and Hydra.Notify.Show then
        Hydra.Notify.Show({ message = msg, type = notifType or 'info' })
    else
        TriggerEvent('hydra:notify:show', { message = msg, type = notifType or 'info' })
    end
end

-- =========================================================================
-- OPEN / CLOSE INVENTORY
-- =========================================================================

--- Open the inventory UI
local function OpenInventory()
    if isOpen then return end
    if IsEntityDead(PlayerPedId()) then return end

    TriggerServerEvent('hydra:inventory:open')
end

--- Close the inventory UI
local function CloseInventory()
    if not isOpen then return end

    isOpen = false
    currentInventory = nil
    secondaryInventory = nil

    SetNuiFocus(false, false)

    SendNUIMessage({
        module = 'inventory',
        action = 'close',
        data = {},
    })

    TriggerServerEvent('hydra:inventory:close')
end

--- Toggle the inventory
local function ToggleInventory()
    if isOpen then
        CloseInventory()
    else
        OpenInventory()
    end
end

-- Server responds with inventory data
RegisterNetEvent('hydra:inventory:client:open')
AddEventHandler('hydra:inventory:client:open', function(data)
    if not data then return end

    isOpen = true
    currentInventory = data.inventory
    secondaryInventory = data.secondary or nil

    SetNuiFocus(true, true)

    -- Push rarity config alongside open
    SendNUIMessage({
        module = 'inventory',
        action = 'rarityConfig',
        data = cfg.rarity or {},
    })

    SendNUIMessage({
        module = 'inventory',
        action = 'open',
        data = {
            inventory = currentInventory,
            secondary = secondaryInventory,
            config = {
                slots = cfg.player.slots,
                maxWeight = cfg.player.maxWeight,
                hotbarSlots = cfg.player.hotbarSlots,
                columns = cfg.ui.columns,
                money = data.money or nil,
            },
        },
    })
end)

-- =========================================================================
-- KEYBIND REGISTRATION (TAB to open)
-- =========================================================================

CreateThread(function()
    Wait(2000) -- allow modules to initialize

    local registered = false

    if hasKeybinds and Hydra.Keybinds and Hydra.Keybinds.Register then
        local ok = pcall(function()
            Hydra.Keybinds.Register('inventory_open', {
                key = cfg.ui.openKey or 'TAB',
                description = 'Open Inventory',
                category = 'inventory',
                module = 'hydra_inventory',
                onPress = ToggleInventory,
            })
        end)
        if ok then registered = true end
    end

    if not registered then
        RegisterCommand('hydra_inventory_open', function()
            ToggleInventory()
        end, false)
        RegisterKeyMapping('hydra_inventory_open', 'Open Inventory', 'keyboard', cfg.ui.openKey or 'TAB')
    end
end)

-- =========================================================================
-- NUI CALLBACKS
-- =========================================================================

-- Close inventory (ESC or close button)
RegisterNUICallback('closeInventory', function(_, cb)
    CloseInventory()
    cb({ ok = true })
end)

-- Move item between slots/inventories
RegisterNUICallback('moveItem', function(data, cb)
    if not data or not data.fromSlot or not data.toSlot then
        cb({ ok = false, error = 'Invalid move data' })
        return
    end

    if data.fromSlot == data.toSlot and data.fromInventory == data.toInventory then
        cb({ ok = false, error = 'Same slot' })
        return
    end

    TriggerServerEvent('hydra:inventory:move', data)
    cb({ ok = true })
end)

-- Use item from a slot
RegisterNUICallback('useItem', function(data, cb)
    if not data or not data.slot then
        cb({ ok = false, error = 'Invalid use data' })
        return
    end

    TriggerServerEvent('hydra:inventory:use', data.slot)
    cb({ ok = true })
end)

-- Drop item onto the ground
RegisterNUICallback('dropItem', function(data, cb)
    if not data or not data.slot then
        cb({ ok = false, error = 'Invalid drop data' })
        return
    end

    local count = data.count or 1
    if count < 1 then
        cb({ ok = false, error = 'Invalid count' })
        return
    end

    TriggerServerEvent('hydra:inventory:drop', data.slot, count)
    cb({ ok = true })
end)

-- Give item to nearest player
RegisterNUICallback('giveItem', function(data, cb)
    if not data or not data.slot then
        cb({ ok = false, error = 'Invalid give data' })
        return
    end

    local count = data.count or 1
    if count < 1 then
        cb({ ok = false, error = 'Invalid count' })
        return
    end

    local targetServerId = Hydra.Inventory.GetNearestPlayer(cfg.give.distance)
    if not targetServerId then
        Notify('No player nearby to give items to.', 'error')
        cb({ ok = false, error = 'No nearby player' })
        return
    end

    TriggerServerEvent('hydra:inventory:give', targetServerId, data.slot, count)
    cb({ ok = true })
end)

-- Split a stack into a new slot
RegisterNUICallback('splitItem', function(data, cb)
    if not data or not data.fromSlot or not data.toSlot or not data.count then
        cb({ ok = false, error = 'Invalid split data' })
        return
    end

    if data.count < 1 then
        cb({ ok = false, error = 'Invalid split count' })
        return
    end

    TriggerServerEvent('hydra:inventory:move', {
        fromSlot = data.fromSlot,
        toSlot = data.toSlot,
        fromInventory = data.fromInventory or 'player',
        toInventory = data.toInventory or 'player',
        count = data.count,
    })
    cb({ ok = true })
end)

-- =========================================================================
-- CONSUME SYSTEM (Client-side animation + progress)
-- =========================================================================

--- Clean up active consume prop and anim
local function ConsumeCleanup()
    local ped = PlayerPedId()

    -- Stop animation
    if hasAnims and consumeAnimDict then
        pcall(function() exports['hydra_anims']:Stop(ped, consumeAnimDict) end)
    elseif consumeAnimDict and consumeAnimClip then
        StopAnimTask(ped, consumeAnimDict, consumeAnimClip, 1.0)
    end

    -- Delete prop
    if consumePropEntity then
        if hasObject then
            pcall(function() exports['hydra_object']:Delete(consumePropEntity) end)
        elseif DoesEntityExist(consumePropEntity) then
            DeleteEntity(consumePropEntity)
        end
        consumePropEntity = nil
    end

    consumeAnimDict = nil
    consumeAnimClip = nil
    isConsuming = false
end

RegisterNetEvent('hydra:inventory:client:consume')
AddEventHandler('hydra:inventory:client:consume', function(data)
    if not data or not data.item then return end
    if isConsuming then
        Notify('You are already consuming something.', 'error')
        return
    end
    if IsEntityDead(PlayerPedId()) then return end

    isConsuming = true

    local itemName = data.item
    local consumable = data.consumable or {}
    local ped = PlayerPedId()

    -- Resolve animation parameters
    local animDict = consumable.anim and consumable.anim.dict
        or cfg.consumables.defaultAnim.dict
    local animClip = consumable.anim and consumable.anim.clip
        or cfg.consumables.defaultAnim.clip
    local animFlag = consumable.anim and consumable.anim.flag or 49
    local duration = consumable.duration or cfg.consumables.defaultDuration

    consumeAnimDict = animDict
    consumeAnimClip = animClip

    -- Play animation
    if hasAnims then
        local ok = pcall(function()
            exports['hydra_anims']:Play(ped, {
                dict = animDict,
                anim = animClip,
                flag = animFlag,
                duration = -1,
                label = 'consume_' .. itemName,
            })
        end)
        if not ok then
            -- Fallback to native
            if LoadAnimDict(animDict) then
                TaskPlayAnim(ped, animDict, animClip, 8.0, -8.0, -1, animFlag, 0, false, false, false)
            end
        end
    else
        if LoadAnimDict(animDict) then
            TaskPlayAnim(ped, animDict, animClip, 8.0, -8.0, -1, animFlag, 0, false, false, false)
        end
    end

    -- Attach prop if specified
    if consumable.prop and consumable.prop.model then
        if hasObject then
            local ok, objId = pcall(function()
                return exports['hydra_object']:Spawn({
                    model = consumable.prop.model,
                    attach = {
                        entity = ped,
                        bone = consumable.prop.bone or 57005,
                        offset = consumable.prop.offset or vector3(0.0, 0.0, 0.0),
                        rotation = consumable.prop.rotation or vector3(0.0, 0.0, 0.0),
                    },
                    owner = 'inventory',
                    tag = 'consume_prop',
                })
            end)
            if ok and objId then
                consumePropEntity = objId
            end
        else
            -- Fallback: native prop creation
            local loaded, hash = LoadModel(consumable.prop.model)
            if loaded then
                local pos = GetEntityCoords(ped)
                local prop = CreateObject(hash, pos.x, pos.y, pos.z, true, true, true)
                local bone = GetPedBoneIndex(ped, consumable.prop.bone or 57005)
                local off = consumable.prop.offset or vector3(0.0, 0.0, 0.0)
                local rot = consumable.prop.rotation or vector3(0.0, 0.0, 0.0)
                AttachEntityToEntity(prop, ped, bone,
                    off.x, off.y, off.z, rot.x, rot.y, rot.z,
                    true, true, false, true, 1, true)
                SetModelAsNoLongerNeeded(hash)
                consumePropEntity = prop
            end
        end
    end

    -- Progress bar
    local completed = false

    if hasProgressbar and Hydra.Progressbar and Hydra.Progressbar.Start then
        local finished = false
        local result = false

        Hydra.Progressbar.Start({
            label = consumable.label or ('Using ' .. (consumable.itemLabel or itemName)),
            duration = duration,
            canCancel = true,
            useWhileDead = false,
            disable = {
                combat = true,
            },
        }, function(success)
            result = success
            finished = true
        end)

        -- Wait for progress to finish
        while not finished do
            -- Cancel on damage
            if cfg.consumables.cancelOnDamage then
                local health = GetEntityHealth(PlayerPedId())
                Wait(100)
                local newHealth = GetEntityHealth(PlayerPedId())
                if newHealth < health then
                    if Hydra.Progressbar.Cancel then
                        Hydra.Progressbar.Cancel()
                    end
                end
            else
                Wait(100)
            end
        end

        completed = result
    else
        -- Fallback: simple timer with cancel on damage
        local startTime = GetGameTimer()
        local startHealth = GetEntityHealth(ped)
        local cancelled = false

        while GetGameTimer() - startTime < duration do
            Wait(100)

            if IsEntityDead(PlayerPedId()) then
                cancelled = true
                break
            end

            if cfg.consumables.cancelOnDamage then
                local currentHealth = GetEntityHealth(PlayerPedId())
                if currentHealth < startHealth then
                    cancelled = true
                    break
                end
            end
        end

        completed = not cancelled
    end

    -- Clean up animation and prop
    ConsumeCleanup()

    -- Notify server of result
    if completed then
        TriggerServerEvent('hydra:inventory:consume:complete', itemName)
    else
        TriggerServerEvent('hydra:inventory:consume:cancel', itemName)
        Notify('Cancelled.', 'error')
    end
end)

-- =========================================================================
-- SCREEN EFFECTS (drugs, alcohol, etc.)
-- =========================================================================

RegisterNetEvent('hydra:inventory:client:effect')
AddEventHandler('hydra:inventory:client:effect', function(data)
    if not data or not data.effect then return end

    local effect = data.effect
    local duration = data.duration or 10000

    if effect == 'drunk' then
        -- Drunk / alcohol effect
        SetTimecycleModifier('Drunk')
        ShakeGameplayCam('DRUNK_SHAKE', 1.0)
        SetPedMotionBlur(PlayerPedId(), true)

        CreateThread(function()
            Wait(duration)
            ClearTimecycleModifier()
            StopGameplayCamShaking(true)
            SetPedMotionBlur(PlayerPedId(), false)
        end)

    elseif effect == 'weed' then
        StartScreenEffect('DrugsMichaelAliensFight', 0, true)

        CreateThread(function()
            Wait(duration)
            StopScreenEffect('DrugsMichaelAliensFight')
        end)

    elseif effect == 'coke' then
        StartScreenEffect('DrugsTrevorClownsFight', 0, true)

        CreateThread(function()
            Wait(duration)
            StopScreenEffect('DrugsTrevorClownsFight')
        end)

    elseif effect == 'meth' then
        StartScreenEffect('DrugsTrevorClownsFightIn', 0, true)
        SetTimecycleModifier('spectator5')

        CreateThread(function()
            Wait(duration)
            StopScreenEffect('DrugsTrevorClownsFightIn')
            ClearTimecycleModifier()
        end)

    elseif effect == 'lsd' then
        StartScreenEffect('DrugsMichaelAliensFightIn', 0, true)
        SetTimecycleModifier('LostTimeDay')

        CreateThread(function()
            Wait(duration)
            StopScreenEffect('DrugsMichaelAliensFightIn')
            ClearTimecycleModifier()
        end)

    else
        -- Generic screen effect by name
        StartScreenEffect(effect, 0, true)

        CreateThread(function()
            Wait(duration)
            StopScreenEffect(effect)
        end)
    end
end)

-- =========================================================================
-- GIVE ANIMATION
-- =========================================================================

RegisterNetEvent('hydra:inventory:client:giveAnim')
AddEventHandler('hydra:inventory:client:giveAnim', function(targetServerId)
    if not cfg.give.anim then return end

    local ped = PlayerPedId()
    local dict = 'mp_common'
    local clip = 'givetake1_a'

    if hasAnims then
        pcall(function()
            exports['hydra_anims']:Play(ped, {
                dict = dict,
                anim = clip,
                flag = 49,
                duration = 1500,
                label = 'give_item',
            })
        end)
    else
        if LoadAnimDict(dict) then
            TaskPlayAnim(ped, dict, clip, 8.0, -8.0, 1500, 49, 0, false, false, false)
        end
    end
end)

RegisterNetEvent('hydra:inventory:client:receiveAnim')
AddEventHandler('hydra:inventory:client:receiveAnim', function()
    if not cfg.give.anim then return end

    local ped = PlayerPedId()
    local dict = 'mp_common'
    local clip = 'givetake1_b'

    if hasAnims then
        pcall(function()
            exports['hydra_anims']:Play(ped, {
                dict = dict,
                anim = clip,
                flag = 49,
                duration = 1500,
                label = 'receive_item',
            })
        end)
    else
        if LoadAnimDict(dict) then
            TaskPlayAnim(ped, dict, clip, 8.0, -8.0, 1500, 49, 0, false, false, false)
        end
    end
end)

-- =========================================================================
-- REAL-TIME SLOT UPDATES
-- =========================================================================

-- Inventory slot update (single or multiple slots changed)
RegisterNetEvent('hydra:inventory:client:update')
AddEventHandler('hydra:inventory:client:update', function(data)
    if not data then return end

    -- Update local cache
    if currentInventory and data.inventory then
        currentInventory = data.inventory
    end
    if secondaryInventory and data.secondary then
        secondaryInventory = data.secondary
    end

    -- Forward to NUI
    SendNUIMessage({
        module = 'inventory',
        action = 'update',
        data = data,
    })
end)

-- Money balance update
RegisterNetEvent('hydra:inventory:client:updateMoney')
AddEventHandler('hydra:inventory:client:updateMoney', function(data)
    if not data then return end

    SendNUIMessage({
        module = 'inventory',
        action = 'updateMoney',
        data = data,
    })
end)

-- Notifications from server (item added/removed, errors, etc.)
RegisterNetEvent('hydra:inventory:client:notify')
AddEventHandler('hydra:inventory:client:notify', function(data)
    if not data then return end

    if type(data) == 'string' then
        Notify(data, 'info')
    else
        Notify(data.message or '', data.type or 'info')
    end
end)

-- =========================================================================
-- HOTBAR
-- =========================================================================

local hotbarItems = {}

RegisterNetEvent('hydra:inventory:client:hotbar')
AddEventHandler('hydra:inventory:client:hotbar', function(data)
    if not data then return end
    hotbarItems = data

    SendNUIMessage({
        module = 'inventory',
        action = 'hotbar',
        data = hotbarItems,
    })
end)

--- Use a hotbar slot
--- @param slot number 1-5
local function UseHotbarSlot(slot)
    if isOpen then return end
    if IsEntityDead(PlayerPedId()) then return end
    if isConsuming then return end

    if hotbarItems[slot] and hotbarItems[slot].name then
        TriggerServerEvent('hydra:inventory:use', slot)
    end
end

-- Register hotbar keybinds (1-5)
CreateThread(function()
    Wait(2000)

    for i = 1, cfg.player.hotbarSlots do
        local slotNum = i

        if hasKeybinds and Hydra.Keybinds and Hydra.Keybinds.Register then
            local ok = pcall(function()
                Hydra.Keybinds.Register('inventory_hotbar_' .. slotNum, {
                    key = tostring(slotNum),
                    description = 'Use Hotbar Slot ' .. slotNum,
                    category = 'inventory',
                    module = 'hydra_inventory',
                    onPress = function()
                        UseHotbarSlot(slotNum)
                    end,
                })
            end)
            if not ok then
                -- Fallback
                RegisterCommand('hydra_hotbar_' .. slotNum, function()
                    UseHotbarSlot(slotNum)
                end, false)
                RegisterKeyMapping('hydra_hotbar_' .. slotNum, 'Hotbar Slot ' .. slotNum, 'keyboard', tostring(slotNum))
            end
        else
            RegisterCommand('hydra_hotbar_' .. slotNum, function()
                UseHotbarSlot(slotNum)
            end, false)
            RegisterKeyMapping('hydra_hotbar_' .. slotNum, 'Hotbar Slot ' .. slotNum, 'keyboard', tostring(slotNum))
        end
    end
end)

-- =========================================================================
-- DEATH HANDLING (close inventory on death)
-- =========================================================================

CreateThread(function()
    local wasDead = false

    while true do
        Wait(500)

        local dead = IsEntityDead(PlayerPedId())

        if dead and not wasDead then
            -- Player just died
            if isOpen then
                CloseInventory()
            end
            if isConsuming then
                ConsumeCleanup()
                TriggerServerEvent('hydra:inventory:consume:cancel', '')
            end
        end

        wasDead = dead
    end
end)

-- =========================================================================
-- HOT RELOAD — receive updated items from server
-- =========================================================================

RegisterNetEvent('hydra:inventory:client:itemsReloaded')
AddEventHandler('hydra:inventory:client:itemsReloaded', function(items, rarityDefs)
    if items then
        HydraConfig.Items = items
    end
    if rarityDefs then
        HydraConfig.Inventory.rarity = rarityDefs
    end

    -- Rebuild shared registry
    if Hydra.Inventory.ReloadItems then
        Hydra.Inventory.ReloadItems()
    end

    -- Push rarity config to NUI
    SendNUIMessage({
        module = 'inventory',
        action = 'rarityConfig',
        data = rarityDefs or HydraConfig.Inventory.rarity,
    })

    DebugLog('Items hot-reloaded — ' .. tostring(#HydraConfig.Items) .. ' items')
end)

-- =========================================================================
-- EXPORTS
-- =========================================================================

exports('IsInventoryOpen', function() return isOpen end)
exports('OpenInventory', function() OpenInventory() end)
exports('CloseInventory', function() CloseInventory() end)
exports('GetNearestPlayer', function(dist) return Hydra.Inventory.GetNearestPlayer(dist) end)
exports('GetNearestVehicle', function(dist) return Hydra.Inventory.GetNearestVehicle(dist) end)
exports('IsConsuming', function() return isConsuming end)

-- =========================================================================
-- MODULE REGISTRATION
-- =========================================================================

CreateThread(function()
    while not Hydra.Modules or not Hydra.Modules.Register do
        Wait(100)
    end

    Hydra.Modules.Register('inventory', {
        label = 'Inventory System',
        version = '1.0.0',
        author = 'Hydra Framework',
        priority = 80,
        dependencies = { 'hydra_core' },

        api = {
            IsOpen = function() return isOpen end,
            Open = OpenInventory,
            Close = CloseInventory,
            GetNearestPlayer = Hydra.Inventory.GetNearestPlayer,
            GetNearestVehicle = Hydra.Inventory.GetNearestVehicle,
            IsConsuming = function() return isConsuming end,
        },

        onLoad = function()
            DebugLog('Inventory client loading')
        end,

        onReady = function()
            DebugLog('Inventory client ready')
        end,

        onUnload = function()
            if isOpen then
                CloseInventory()
            end
            if isConsuming then
                ConsumeCleanup()
            end
            isOpen = false
            currentInventory = nil
            secondaryInventory = nil
            hotbarItems = {}
            DebugLog('Inventory client unloaded')
        end,
    })
end)
