--[[
    Hydra Data - Client Store

    Receives store updates from server and maintains local state.
    Scripts can watch for changes reactively.
]]

Hydra = Hydra or {}

--- Listen for store sync from server
RegisterNetEvent('hydra:store:sync')
AddEventHandler('hydra:store:sync', function(storeName, key, value)
    Hydra.Data.Store.Set(storeName, key, value)
end)

--- Listen for bulk store sync
RegisterNetEvent('hydra:store:syncBulk')
AddEventHandler('hydra:store:syncBulk', function(storeName, data)
    Hydra.Data.Store.SetBulk(storeName, data)
end)

--- Listen for store delete
RegisterNetEvent('hydra:store:delete')
AddEventHandler('hydra:store:delete', function(storeName)
    Hydra.Data.Store.Delete(storeName)
end)

-- Client exports
exports('GetStore', function(storeName) return Hydra.Data.Store.GetAll(storeName) end)
exports('GetStoreValue', function(storeName, key, default) return Hydra.Data.Store.Get(storeName, key, default) end)
