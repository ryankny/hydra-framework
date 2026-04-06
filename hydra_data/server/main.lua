--[[
    Hydra Data - Server Main

    Initializes the data layer and registers it as a Hydra module.
]]

Hydra = Hydra or {}
Hydra.Data = Hydra.Data or {}

--- Register as Hydra module
Hydra.Modules.Register('data', {
    label = 'Hydra Data Layer',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 90, -- Load early, other modules depend on data

    onLoad = function()
        -- Load data config
        local config = Hydra.ConfigManager.LoadModuleConfig('data', {
            adapter = 'mysql',
            cache = { enabled = true, default_ttl = 300, max_entries = 10000 },
            subscriptions = { enabled = true },
            auto_migrate = true,
            query = { max_results = 1000, default_page_size = 50 },
        })

        -- Initialize cache
        if config.cache and config.cache.enabled ~= false then
            Hydra.Data.Cache.Init(config.cache)
        end

        Hydra.Utils.Log('info', 'Data layer initialized (adapter=%s, cache=%s)',
            config.adapter or 'mysql',
            config.cache and config.cache.enabled ~= false and 'on' or 'off')
    end,

    onPlayerDrop = function(src)
        -- Clean up player subscriptions
        Hydra.Data.Subscriptions.CleanupPlayer(src)
    end,

    api = {
        -- CRUD
        Create = function(...) return Hydra.Data.Create(...) end,
        Read = function(...) return Hydra.Data.FindOne(...) end,
        Update = function(...) return Hydra.Data.Update(...) end,
        Delete = function(...) return Hydra.Data.Delete(...) end,
        Find = function(...) return Hydra.Data.Find(...) end,
        FindOne = function(...) return Hydra.Data.FindOne(...) end,
        Count = function(...) return Hydra.Data.Count(...) end,

        -- Batch
        BulkCreate = function(...) return Hydra.Data.BulkCreate(...) end,
        BulkUpdate = function(...) return Hydra.Data.BulkUpdate(...) end,

        -- Collections
        CreateCollection = function(...) return Hydra.Data.Collections.Create(...) end,
        CollectionExists = function(...) return Hydra.Data.Collections.Exists(...) end,

        -- Cache
        CacheGet = function(...) return Hydra.Data.Cache.Get(...) end,
        CacheSet = function(...) return Hydra.Data.Cache.Set(...) end,
        CacheInvalidate = function(...) return Hydra.Data.Cache.Invalidate(...) end,

        -- Subscriptions
        Subscribe = function(...) return Hydra.Data.Subscriptions.Subscribe(...) end,
        Unsubscribe = function(...) return Hydra.Data.Subscriptions.Unsubscribe(...) end,
    },
})

-- Server exports
exports('Create', function(...) return Hydra.Data.Create(...) end)
exports('Read', function(...) return Hydra.Data.FindOne(...) end)
exports('Update', function(...) return Hydra.Data.Update(...) end)
exports('Delete', function(...) return Hydra.Data.Delete(...) end)
exports('Find', function(...) return Hydra.Data.Find(...) end)
exports('FindOne', function(...) return Hydra.Data.FindOne(...) end)
exports('Count', function(...) return Hydra.Data.Count(...) end)
exports('BulkCreate', function(...) return Hydra.Data.BulkCreate(...) end)
exports('BulkUpdate', function(...) return Hydra.Data.BulkUpdate(...) end)
exports('CacheGet', function(...) return Hydra.Data.Cache.Get(...) end)
exports('CacheSet', function(...) return Hydra.Data.Cache.Set(...) end)
exports('CacheInvalidate', function(...) return Hydra.Data.Cache.Invalidate(...) end)
exports('CreateCollection', function(...) return Hydra.Data.Collections.Create(...) end)
exports('CollectionExists', function(...) return Hydra.Data.Collections.Exists(...) end)
exports('Subscribe', function(...) return Hydra.Data.Subscriptions.Subscribe(...) end)
exports('Unsubscribe', function(...) return Hydra.Data.Subscriptions.Unsubscribe(...) end)

--- Handle player drop for subscription cleanup
AddEventHandler('playerDropped', function()
    local src = source
    Hydra.Data.Subscriptions.CleanupPlayer(src)
end)
