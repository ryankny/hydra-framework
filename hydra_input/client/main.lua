--[[
    Hydra Input - Client

    Modal input dialogs: single text, multi-field forms,
    confirmations, number inputs, dropdowns.
    Promise-style via callbacks. One dialog at a time.
]]

Hydra = Hydra or {}
Hydra.Input = {}

local isOpen = false
local activeCb = nil

--- Show an input dialog
--- @param options table
---   title   string          - Dialog title
---   fields  table           - Array of field definitions:
---     { type = 'text'|'number'|'password'|'select'|'checkbox'|'textarea',
---       label = string, name = string, placeholder = string,
---       required = bool, default = any, min = number, max = number,
---       options = { {value, label}, ... } (for select) }
--- @param cb function(result: table|nil)  - nil if cancelled
function Hydra.Input.Show(options, cb)
    if isOpen then
        if cb then cb(nil) end
        return
    end

    isOpen = true
    activeCb = cb

    SetNuiFocus(true, true)

    SendNUIMessage({
        module = 'input',
        action = 'show',
        data = {
            title = options.title or 'Input',
            description = options.description,
            fields = options.fields or {},
            submitText = options.submitText or 'Confirm',
            cancelText = options.cancelText or 'Cancel',
        },
    })
end

--- Show a simple confirmation dialog
--- @param title string
--- @param message string
--- @param cb function(confirmed: bool)
function Hydra.Input.Confirm(title, message, cb)
    if isOpen then
        if cb then cb(false) end
        return
    end

    isOpen = true
    activeCb = function(result)
        if cb then cb(result ~= nil) end
    end

    SetNuiFocus(true, true)

    SendNUIMessage({
        module = 'input',
        action = 'confirm',
        data = {
            title = title or 'Confirm',
            message = message or 'Are you sure?',
        },
    })
end

--- Close the active dialog
function Hydra.Input.Close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({
        module = 'input',
        action = 'hide',
    })

    local cb = activeCb
    activeCb = nil
    if cb then cb(nil) end
end

--- NUI: Submit form
RegisterNUICallback('input:submit', function(data, cb)
    if not isOpen then cb({ ok = false }) return end

    isOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({
        module = 'input',
        action = 'hide',
    })

    local callback = activeCb
    activeCb = nil
    if callback then callback(data.values) end
    cb({ ok = true })
end)

--- NUI: Cancel/close
RegisterNUICallback('input:cancel', function(_, cb)
    Hydra.Input.Close()
    cb({ ok = true })
end)

-- Close on escape
CreateThread(function()
    while true do
        Wait(0)
        if isOpen then
            DisableControlAction(0, 200, true) -- ESC/MAP
            if IsDisabledControlJustPressed(0, 200) then
                Hydra.Input.Close()
            end
        end
    end
end)

-- Exports
exports('InputShow', function(options, cb)
    Hydra.Input.Show(options, cb)
end)

exports('InputConfirm', function(title, message, cb)
    Hydra.Input.Confirm(title, message, cb)
end)

exports('InputClose', function()
    Hydra.Input.Close()
end)

-- Event API
RegisterNetEvent('hydra:input:show')
AddEventHandler('hydra:input:show', function(options)
    Hydra.Input.Show(options, function(result)
        TriggerEvent('hydra:input:result', result)
        if options._serverCb then
            TriggerServerEvent('hydra:input:result', result)
        end
    end)
end)
