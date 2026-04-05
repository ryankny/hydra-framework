--[[
    Hydra HUD - Server Main
]]

Hydra = Hydra or {}

Hydra.Modules.Register('hud', {
    label = 'Hydra HUD',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 60,
    dependencies = { 'players' },

    onLoad = function()
        Hydra.Utils.Log('info', 'HUD module loaded')
    end,

    api = {},
})

-- Send player money updates to HUD
AddEventHandler('hydra:players:moneyChanged', function(source, accountType, amount, action)
    TriggerClientEvent('hydra:hud:moneyUpdate', source, accountType, amount, action)
end)

-- Send job updates to HUD
AddEventHandler('hydra:players:jobChanged', function(source, job)
    TriggerClientEvent('hydra:hud:jobUpdate', source, job)
end)
