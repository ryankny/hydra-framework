--[[
    Hydra UI - Client Main

    Core client UI engine. Manages the NUI frame and provides
    the API for all Hydra UI modules (HUD, notifications, menus, etc.)
]]

Hydra = Hydra or {}
Hydra.UI = Hydra.UI or {}

local uiReady = false
local pendingMessages = {}

--- Send a message to the NUI frame
--- @param module string target module ('notify', 'hud', 'menu', etc.)
--- @param action string action name
--- @param data table|nil payload
function Hydra.UI.Send(module, action, data)
    local msg = {
        module = module,
        action = action,
        data = data or {},
    }

    if uiReady then
        SendNUIMessage(msg)
    else
        pendingMessages[#pendingMessages + 1] = msg
    end
end

--- Register a NUI callback
--- @param name string
--- @param handler function(data, cb)
function Hydra.UI.OnNUI(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local ok, err = pcall(handler, data, cb)
        if not ok then
            Hydra.Utils.Log('error', 'NUI callback error [%s]: %s', name, tostring(err))
            cb({ success = false })
        end
    end)
end

--- Set NUI focus
--- @param hasFocus boolean
--- @param hasCursor boolean
function Hydra.UI.SetFocus(hasFocus, hasCursor)
    SetNuiFocus(hasFocus, hasCursor)
    -- When NUI has focus, do NOT keep game input (it causes camera issues)
    SetNuiFocusKeepInput(false)
end

--- Release NUI focus
function Hydra.UI.ReleaseFocus()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end

--- NUI ready callback - flush pending messages
Hydra.UI.OnNUI('hydra:ui:ready', function(data, cb)
    uiReady = true

    -- Send theme
    Hydra.UI.Send('core', 'setTheme', Hydra.UI.Theme)

    -- Flush pending
    for _, msg in ipairs(pendingMessages) do
        SendNUIMessage(msg)
    end
    pendingMessages = {}

    cb({ success = true })

    Hydra.Utils.Log('debug', 'NUI frame ready')
end)

--- Receive theme from server
RegisterNetEvent('hydra:ui:syncTheme')
AddEventHandler('hydra:ui:syncTheme', function(theme)
    if theme then
        for k, v in pairs(theme) do
            Hydra.UI.Theme[k] = v
        end
        Hydra.UI.Send('core', 'setTheme', Hydra.UI.Theme)
    end
end)

--- Receive server commands
RegisterNetEvent('hydra:ui:command')
AddEventHandler('hydra:ui:command', function(action, data)
    Hydra.UI.Send('command', action, data)
end)

--- Close all UI panels (escape handler)
Hydra.UI.OnNUI('hydra:ui:close', function(data, cb)
    Hydra.UI.ReleaseFocus()
    cb({ success = true })
end)
