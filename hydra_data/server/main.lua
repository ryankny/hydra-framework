--[[
    Hydra Data - Server Main

    Initializes the data layer and registers it as a Hydra module.
]]

Hydra = Hydra or {}
Hydra.Data = Hydra.Data or {}

--- Register as Hydra module (metadata only)
Hydra.Modules.Register('data', {
    label = 'Hydra Data Layer',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 90,
})

--- Initialize data layer immediately (no need to wait for framework ready — data IS the foundation)
CreateThread(function()
    Wait(100) -- brief wait for oxmysql to be ready

    local config = {
        adapter = 'mysql',
        cache = { enabled = true, default_ttl = 300, max_entries = 10000 },
        auto_migrate = true,
    }

    if Hydra.Data.Cache and Hydra.Data.Cache.Init then
        Hydra.Data.Cache.Init(config.cache)
    end

    Hydra.Utils.Log('info', 'Data layer initialized (adapter=%s, cache=on)', config.adapter)
end)

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
