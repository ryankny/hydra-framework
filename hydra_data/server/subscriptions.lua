--[[
    Hydra Data - Real-Time Subscriptions

    Kuzzle-like pub/sub system for data changes.
    Modules and clients can subscribe to collection changes
    and receive real-time notifications.
]]

Hydra = Hydra or {}
Hydra.Data = Hydra.Data or {}
Hydra.Data.Subscriptions = Hydra.Data.Subscriptions or {}

-- { [collection] = { [subId] = { handler, filter, source } } }
local subscriptions = {}
local subCounter = 0

-- Per-player subscription tracking for cleanup
local playerSubs = {} -- { [source] = { subId1, subId2, ... } }

--- Subscribe to changes on a collection
--- @param collection string
--- @param filter table|nil only notify if change matches filter
--- @param handler function(action, data) called on changes
--- @param source number|nil player source (for auto-cleanup)
--- @return string subscriptionId
function Hydra.Data.Subscriptions.Subscribe(collection, filter, handler, source)
    subCounter = subCounter + 1
    local subId = 'sub_' .. subCounter

    if not subscriptions[collection] then
        subscriptions[collection] = {}
    end

    subscriptions[collection][subId] = {
        handler = handler,
        filter = filter,
        source = source,
    }

    -- Track player subscriptions for cleanup
    if source then
        if not playerSubs[source] then
            playerSubs[source] = {}
        end
        playerSubs[source][#playerSubs[source] + 1] = { collection = collection, subId = subId }
    end

    Hydra.Utils.Log('debug', 'Subscription created: %s on %s', subId, collection)
    return subId
end

--- Unsubscribe
--- @param collection string
--- @param subId string
function Hydra.Data.Subscriptions.Unsubscribe(collection, subId)
    if subscriptions[collection] then
        subscriptions[collection][subId] = nil
    end
end

--- Notify all subscribers of a collection change
--- @param collection string
--- @param action string 'create'|'update'|'delete'
--- @param payload table { filter, data, id }
function Hydra.Data.Subscriptions.Notify(collection, action, payload)
    local subs = subscriptions[collection]
    if not subs then return end

    for subId, sub in pairs(subs) do
        -- Check if subscription filter matches the change
        local matches = true
        if sub.filter and payload.filter then
            for k, v in pairs(sub.filter) do
                if payload.filter[k] ~= v and (not payload.data or payload.data[k] ~= v) then
                    matches = false
                    break
                end
            end
        end

        if matches then
            local ok, err = pcall(sub.handler, action, payload)
            if not ok then
                Hydra.Utils.Log('error', 'Subscription handler error [%s]: %s', subId, tostring(err))
            end
        end
    end
end

--- Clean up all subscriptions for a player
--- @param source number
function Hydra.Data.Subscriptions.CleanupPlayer(source)
    local subs = playerSubs[source]
    if not subs then return end

    for _, sub in ipairs(subs) do
        if subscriptions[sub.collection] then
            subscriptions[sub.collection][sub.subId] = nil
        end
    end

    playerSubs[source] = nil
end

--- Get subscription count for a collection
--- @param collection string|nil nil for total
--- @return number
function Hydra.Data.Subscriptions.Count(collection)
    if collection then
        return subscriptions[collection] and Hydra.Utils.Keys(subscriptions[collection]) and #Hydra.Utils.Keys(subscriptions[collection]) or 0
    end
    local total = 0
    for _, subs in pairs(subscriptions) do
        for _ in pairs(subs) do
            total = total + 1
        end
    end
    return total
end
