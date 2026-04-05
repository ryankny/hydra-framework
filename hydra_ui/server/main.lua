--[[
    Hydra UI - Server Main

    Registers the UI module and syncs theme to clients.
]]

Hydra = Hydra or {}

Hydra.Modules.Register('ui', {
    label = 'Hydra UI Engine',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 88,

    onLoad = function()
        Hydra.Utils.Log('info', 'UI engine loaded')
    end,

    onPlayerJoin = function(src)
        -- Send theme config to client
        TriggerClientEvent('hydra:ui:syncTheme', src, Hydra.UI.Theme)
    end,

    api = {
        GetTheme = function() return Hydra.UI.Theme end,
    },
})

-- Allow server to push UI commands to specific clients
RegisterNetEvent('hydra:ui:serverCommand')
AddEventHandler('hydra:ui:serverCommand', function(target, action, data)
    if source ~= 0 then return end -- Server only
    TriggerClientEvent('hydra:ui:command', target, action, data)
end)
