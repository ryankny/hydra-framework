--[[
    Hydra Context - Client

    Context menus: list-style and radial. Supports nested
    sub-menus, icons, descriptions, disabled items, and
    server event triggers. Single menu at a time.
]]

Hydra = Hydra or {}
Hydra.Context = {}

local isOpen = false
local menuStack = {}  -- For nested back-navigation
local registeredMenus = {} -- Named menu registry

--- Register a named menu for quick access
--- @param id string
--- @param menu table
function Hydra.Context.Register(id, menu)
    registeredMenus[id] = menu
end

--- Unregister a named menu
--- @param id string
function Hydra.Context.Unregister(id)
    registeredMenus[id] = nil
end

--- Show a context menu
--- @param menu table
---   id       string|nil    - Menu ID (for back navigation)
---   title    string        - Menu title
---   type     string|nil    - 'list' (default) or 'radial'
---   items    table         - Array of item definitions:
---     { label = string, description = string|nil, icon = string|nil,
---       disabled = bool|nil, event = string|nil, serverEvent = string|nil,
---       args = any, submenu = string|nil (registered menu id),
---       onSelect = function|nil }
function Hydra.Context.Show(menu)
    if isOpen then
        Hydra.Context.Hide(true)
    end

    isOpen = true
    menuStack = {}

    SetNuiFocus(true, true)

    -- Sanitize items for NUI (strip functions, keep metadata)
    local nuiItems = {}
    for i, item in ipairs(menu.items or {}) do
        nuiItems[i] = {
            index = i,
            label = item.label,
            description = item.description,
            icon = item.icon,
            disabled = item.disabled or false,
            hasSubmenu = item.submenu ~= nil,
        }
    end

    SendNUIMessage({
        module = 'context',
        action = 'show',
        data = {
            id = menu.id,
            title = menu.title or 'Menu',
            type = menu.type or 'list',
            items = nuiItems,
            canGoBack = #menuStack > 0,
        },
    })

    -- Store current menu reference for item lookups
    Hydra.Context._currentMenu = menu
end

--- Show a registered menu by ID
--- @param id string
function Hydra.Context.ShowRegistered(id)
    local menu = registeredMenus[id]
    if not menu then
        Hydra.Utils.Log('warn', 'Context menu "%s" not registered', id)
        return
    end
    Hydra.Context.Show(menu)
end

--- Hide the context menu
--- @param silent bool|nil  - Don't clear menu stack
function Hydra.Context.Hide(silent)
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({
        module = 'context',
        action = 'hide',
    })

    if not silent then
        menuStack = {}
        Hydra.Context._currentMenu = nil
    end
end

--- Check if context menu is open
--- @return bool
function Hydra.Context.IsOpen()
    return isOpen
end

--- NUI: Item selected
RegisterNUICallback('context:select', function(data, cb)
    if not isOpen then cb({ ok = false }) return end

    local menu = Hydra.Context._currentMenu
    if not menu or not menu.items then cb({ ok = false }) return end

    local item = menu.items[data.index]
    if not item or item.disabled then cb({ ok = false }) return end

    -- Submenu navigation
    if item.submenu then
        local subMenu = registeredMenus[item.submenu]
        if subMenu then
            menuStack[#menuStack + 1] = menu
            Hydra.Context.Show(subMenu)
            cb({ ok = true })
            return
        end
    end

    -- Close menu before firing events
    Hydra.Context.Hide()

    -- Fire events
    if item.onSelect then
        item.onSelect(item.args)
    end

    if item.event then
        TriggerEvent(item.event, item.args)
    end

    if item.serverEvent then
        TriggerServerEvent(item.serverEvent, item.args)
    end

    cb({ ok = true })
end)

--- NUI: Close
RegisterNUICallback('context:close', function(_, cb)
    Hydra.Context.Hide()
    cb({ ok = true })
end)

--- NUI: Back navigation
RegisterNUICallback('context:back', function(_, cb)
    if #menuStack > 0 then
        local prev = menuStack[#menuStack]
        menuStack[#menuStack] = nil
        isOpen = false -- Reset so Show() works
        Hydra.Context.Show(prev)
    else
        Hydra.Context.Hide()
    end
    cb({ ok = true })
end)

-- Close on escape
CreateThread(function()
    while true do
        Wait(0)
        if isOpen then
            DisableControlAction(0, 200, true)
            if IsDisabledControlJustPressed(0, 200) then
                -- Go back if possible, otherwise close
                if #menuStack > 0 then
                    local prev = menuStack[#menuStack]
                    menuStack[#menuStack] = nil
                    isOpen = false
                    Hydra.Context.Show(prev)
                else
                    Hydra.Context.Hide()
                end
            end
        end
    end
end)

-- Exports
exports('ContextShow', function(menu)
    Hydra.Context.Show(menu)
end)

exports('ContextShowRegistered', function(id)
    Hydra.Context.ShowRegistered(id)
end)

exports('ContextRegister', function(id, menu)
    Hydra.Context.Register(id, menu)
end)

exports('ContextUnregister', function(id)
    Hydra.Context.Unregister(id)
end)

exports('ContextHide', function()
    Hydra.Context.Hide()
end)

exports('IsContextOpen', function()
    return Hydra.Context.IsOpen()
end)
