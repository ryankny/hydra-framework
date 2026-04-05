--[[
    Hydra Blips - Server

    Server-authoritative blip registry. Blips can be created from
    server and synced to all clients. Supports categories for
    bulk visibility toggling, and auto-cleanup on resource stop.
]]

Hydra = Hydra or {}
Hydra.Blips = Hydra.Blips or {}

local cfg = HydraBlipsConfig
local blips = {}
local nextId = 1

--- Create a blip (synced to all clients)
--- @param data table
---   coords   vector3       - Position
---   label    string        - Blip label
---   sprite   number|nil    - Blip sprite ID
---   color    number|nil    - Blip color ID
---   scale    number|nil    - Blip scale
---   category string|nil    - Category key
---   short_range bool|nil   - Short range display
---   display  number|nil    - Display mode (2=both, 4=map only)
---   resource string|nil    - Owning resource (auto-cleanup)
--- @return number blipId
function Hydra.Blips.Create(data)
    local id = nextId
    nextId = nextId + 1

    local defaults = cfg.defaults
    blips[id] = {
        id = id,
        coords = data.coords,
        label = data.label or 'Blip',
        sprite = data.sprite or defaults.sprite,
        color = data.color or defaults.color,
        scale = data.scale or defaults.scale,
        category = data.category or 'custom',
        short_range = data.short_range ~= nil and data.short_range or defaults.short_range,
        display = data.display or defaults.display,
        resource = data.resource or GetInvokingResource() or 'hydra_blips',
    }

    TriggerClientEvent('hydra:blips:create', -1, blips[id])
    return id
end

--- Update a blip
--- @param id number
--- @param data table (partial fields to update)
function Hydra.Blips.Update(id, data)
    local blip = blips[id]
    if not blip then return end

    for k, v in pairs(data) do
        blip[k] = v
    end

    TriggerClientEvent('hydra:blips:update', -1, id, data)
end

--- Remove a blip
--- @param id number
function Hydra.Blips.Remove(id)
    if not blips[id] then return end
    blips[id] = nil
    TriggerClientEvent('hydra:blips:remove', -1, id)
end

--- Remove all blips from a specific resource
--- @param resourceName string
function Hydra.Blips.RemoveByResource(resourceName)
    local toRemove = {}
    for id, blip in pairs(blips) do
        if blip.resource == resourceName then
            toRemove[#toRemove + 1] = id
        end
    end
    for _, id in ipairs(toRemove) do
        Hydra.Blips.Remove(id)
    end
end

--- Remove all blips in a category
--- @param category string
function Hydra.Blips.RemoveByCategory(category)
    local toRemove = {}
    for id, blip in pairs(blips) do
        if blip.category == category then
            toRemove[#toRemove + 1] = id
        end
    end
    for _, id in ipairs(toRemove) do
        Hydra.Blips.Remove(id)
    end
end

--- Get all blips
function Hydra.Blips.GetAll()
    return blips
end

-- Auto-cleanup when a resource stops
AddEventHandler('onResourceStop', function(resourceName)
    Hydra.Blips.RemoveByResource(resourceName)
end)

-- Sync blips to joining player
RegisterNetEvent('hydra:blips:requestSync')
AddEventHandler('hydra:blips:requestSync', function()
    local src = source
    for _, blip in pairs(blips) do
        TriggerClientEvent('hydra:blips:create', src, blip)
    end
end)

--- Module registration
Hydra.Modules.Register('blips', {
    label = 'Hydra Blips',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 45,
    dependencies = {},

    onLoad = function()
        Hydra.Utils.Log('info', 'Blips module loaded')
    end,

    onPlayerJoin = function(src)
        for _, blip in pairs(blips) do
            TriggerClientEvent('hydra:blips:create', src, blip)
        end
    end,

    api = {
        Create = function(...) return Hydra.Blips.Create(...) end,
        Update = function(...) Hydra.Blips.Update(...) end,
        Remove = function(...) Hydra.Blips.Remove(...) end,
        RemoveByResource = function(...) Hydra.Blips.RemoveByResource(...) end,
        RemoveByCategory = function(...) Hydra.Blips.RemoveByCategory(...) end,
        GetAll = function() return Hydra.Blips.GetAll() end,
    },
})

exports('CreateBlip', function(...) return Hydra.Blips.Create(...) end)
exports('UpdateBlip', function(...) Hydra.Blips.Update(...) end)
exports('RemoveBlip', function(...) Hydra.Blips.Remove(...) end)
exports('RemoveBlipsByResource', function(...) Hydra.Blips.RemoveByResource(...) end)
exports('RemoveBlipsByCategory', function(...) Hydra.Blips.RemoveByCategory(...) end)
