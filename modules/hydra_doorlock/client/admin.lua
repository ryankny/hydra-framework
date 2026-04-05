--[[
    Hydra Doorlock - Client Admin

    In-game door creation tool. Admin looks at a door entity,
    fills out a form, and the door is created and synced.
]]

Hydra = Hydra or {}

local cfg = HydraDoorlockConfig
local isCreating = false
local isDeleting = false

-- =============================================
-- CREATE MODE
-- =============================================

RegisterNetEvent('hydra:doorlock:admin:startCreate')
AddEventHandler('hydra:doorlock:admin:startCreate', function()
    if isCreating then return end
    isCreating = true

    TriggerEvent('hydra:notify:show', {
        type = 'info', title = 'Doorlock Admin',
        message = 'Look at a door and press E to select it, or press X to cancel.',
        duration = 8000,
    })

    CreateThread(function()
        while isCreating do
            Wait(0)

            -- Cancel
            if IsControlJustPressed(0, 73) then -- X
                isCreating = false
                TriggerEvent('hydra:notify:show', {
                    type = 'info', title = 'Doorlock Admin',
                    message = 'Creation cancelled.',
                    duration = 2000,
                })
                return
            end

            -- Raycast for door entity
            local hit, coords, _, entity = Hydra.Target and Hydra.Target.Raycast(10.0, 16) or false, nil, nil, 0

            if hit and entity ~= 0 and GetEntityType(entity) == 3 then
                -- Highlight entity
                SetEntityDrawOutline(entity, true)
                SetEntityDrawOutlineColor(108, 92, 231, 200)

                -- Draw helper text
                SetTextFont(4)
                SetTextScale(0.0, 0.35)
                SetTextColour(108, 92, 231, 255)
                SetTextCentre(true)
                SetTextDropShadow()
                SetTextOutline()
                SetTextEntry('STRING')
                AddTextComponentString('~p~[E]~w~ Select this door')
                DrawText(0.5, 0.9)

                if IsControlJustPressed(0, 38) then -- E
                    isCreating = false
                    SetEntityDrawOutline(entity, false)

                    local entCoords = GetEntityCoords(entity)
                    local entModel = GetEntityModel(entity)
                    local entHeading = GetEntityHeading(entity)

                    showDoorCreationForm(entCoords, entModel, entHeading)
                    return
                end
            end

            -- Draw mode indicator
            SetTextFont(4)
            SetTextScale(0.0, 0.3)
            SetTextColour(255, 255, 255, 180)
            SetTextCentre(true)
            SetTextEntry('STRING')
            AddTextComponentString('DOORLOCK CREATE MODE - Look at a door')
            DrawText(0.5, 0.05)
        end
    end)
end)

--- Show the door creation form
function showDoorCreationForm(coords, model, heading)
    if not Hydra.Input or not Hydra.Input.Show then
        TriggerEvent('hydra:notify:show', {
            type = 'error', title = 'Doorlock',
            message = 'hydra_input required for door creation.',
        })
        return
    end

    -- Build lock type options
    local typeOptions = {}
    for key, def in pairs(cfg.lock_types) do
        typeOptions[#typeOptions + 1] = { value = key, label = def.label }
    end

    Hydra.Input.Show({
        title = 'Create Door Lock',
        description = ('Model: %d | Pos: %.1f, %.1f, %.1f'):format(model, coords.x, coords.y, coords.z),
        fields = {
            { type = 'text', name = 'label', label = 'Door Name', placeholder = 'PD Front Door', required = true },
            { type = 'select', name = 'lock_type', label = 'Lock Type', options = typeOptions, default = 'job' },
            { type = 'text', name = 'lock_detail', label = 'Lock Detail', placeholder = 'Job: police,ambulance | Code: 1234 | Item: key_pd | Perm: hydra.pd' },
            { type = 'number', name = 'min_grade', label = 'Min Job Grade (job type)', default = 0, min = 0, max = 99 },
            { type = 'number', name = 'auto_lock', label = 'Auto Lock (seconds, 0=disabled)', default = 0, min = 0, max = 3600 },
            { type = 'checkbox', name = 'locked', label = 'Start Locked', default = true },
        },
        submitText = 'Create Door',
    }, function(result)
        if not result then return end

        -- Parse lock_data from the detail field
        local lockData = {}
        local lockType = result.lock_type or 'public'

        if lockType == 'job' then
            local detail = result.lock_detail or ''
            local jobs = {}
            for job in detail:gmatch('[^,%s]+') do
                jobs[#jobs + 1] = job
            end
            if #jobs == 0 then jobs = { 'police' } end
            lockData = { jobs = jobs, min_grade = result.min_grade or 0 }

        elseif lockType == 'keypad' then
            lockData = { code = result.lock_detail or '0000' }

        elseif lockType == 'item' then
            lockData = { item = result.lock_detail or 'key' }

        elseif lockType == 'permission' then
            lockData = { permission = result.lock_detail or 'hydra.access' }

        elseif lockType == 'owner' then
            -- Set current player as owner
            lockData = { identifier = 'self' } -- Server resolves this
        end

        TriggerServerEvent('hydra:doorlock:admin:create', {
            label = result.label,
            coords = { x = coords.x, y = coords.y, z = coords.z },
            model = model,
            heading = heading,
            locked = result.locked ~= false,
            lock_type = lockType,
            lock_data = lockData,
            auto_lock = result.auto_lock or 0,
        })
    end)
end

-- =============================================
-- DELETE MODE
-- =============================================

RegisterNetEvent('hydra:doorlock:admin:startDelete')
AddEventHandler('hydra:doorlock:admin:startDelete', function()
    local id, door, dist = Hydra.Doorlock.GetNearestDoor()
    if not id then
        TriggerEvent('hydra:notify:show', {
            type = 'error', title = 'Doorlock',
            message = 'No door nearby to delete.',
            duration = 3000,
        })
        return
    end

    if Hydra.Input and Hydra.Input.Confirm then
        Hydra.Input.Confirm('Delete Door', ('Delete "%s"? This cannot be undone.'):format(door.label or id), function(confirmed)
            if confirmed then
                TriggerServerEvent('hydra:doorlock:admin:delete', id)
            end
        end)
    else
        TriggerServerEvent('hydra:doorlock:admin:delete', id)
    end
end)

-- =============================================
-- NEAREST DOOR INFO
-- =============================================

RegisterNetEvent('hydra:doorlock:admin:showNearest')
AddEventHandler('hydra:doorlock:admin:showNearest', function()
    local id, door, dist = Hydra.Doorlock.GetNearestDoor()
    if not id then
        TriggerEvent('hydra:notify:show', {
            type = 'info', title = 'Doorlock',
            message = 'No doors nearby.',
            duration = 3000,
        })
        return
    end

    local info = ('ID: %s\nLabel: %s\nType: %s\nState: %s\nModel: %d\nDist: %.1f'):format(
        id, door.label or id, door.lock_type or 'unknown',
        door.locked and 'LOCKED' or 'UNLOCKED',
        door.model or 0, dist
    )

    TriggerEvent('hydra:notify:show', {
        type = 'info', title = 'Door Info',
        message = info,
        duration = 10000,
    })
end)
