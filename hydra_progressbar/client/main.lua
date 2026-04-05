--[[
    Hydra Progressbar - Client

    Lightweight progress bar with optional animation disable,
    movement/combat cancellation, and prop/anim support.
    Single active bar at a time for performance.
]]

Hydra = Hydra or {}
Hydra.Progressbar = {}

local isActive = false
local activeCb = nil
local activeOptions = nil

--- Start a progress bar
--- @param options table
---   label    string   - Text to display
---   duration number   - Duration in ms
---   useWhileDead bool - Allow while dead (default false)
---   canCancel bool    - Allow cancellation via movement/combat (default true)
---   disable  table    - { move = bool, car = bool, combat = bool, mouse = bool }
---   anim     table|nil - { dict = string, clip = string, flag = number }
---   prop     table|nil - { model = string, bone = number, offset = vec3, rotation = vec3 }
--- @param cb function(completed: bool)
function Hydra.Progressbar.Start(options, cb)
    if isActive then
        if cb then cb(false) end
        return
    end

    local ped = PlayerPedId()

    -- Dead check
    if not options.useWhileDead and IsEntityDead(ped) then
        if cb then cb(false) end
        return
    end

    isActive = true
    activeCb = cb
    activeOptions = options

    local disable = options.disable or {}
    local duration = options.duration or 3000

    -- Play animation
    if options.anim and options.anim.dict then
        RequestAnimDict(options.anim.dict)
        local t = 0
        while not HasAnimDictLoaded(options.anim.dict) and t < 2000 do
            Wait(10)
            t = t + 10
        end
        if HasAnimDictLoaded(options.anim.dict) then
            TaskPlayAnim(ped, options.anim.dict, options.anim.clip or 'idle',
                8.0, -8.0, -1, options.anim.flag or 49, 0, false, false, false)
        end
    end

    -- Attach prop
    local propEntity = nil
    if options.prop and options.prop.model then
        local model = GetHashKey(options.prop.model)
        RequestModel(model)
        local t = 0
        while not HasModelLoaded(model) and t < 2000 do
            Wait(10)
            t = t + 10
        end
        if HasModelLoaded(model) then
            local pos = GetEntityCoords(ped)
            propEntity = CreateObject(model, pos.x, pos.y, pos.z, true, true, true)
            local bone = GetPedBoneIndex(ped, options.prop.bone or 57005)
            local off = options.prop.offset or vector3(0.0, 0.0, 0.0)
            local rot = options.prop.rotation or vector3(0.0, 0.0, 0.0)
            AttachEntityToEntity(propEntity, ped, bone, off.x, off.y, off.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(model)
        end
    end

    -- Send to NUI
    SendNUIMessage({
        module = 'progressbar',
        action = 'start',
        data = {
            label = options.label or 'Processing...',
            duration = duration,
        },
    })

    -- Control loop
    CreateThread(function()
        local canCancel = options.canCancel ~= false
        local startTime = GetGameTimer()

        while isActive do
            Wait(0)

            local now = GetGameTimer()

            -- Duration complete
            if now - startTime >= duration then
                Hydra.Progressbar._Finish(true, propEntity)
                return
            end

            -- Disable controls
            if disable.move then
                DisableControlAction(0, 30, true)  -- move lr
                DisableControlAction(0, 31, true)  -- move ud
                DisableControlAction(0, 21, true)  -- sprint
                DisableControlAction(0, 36, true)  -- stealth
            end
            if disable.car then
                DisableControlAction(0, 71, true)  -- accelerate
                DisableControlAction(0, 72, true)  -- brake
                DisableControlAction(0, 75, true)  -- exit vehicle
            end
            if disable.combat then
                DisableControlAction(0, 24, true)  -- attack
                DisableControlAction(0, 25, true)  -- aim
                DisableControlAction(0, 47, true)  -- weapon
                DisableControlAction(0, 58, true)  -- weapon
                DisableControlAction(0, 263, true) -- melee
                DisableControlAction(0, 264, true) -- melee
            end
            if disable.mouse then
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
            end

            -- Cancel checks
            if canCancel then
                -- Cancel on death
                if IsEntityDead(PlayerPedId()) then
                    Hydra.Progressbar._Finish(false, propEntity)
                    return
                end
                -- Cancel on movement (if move not disabled, check if player is running)
                if not disable.move and IsPedRagdoll(PlayerPedId()) then
                    Hydra.Progressbar._Finish(false, propEntity)
                    return
                end
            end
        end
    end)
end

--- Cancel the active progress bar
function Hydra.Progressbar.Cancel()
    if isActive then
        Hydra.Progressbar._Finish(false)
    end
end

--- Check if a progress bar is active
--- @return bool
function Hydra.Progressbar.IsActive()
    return isActive
end

--- Internal: finish and clean up
function Hydra.Progressbar._Finish(completed, propEntity)
    if not isActive then return end
    isActive = false

    -- Stop animation
    local ped = PlayerPedId()
    if activeOptions and activeOptions.anim then
        StopAnimTask(ped, activeOptions.anim.dict, activeOptions.anim.clip or 'idle', 1.0)
    end

    -- Remove prop
    if propEntity and DoesEntityExist(propEntity) then
        DeleteEntity(propEntity)
    end

    -- Hide NUI
    SendNUIMessage({
        module = 'progressbar',
        action = 'stop',
    })

    -- Invoke callback
    local cb = activeCb
    activeCb = nil
    activeOptions = nil

    if cb then cb(completed) end
end

-- NUI callback for cancel button
RegisterNUICallback('progressbar:cancel', function(_, cb)
    Hydra.Progressbar.Cancel()
    cb({ ok = true })
end)

-- Export API
exports('ProgressStart', function(options, cb)
    Hydra.Progressbar.Start(options, cb)
end)

exports('ProgressCancel', function()
    Hydra.Progressbar.Cancel()
end)

exports('IsProgressActive', function()
    return Hydra.Progressbar.IsActive()
end)

-- Event-based API for cross-resource usage
RegisterNetEvent('hydra:progressbar:start')
AddEventHandler('hydra:progressbar:start', function(options)
    Hydra.Progressbar.Start(options, function(completed)
        TriggerEvent('hydra:progressbar:finished', completed)
    end)
end)
