--[[
    Hydra Blips - Client

    Creates and manages GTA blips from server-synced data.
    Supports client-only blips, category toggling, and auto-cleanup.
]]

Hydra = Hydra or {}
Hydra.Blips = Hydra.Blips or {}

local cfg = HydraBlipsConfig

-- blipId -> { nativeHandle, data }
local activeBlips = {}
local localNextId = 100000
local categoryVisibility = {}

-- Initialize category visibility from config
for cat, def in pairs(cfg.categories) do
    categoryVisibility[cat] = def.visible
end

-- =============================================
-- BLIP CREATION / MANAGEMENT
-- =============================================

--- Create a native blip from data
--- @param data table
--- @return number nativeHandle
local function createNativeBlip(data)
    local coords = data.coords
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, data.sprite or cfg.defaults.sprite)
    SetBlipColour(blip, data.color or cfg.defaults.color)
    SetBlipScale(blip, data.scale or cfg.defaults.scale)
    SetBlipDisplay(blip, data.display or cfg.defaults.display)
    SetBlipAsShortRange(blip, data.short_range ~= false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(data.label or 'Blip')
    EndTextCommandSetBlipName(blip)

    -- Hide if category is toggled off
    local cat = data.category or 'custom'
    if categoryVisibility[cat] == false then
        SetBlipAlpha(blip, 0)
    end

    return blip
end

--- Create a client-only blip (not synced to server)
--- @param data table
--- @return number blipId
function Hydra.Blips.CreateLocal(data)
    local id = localNextId
    localNextId = localNextId + 1

    local handle = createNativeBlip(data)
    activeBlips[id] = { handle = handle, data = data }
    return id
end

--- Remove a blip (local or synced)
--- @param id number blipId
function Hydra.Blips.RemoveLocal(id)
    local entry = activeBlips[id]
    if entry then
        if DoesBlipExist(entry.handle) then
            RemoveBlip(entry.handle)
        end
        activeBlips[id] = nil
    end
end

--- Toggle category visibility
--- @param category string
--- @param visible boolean
function Hydra.Blips.SetCategoryVisible(category, visible)
    categoryVisibility[category] = visible

    for _, entry in pairs(activeBlips) do
        if entry.data.category == category and DoesBlipExist(entry.handle) then
            SetBlipAlpha(entry.handle, visible and 255 or 0)
        end
    end
end

--- Check if category is visible
--- @param category string
--- @return boolean
function Hydra.Blips.IsCategoryVisible(category)
    return categoryVisibility[category] ~= false
end

-- =============================================
-- SERVER SYNC
-- =============================================

RegisterNetEvent('hydra:blips:create')
AddEventHandler('hydra:blips:create', function(data)
    -- Remove existing if re-syncing
    if activeBlips[data.id] then
        Hydra.Blips.RemoveLocal(data.id)
    end

    local handle = createNativeBlip(data)
    activeBlips[data.id] = { handle = handle, data = data }
end)

RegisterNetEvent('hydra:blips:update')
AddEventHandler('hydra:blips:update', function(id, updates)
    local entry = activeBlips[id]
    if not entry then return end

    -- Update stored data
    for k, v in pairs(updates) do
        entry.data[k] = v
    end

    local blip = entry.handle
    if not DoesBlipExist(blip) then return end

    -- Re-apply changed properties
    if updates.coords then
        SetBlipCoords(blip, updates.coords.x, updates.coords.y, updates.coords.z)
    end
    if updates.sprite then SetBlipSprite(blip, updates.sprite) end
    if updates.color then SetBlipColour(blip, updates.color) end
    if updates.scale then SetBlipScale(blip, updates.scale) end
    if updates.short_range ~= nil then SetBlipAsShortRange(blip, updates.short_range) end
    if updates.label then
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(updates.label)
        EndTextCommandSetBlipName(blip)
    end
end)

RegisterNetEvent('hydra:blips:remove')
AddEventHandler('hydra:blips:remove', function(id)
    Hydra.Blips.RemoveLocal(id)
end)

-- Request sync on resource start
CreateThread(function()
    Wait(500)
    TriggerServerEvent('hydra:blips:requestSync')
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for id, entry in pairs(activeBlips) do
            if DoesBlipExist(entry.handle) then
                RemoveBlip(entry.handle)
            end
        end
        activeBlips = {}
    end
end)

-- =============================================
-- EXPORTS
-- =============================================

exports('CreateLocalBlip', function(...) return Hydra.Blips.CreateLocal(...) end)
exports('RemoveLocalBlip', function(...) Hydra.Blips.RemoveLocal(...) end)
exports('SetCategoryVisible', function(...) Hydra.Blips.SetCategoryVisible(...) end)
exports('IsCategoryVisible', function(...) return Hydra.Blips.IsCategoryVisible(...) end)
