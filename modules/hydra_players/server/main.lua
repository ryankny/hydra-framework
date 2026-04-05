--[[
    Hydra Players - Server Main

    Registers the player module with Hydra and sets up lifecycle hooks.
]]

Hydra = Hydra or {}

--- Create the players collection (database table)
local function createPlayersCollection()
    Hydra.Data.Collections.Create('players', {
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

--- Register as Hydra module
Hydra.Modules.Register('players', {
    label = 'Hydra Players',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 80,
    dependencies = { 'data' },

    onLoad = function()
        -- Create database table
        createPlayersCollection()

        -- Initialize jobs
        Hydra.Players.InitJobs()

        -- Start auto-save loop
        local interval = HydraPlayersConfig.auto_save_interval or 300
        if interval > 0 then
            CreateThread(function()
                while true do
                    Wait(interval * 1000)
                    Hydra.Players.SaveAll()
                end
            end)
        end

        Hydra.Utils.Log('info', 'Players module loaded')
    end,

    onPlayerConnecting = function(src, name, deferrals)
        -- Player connecting is handled in player.lua Load
    end,

    onPlayerJoin = function(src)
        -- If identity module is loaded, it handles character selection & loading
        if Hydra.Modules.IsLoaded and Hydra.Modules.IsLoaded('identity') then
            return
        end

        -- Load player data when they fully join
        local data = Hydra.Players.Load(src)
        if data then
            -- Notify client of their data
            TriggerClientEvent('hydra:players:loaded', src, {
                name = data.name,
                group = data.group,
                accounts = data.accounts,
                job = data.job,
                position = data.position,
                charinfo = data.charinfo,
            })

            -- Emit framework events for bridge compatibility
            TriggerEvent('hydra:players:playerLoaded', src, data)

            -- Bridge events
            local bridge = Hydra.Bridge and Hydra.Bridge.GetMode() or 'native'
            if bridge == 'esx' then
                TriggerClientEvent('esx:playerLoaded', src, data)
            elseif bridge == 'qbcore' or bridge == 'qbox' then
                TriggerClientEvent('QBCore:Client:OnPlayerLoaded', src)
            end
        end
    end,

    onPlayerDrop = function(src, reason)
        Hydra.Players.Unload(src)
    end,

    -- Public API exposed to other modules
    api = {
        GetPlayer = function(...) return Hydra.Players.GetPlayer(...) end,
        GetAllPlayers = function(...) return Hydra.Players.GetAllPlayers(...) end,
        GetAllPlayerIds = function(...) return Hydra.Players.GetAllPlayerIds(...) end,
        GetPlayerByIdentifier = function(...) return Hydra.Players.GetPlayerByIdentifier(...) end,
        GetIdentifier = function(...) return Hydra.Players.GetIdentifier(...) end,

        -- Money
        AddMoney = function(...) return Hydra.Players.AddMoney(...) end,
        RemoveMoney = function(...) return Hydra.Players.RemoveMoney(...) end,
        SetMoney = function(...) return Hydra.Players.SetMoney(...) end,
        GetMoney = function(...) return Hydra.Players.GetMoney(...) end,
        GetAccounts = function(...) return Hydra.Players.GetAccounts(...) end,

        -- Job
        SetJob = function(...) return Hydra.Players.SetJob(...) end,
        GetJob = function(...) return Hydra.Players.GetJob(...) end,
        GetJobs = function(...) return Hydra.Players.GetJobs(...) end,
        RegisterJob = function(...) return Hydra.Players.RegisterJob(...) end,

        -- Group
        SetGroup = function(...) return Hydra.Players.SetGroup(...) end,
        GetGroup = function(...) return Hydra.Players.GetGroup(...) end,

        -- Character
        GetCharInfo = function(...) return Hydra.Players.GetCharInfo(...) end,
        SetCharInfo = function(...) return Hydra.Players.SetCharInfo(...) end,
        SetCharInfoBulk = function(...) return Hydra.Players.SetCharInfoBulk(...) end,

        -- Metadata
        SetMetadata = function(...) return Hydra.Players.SetMetadata(...) end,
        GetMetadata = function(...) return Hydra.Players.GetMetadata(...) end,

        -- Items
        RegisterUsableItem = function(...) return Hydra.Players.RegisterUsableItem(...) end,
        UseItem = function(...) return Hydra.Players.UseItem(...) end,

        -- Save
        Save = function(...) return Hydra.Players.Save(...) end,
        SaveAll = function(...) return Hydra.Players.SaveAll(...) end,
    },
})

-- Register server callbacks
Hydra.OnReady(function()
    -- Get player data callback
    Hydra.Callbacks.Register('hydra:players:getData', function(src, cb)
        local data = Hydra.Players.GetPlayer(src)
        cb(data ~= nil, data)
    end)

    -- Get money callback
    Hydra.Callbacks.Register('hydra:players:getMoney', function(src, cb, accountType)
        cb(Hydra.Players.GetMoney(src, accountType or 'cash'))
    end)

    -- Get job callback
    Hydra.Callbacks.Register('hydra:players:getJob', function(src, cb)
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
