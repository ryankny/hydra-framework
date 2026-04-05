--[[
    Hydra Data - Shared Store

    Reactive key-value store that syncs between server and client.
    Server sets values, client receives updates automatically.
    Like a simplified state management system.
]]

Hydra = Hydra or {}
Hydra.Data = Hydra.Data or {}
Hydra.Data.Store = Hydra.Data.Store or {}

local stores = {}       -- { [storeName] = { [key] = value } }
local watchers = {}     -- { [storeName] = { [key] = { callback1, callback2 } } }
local isServer = IsDuplicityVersion()

--- Get a store value
--- @param storeName string
--- @param key string
--- @param default any
--- @return any
function Hydra.Data.Store.Get(storeName, key, default)
    if not stores[storeName] then return default end
    local value = stores[storeName][key]
    return value ~= nil and value or default
end

--- Get entire store
--- @param storeName string
--- @return table
function Hydra.Data.Store.GetAll(storeName)
    return stores[storeName] or {}
end

--- Set a store value (triggers watchers and sync)
--- @param storeName string
--- @param key string
--- @param value any
function Hydra.Data.Store.Set(storeName, key, value)
    if not stores[storeName] then
        stores[storeName] = {}
    end

    local oldValue = stores[storeName][key]
    stores[storeName][key] = value

    -- Trigger watchers
    if watchers[storeName] and watchers[storeName][key] then
        for _, cb in ipairs(watchers[storeName][key]) do
            pcall(cb, value, oldValue, key)
        end
    end
end

--- Watch a store key for changes
--- @param storeName string
--- @param key string
--- @param callback function(newValue, oldValue, key)
--- @return function unwatch
function Hydra.Data.Store.Watch(storeName, key, callback)
    if not watchers[storeName] then
        watchers[storeName] = {}
    end
    if not watchers[storeName][key] then
        watchers[storeName][key] = {}
    end

    local watchList = watchers[storeName][key]
    watchList[#watchList + 1] = callback

    -- Return unwatch function
    return function()
        for i, cb in ipairs(watchList) do
            if cb == callback then
                table.remove(watchList, i)
                break
            end
        end
    end
end

--- Set multiple values at once
--- @param storeName string
--- @param data table { key = value }
function Hydra.Data.Store.SetBulk(storeName, data)
    for key, value in pairs(data) do
        Hydra.Data.Store.Set(storeName, key, value)
    end
end

--- Delete a store
--- @param storeName string
function Hydra.Data.Store.Delete(storeName)
    stores[storeName] = nil
    watchers[storeName] = nil
end
