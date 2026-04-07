--[[
    Hydra Players - Server Main

    Registers the player module with Hydra and sets up lifecycle hooks.
]]

Hydra = Hydra or {}

--- Create the players collection (database table)
local function createPlayersCollection()
    exports['hydra_data']:CreateCollection('players', {
        { name = 'identifier',       type = 'VARCHAR(64)',  nullable = false },
        { name = 'last_name',        type = 'VARCHAR(64)',  nullable = true },
        { name = 'permission_group', type = 'VARCHAR(32)',  default = 'user' },
        { name = 'accounts',         type = 'LONGTEXT',     default = '{}' },
        { name = 'job',              type = 'TEXT',          default = '{}' },
        { name = 'position',         type = 'TEXT',          default = '{}' },
        { name = 'metadata',         type = 'LONGTEXT',     default = '{}' },
        { name = 'charinfo',         type = 'TEXT',          default = '{}' },
        { name = 'inventory',        type = 'LONGTEXT',     default = '{}' },
        { name = 'last_login',       type = 'DATETIME',     nullable = true },
    }, {
        indexes = {
            { name = 'idx_identifier', columns = { 'identifier' }, unique = true },
            { name = 'idx_permission_group', columns = { 'permission_group' } },
        },
    })
end

--- Register as Hydra module (metadata only)
Hydra.Modules.Register('players', {
    label = 'Hydra Players',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 80,
    dependencies = { 'data' },
})

--- Initialize on framework ready
Hydra.OnReady(function()
    createPlayersCollection()
    Hydra.Players.InitJobs()

    -- Auto-save loop
    local interval = HydraPlayersConfig and HydraPlayersConfig.auto_save_interval or 300
    if interval > 0 then
        CreateThread(function()
            while true do
                Wait(interval * 1000)
                Hydra.Players.SaveAll()
            end
        end)
    end

    Hydra.Utils.Log('info', 'Players module loaded')
end)

--- Player loaded — load player data (if identity module is NOT handling it)
RegisterNetEvent('hydra:playerLoaded')
AddEventHandler('hydra:playerLoaded', function()
    local src = source

    -- If identity module is loaded, it handles character selection & loading
    if Hydra.Modules.IsLoaded('identity') then
        return
    end

    local data = Hydra.Players.Load(src)
    if data then
        TriggerClientEvent('hydra:players:loaded', src, {
            name = data.name,
            group = data.group,
            accounts = data.accounts,
            job = data.job,
            position = data.position,
            charinfo = data.charinfo,
        })

        TriggerEvent('hydra:players:playerLoaded', src, data)

        local ok, mode = pcall(function() return exports['hydra_bridge']:GetBridgeMode() end)
        local bridge = ok and mode or 'native'
        if bridge == 'esx' then
            TriggerClientEvent('esx:playerLoaded', src, data)
        elseif bridge == 'qbcore' or bridge == 'qbox' then
            TriggerClientEvent('QBCore:Client:OnPlayerLoaded', src)
        end
    end
end)

--- Player dropped — save and unload
AddEventHandler('playerDropped', function(reason)
    local src = source
    if Hydra.Players and Hydra.Players.Unload then
        Hydra.Players.Unload(src)
    end
end)

-- Register server callbacks
Hydra.OnReady(function()
    -- Get player data callback
    exports['hydra_core']:RegisterCallback('hydra:players:getData', function(src, cb)
        local data = Hydra.Players.GetPlayer(src)
        cb(data ~= nil, data)
    end)

    -- Get money callback
    exports['hydra_core']:RegisterCallback('hydra:players:getMoney', function(src, cb, accountType)
        cb(Hydra.Players.GetMoney(src, accountType or 'cash'))
    end)

    -- Get job callback
    exports['hydra_core']:RegisterCallback('hydra:players:getJob', function(src, cb)
        cb(Hydra.Players.GetJob(src))
    end)
end)

-- Server exports
exports('GetPlayer', function(...) return Hydra.Players.GetPlayer(...) end)
exports('GetAllPlayers', function(...) return Hydra.Players.GetAllPlayers(...) end)
exports('GetAllPlayerIds', function(...) return Hydra.Players.GetAllPlayerIds(...) end)
exports('GetPlayerByIdentifier', function(...) return Hydra.Players.GetPlayerByIdentifier(...) end)
exports('AddMoney', function(...) return Hydra.Players.AddMoney(...) end)
exports('RemoveMoney', function(...) return Hydra.Players.RemoveMoney(...) end)
exports('SetMoney', function(...) return Hydra.Players.SetMoney(...) end)
exports('GetMoney', function(...) return Hydra.Players.GetMoney(...) end)
exports('SetJob', function(...) return Hydra.Players.SetJob(...) end)
exports('GetJob', function(...) return Hydra.Players.GetJob(...) end)
exports('SetGroup', function(...) return Hydra.Players.SetGroup(...) end)
exports('GetGroup', function(...) return Hydra.Players.GetGroup(...) end)
exports('SetMetadata', function(...) return Hydra.Players.SetMetadata(...) end)
exports('GetMetadata', function(...) return Hydra.Players.GetMetadata(...) end)
exports('SavePlayer', function(...) return Hydra.Players.Save(...) end)
exports('SaveAllPlayers', function(...) return Hydra.Players.SaveAll(...) end)
exports('GetIdentifier', function(...) return Hydra.Players.GetIdentifier(...) end)
exports('InjectPlayer', function(...) return Hydra.Players._InjectPlayer(...) end)
