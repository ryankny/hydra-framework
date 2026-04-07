--[[
    Hydra HUD - Client Main

    Central HUD controller. Collects data from various sources
    and sends periodic updates to the NUI layer.
    Optimized: only sends data that has changed.
]]

Hydra = Hydra or {}
Hydra.HUD = Hydra.HUD or {}

local hudVisible = false  -- Start hidden, show after character loads
local lastState = {}

--- Send data to HUD NUI
--- @param action string
--- @param data table
function Hydra.HUD.Send(action, data)
    SendNUIMessage({
        module = 'hud',
        action = action,
        data = data,
    })
end

--- Show/hide the entire HUD
--- @param visible boolean
function Hydra.HUD.SetVisible(visible)
    hudVisible = visible
    Hydra.HUD.Send('setVisible', { visible = visible })
end

--- Toggle HUD visibility
function Hydra.HUD.Toggle()
    hudVisible = not hudVisible
    Hydra.HUD.SetVisible(hudVisible)
end

--- Check if HUD is visible
--- @return boolean
function Hydra.HUD.IsVisible()
    return hudVisible
end

--- NUI ready
RegisterNUICallback('hydra:hud:ready', function(_, cb)
    -- Send initial config with visibility state
    Hydra.HUD.Send('init', {
        config = HydraHUDConfig,
        visible = hudVisible,
    })
    cb({ success = true })
end)

--- Receive money updates from server
RegisterNetEvent('hydra:hud:moneyUpdate')
AddEventHandler('hydra:hud:moneyUpdate', function(accountType, amount, action)
    Hydra.HUD.Send('moneyUpdate', {
        type = accountType,
        amount = amount,
        action = action,
    })
end)

--- Receive job updates
RegisterNetEvent('hydra:hud:jobUpdate')
AddEventHandler('hydra:hud:jobUpdate', function(job)
    Hydra.HUD.Send('jobUpdate', job)
end)

--- Register HUD toggle keybind (via hydra_keybinds if available)
CreateThread(function()
    Wait(500)
    local ok = pcall(function()
        exports['hydra_keybinds']:Register('togglehud', {
            key = 'F7',
            description = 'Toggle HUD',
            category = 'ui',
            module = 'hydra_hud',
            onPress = function() Hydra.HUD.Toggle() end,
        })
    end)
    if not ok then
        RegisterCommand('togglehud', function() Hydra.HUD.Toggle() end, false)
        RegisterKeyMapping('togglehud', 'Toggle HUD', 'keyboard', 'F7')
    end
end)

--- Disable default GTA HUD elements that Hydra replaces
CreateThread(function()
    while not Hydra.HUD.IsVisible() do Wait(500) end

    while true do
        Wait(0)

        -- Hide all native GTA HUD elements that Hydra replaces
        HideHudComponentThisFrame(1)   -- Wanted stars
        HideHudComponentThisFrame(2)   -- Weapon icon
        HideHudComponentThisFrame(3)   -- Cash
        HideHudComponentThisFrame(4)   -- MP Cash
        HideHudComponentThisFrame(5)   -- MP message large
        HideHudComponentThisFrame(6)   -- Vehicle name
        HideHudComponentThisFrame(7)   -- Area name
        HideHudComponentThisFrame(8)   -- Vehicle class
        HideHudComponentThisFrame(9)   -- Street name
        HideHudComponentThisFrame(10)  -- Help text
        HideHudComponentThisFrame(11)  -- Floating help text
        HideHudComponentThisFrame(12)  -- Money change
        HideHudComponentThisFrame(13)  -- MP rank bar

        -- Hide native health/armour arcs around minimap
        -- The arcs only show when health < max or armour > 0 in the HUD's view.
        -- SetPlayerHealthRechargeLimit makes the regen bar disappear.
        -- SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0) prevents the regen flash.
        SetPlayerHealthRechargeLimit(PlayerId(), GetEntityMaxHealth(PlayerPedId()))
        SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
    end
end)
