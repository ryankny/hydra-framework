--[[
    Hydra Status - Server

    Authoritative player needs system. Ticks down statuses over
    time, persists to player metadata, syncs to clients, and
    provides API for other scripts to modify statuses.
]]

Hydra = Hydra or {}
Hydra.Status = {}

local cfg = HydraStatusConfig
local playerStatuses = {} -- [source] = { hunger = 100, thirst = 100, stress = 0, ... }
local pendingSync = {}    -- [source] = true, debounce sync to next sync interval

-- =============================================
-- STATUS MANAGEMENT
-- =============================================

--- Initialize statuses for a player (load from metadata or use defaults)
--- @param src number
function Hydra.Status.Init(src)
    local saved = nil
    local ok, player = pcall(exports['hydra_players'].GetPlayer, exports['hydra_players'], src)
    if not ok then player = nil end
    if player and player.metadata and player.metadata[cfg.metadata_key] then
        saved = player.metadata[cfg.metadata_key]
    end

    local statuses = {}
    for name, def in pairs(cfg.statuses) do
        if saved and saved[name] ~= nil then
            statuses[name] = math.max(def.min, math.min(def.max, saved[name]))
        else
            statuses[name] = def.default
        end
    end

    playerStatuses[src] = statuses
    Hydra.Status.Sync(src, true)
end

--- Get all statuses for a player
--- @param src number
--- @return table|nil
function Hydra.Status.GetAll(src)
    return playerStatuses[src]
end

--- Get a specific status value
--- @param src number
--- @param name string
--- @return number|nil
function Hydra.Status.Get(src, name)
    local s = playerStatuses[src]
    if not s then return nil end
    return s[name]
end

--- Set a specific status value (clamped)
--- @param src number
--- @param name string
--- @param value number
function Hydra.Status.Set(src, name, value)
    local s = playerStatuses[src]
    if not s then return end

    local def = cfg.statuses[name]
    if not def then return end

    s[name] = math.max(def.min, math.min(def.max, value))
    Hydra.Status.Sync(src)
end

--- Add to a status (positive or negative)
--- @param src number
--- @param name string
--- @param amount number
function Hydra.Status.Add(src, name, amount)
    local current = Hydra.Status.Get(src, name)
    if current == nil then return end
    Hydra.Status.Set(src, name, current + amount)
end

--- Mark player for sync on next interval (debounced)
--- @param src number
--- @param immediate boolean|nil force immediate sync
function Hydra.Status.Sync(src, immediate)
    if immediate then
        local s = playerStatuses[src]
        if not s then return end
        TriggerClientEvent('hydra:status:sync', src, s)
        pendingSync[src] = nil
    else
        pendingSync[src] = true
    end
end

--- Save statuses to player metadata
--- @param src number
function Hydra.Status.Save(src)
    local s = playerStatuses[src]
    if not s then return end

    exports['hydra_players']:SetMetadata(src, cfg.metadata_key, s)
end

--- Cleanup on player drop
--- @param src number
function Hydra.Status.Cleanup(src)
    Hydra.Status.Save(src)
    playerStatuses[src] = nil
end

-- =============================================
-- TICK LOOP - Status decay/regen
-- =============================================

CreateThread(function()
    while true do
        Wait(cfg.tick_interval * 1000)

        for src, statuses in pairs(playerStatuses) do
            for name, value in pairs(statuses) do
                local def = cfg.statuses[name]
                if def and def.rate ~= 0 then
                    local newVal = value - def.rate
                    statuses[name] = math.max(def.min, math.min(def.max, newVal))
                end
            end

            -- Apply effects (health drain at 0 hunger/thirst)
            for name, value in pairs(statuses) do
                local def = cfg.statuses[name]
                if def and def.effects then
                    for _, effect in ipairs(def.effects) do
                        if effect.type == 'health_drain' and value <= effect.threshold then
                            TriggerClientEvent('hydra:status:effect', src, 'health_drain', effect.amount)
                        end
                    end
                end
            end
        end
    end
end)

-- Sync loop - flush pending syncs and periodic full sync
CreateThread(function()
    while true do
        Wait(cfg.sync_interval * 1000)
        for src in pairs(playerStatuses) do
            if pendingSync[src] then
                local s = playerStatuses[src]
                if s then
                    TriggerClientEvent('hydra:status:sync', src, s)
                end
                pendingSync[src] = nil
            end
        end
    end
end)

-- Save all periodically (piggyback on player auto-save interval)
CreateThread(function()
    while true do
        Wait(300000) -- 5 min
        for src in pairs(playerStatuses) do
            Hydra.Status.Save(src)
        end
    end
end)

-- =============================================
-- MODULE REGISTRATION
-- =============================================

Hydra.Modules.Register('status', {
    label = 'Hydra Status',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 70,
    dependencies = { 'players' },

    onLoad = function()
        Hydra.Utils.Log('info', 'Status module loaded')
    end,

    onPlayerJoin = function(src)
        -- Delay slightly to ensure player data is loaded
        CreateThread(function()
            Wait(2000)
            if exports['hydra_players']:GetPlayer(src) then
                Hydra.Status.Init(src)
            end
        end)
    end,

    onPlayerDrop = function(src)
        Hydra.Status.Cleanup(src)
    end,

    api = {
        Get = function(...) return Hydra.Status.Get(...) end,
        GetAll = function(...) return Hydra.Status.GetAll(...) end,
        Set = function(...) Hydra.Status.Set(...) end,
        Add = function(...) Hydra.Status.Add(...) end,
        Save = function(...) Hydra.Status.Save(...) end,
    },
})

-- Server event for client-reported status changes (e.g. stress from shooting)
local clientAddCooldown = {} -- [source] = { [name] = lastTime }
RegisterNetEvent('hydra:status:clientAdd')
AddEventHandler('hydra:status:clientAdd', function(name, amount)
    local src = source
    if not src or src <= 0 then return end

    -- Security: validate input
    if type(name) ~= 'string' or #name > 32 or type(amount) ~= 'number' then return end
    if not cfg.statuses[name] then return end

    -- Rate limit: max one client-add per status per 500ms
    local now = GetGameTimer()
    if not clientAddCooldown[src] then clientAddCooldown[src] = {} end
    if clientAddCooldown[src][name] and now - clientAddCooldown[src][name] < 500 then return end
    clientAddCooldown[src][name] = now

    -- Cap client-reported additions to prevent exploits
    local maxAdd = 5.0
    amount = math.max(-maxAdd, math.min(maxAdd, amount))

    Hydra.Status.Add(src, name, amount)
end)

-- Cleanup cooldown tracking on player drop
AddEventHandler('playerDropped', function()
    clientAddCooldown[source] = nil
end)

exports('GetStatus', function(...) return Hydra.Status.Get(...) end)
exports('GetAllStatuses', function(...) return Hydra.Status.GetAll(...) end)
exports('SetStatus', function(...) Hydra.Status.Set(...) end)
exports('AddStatus', function(...) Hydra.Status.Add(...) end)
