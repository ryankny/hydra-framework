--[[
    Hydra Framework - Client NUI Helper

    Simplified NUI (browser UI) communication layer.
    Provides easy send/receive between Lua and NUI.
]]

Hydra = Hydra or {}
Hydra.NUI = Hydra.NUI or {}

local nuiCallbacks = {}
local nuiVisible = {}

--- Send data to NUI
--- @param action string
--- @param data table|nil
function Hydra.NUI.Send(action, data)
    SendNUIMessage({
        action = action,
        data = data or {},
    })
end

--- Register a NUI callback
--- @param action string
--- @param handler function(data, cb)
function Hydra.NUI.RegisterCallback(action, handler)
    nuiCallbacks[action] = handler
    RegisterNUICallback(action, function(data, cb)
        local ok, err = pcall(handler, data, cb)
        if not ok then
            Hydra.Utils.Log('error', 'NUI callback error [%s]: %s', action, tostring(err))
            cb({ success = false, error = 'Internal error' })
        end
    end)
end

--- Show/hide a NUI panel
--- @param name string panel identifier
--- @param visible boolean
--- @param focus boolean|nil capture mouse/keyboard
function Hydra.NUI.SetVisible(name, visible, focus)
    nuiVisible[name] = visible
    Hydra.NUI.Send('setVisible', { panel = name, visible = visible })

    if focus ~= nil then
        SetNuiFocus(visible and focus, visible and focus)
    end
end

--- Check if a NUI panel is visible
--- @param name string
--- @return boolean
function Hydra.NUI.IsVisible(name)
    return nuiVisible[name] or false
end

--- Close all NUI panels
function Hydra.NUI.CloseAll()
    for name in pairs(nuiVisible) do
        nuiVisible[name] = false
    end
    Hydra.NUI.Send('closeAll')
    SetNuiFocus(false, false)
end

--- Register escape key to close NUI
--- @param name string panel name
function Hydra.NUI.RegisterEscapeClose(name)
    CreateThread(function()
        while true do
            Wait(0)
            if nuiVisible[name] then
                DisableControlAction(0, 200, true) -- ESC
                if IsDisabledControlJustReleased(0, 200) then
                    Hydra.NUI.SetVisible(name, false, false)
                end
            end
        end
    end)
end
