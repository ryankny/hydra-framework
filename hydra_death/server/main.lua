--[[
    Hydra Death - Server

    Manages death state, respawn authorization, EMS revives,
    and hospital costs. Server is authoritative on death state.
]]

Hydra = Hydra or {}
Hydra.Death = {}

local cfg = HydraDeathConfig

-- Player death state: [source] = { isDead = bool, deathTime = number }
local deathState = {}

--- Mark player as dead
--- @param src number
function Hydra.Death.SetDead(src)
    deathState[src] = {
        isDead = true,
        deathTime = os.time(),
    }
    TriggerEvent('hydra:death:playerDied', src)
end

--- Check if player is dead
--- @param src number
--- @return boolean
function Hydra.Death.IsDead(src)
    local state = deathState[src]
    return state ~= nil and state.isDead
end

--- Revive a player
--- @param src number
--- @param coords vector3|nil (optional override position)
function Hydra.Death.Revive(src, coords)
    if not Hydra.Death.IsDead(src) then return end

    deathState[src] = nil
    TriggerClientEvent('hydra:death:revive', src, coords)
    TriggerEvent('hydra:death:playerRevived', src)

    Hydra.Utils.Log('info', 'Player %d revived', src)
end

--- Respawn player at hospital
--- @param src number
function Hydra.Death.Respawn(src)
    if not Hydra.Death.IsDead(src) then return end

    -- Deduct respawn cost
    if cfg.respawn_cost > 0 and Hydra.Players then
        local current = Hydra.Players.GetMoney(src, cfg.respawn_cost_account)
        if current and current >= cfg.respawn_cost then
            Hydra.Players.RemoveMoney(src, cfg.respawn_cost_account, cfg.respawn_cost)
        end
    end

    -- Pick random hospital
    local hospital = cfg.hospitals[math.random(#cfg.hospitals)]

    deathState[src] = nil
    TriggerClientEvent('hydra:death:respawn', src, {
        coords = hospital.coords,
        heading = hospital.heading,
        label = hospital.label,
        healOnRespawn = cfg.effects.heal_on_respawn,
        removeWeapons = cfg.effects.remove_weapons,
    })
    TriggerEvent('hydra:death:playerRespawned', src)

    Hydra.Utils.Log('info', 'Player %d respawned at %s', src, hospital.label)
end

-- =============================================
-- EVENTS
-- =============================================

--- Client reports death
RegisterNetEvent('hydra:death:died')
AddEventHandler('hydra:death:died', function()
    local src = source
    if not Hydra.Death.IsDead(src) then
        Hydra.Death.SetDead(src)
    end
end)

--- Client requests respawn (after timer)
RegisterNetEvent('hydra:death:requestRespawn')
AddEventHandler('hydra:death:requestRespawn', function()
    local src = source
    local state = deathState[src]
    if not state or not state.isDead then return end

    -- Validate minimum time has passed (anti-exploit)
    local elapsed = os.time() - state.deathTime
    local minTime = cfg.last_stand_duration + cfg.respawn_timer - 5 -- 5s grace
    if elapsed < minTime then return end

    Hydra.Death.Respawn(src)
end)

--- EMS revive event (from another player)
RegisterNetEvent('hydra:death:emsRevive')
AddEventHandler('hydra:death:emsRevive', function(targetId)
    local src = source
    if not cfg.allow_revive then return end

    local targetSrc = tonumber(targetId)
    if not targetSrc or not Hydra.Death.IsDead(targetSrc) then return end

    -- Verify source is EMS
    local player = Hydra.Players and Hydra.Players.GetPlayer(src)
    if not player or not player.job then return end

    local isEms = false
    for _, jobName in ipairs(cfg.ems_jobs) do
        if player.job.name == jobName then
            isEms = true
            break
        end
    end

    if not isEms then return end

    -- Verify proximity
    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetSrc)
    if srcPed == 0 or targetPed == 0 then return end

    local dist = #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed))
    if dist > 5.0 then return end

    Hydra.Death.Revive(targetSrc)
    Hydra.Utils.Log('info', 'Player %d revived by EMS player %d', targetSrc, src)
end)

-- =============================================
-- ADMIN REVIVE COMMAND
-- =============================================

RegisterCommand(cfg.revive_command, function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, cfg.revive_permission) then
        TriggerClientEvent('hydra:notify:show', src, {
            type = 'error', title = 'No Permission',
            message = 'You do not have permission to revive.',
        })
        return
    end

    local targetSrc = tonumber(args[1])
    if not targetSrc then
        -- Self-revive for admins, or revive nearest if from console
        if src > 0 then
            targetSrc = src
        else
            print('[Hydra Death] Usage: /' .. cfg.revive_command .. ' [player_id]')
            return
        end
    end

    if Hydra.Death.IsDead(targetSrc) then
        Hydra.Death.Revive(targetSrc)
        local name = src > 0 and GetPlayerName(src) or 'Console'
        Hydra.Utils.Log('info', '%s admin-revived player %d', name, targetSrc)

        if src > 0 then
            TriggerClientEvent('hydra:notify:show', src, {
                type = 'success', title = 'Revive',
                message = ('Revived player %d'):format(targetSrc),
            })
        end
    else
        local msg = ('Player %d is not dead'):format(targetSrc)
        if src > 0 then
            TriggerClientEvent('hydra:notify:show', src, { type = 'info', title = 'Revive', message = msg })
        else
            print('[Hydra Death] ' .. msg)
        end
    end
end, false)

-- =============================================
-- MODULE REGISTRATION
-- =============================================

Hydra.Modules.Register('death', {
    label = 'Hydra Death',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 65,
    dependencies = { 'players' },

    onLoad = function()
        Hydra.Utils.Log('info', 'Death module loaded')
    end,

    onPlayerDrop = function(src)
        deathState[src] = nil
    end,

    api = {
        IsDead = function(...) return Hydra.Death.IsDead(...) end,
        Revive = function(...) Hydra.Death.Revive(...) end,
        Respawn = function(...) Hydra.Death.Respawn(...) end,
        SetDead = function(...) Hydra.Death.SetDead(...) end,
    },
})

exports('IsDead', function(...) return Hydra.Death.IsDead(...) end)
exports('Revive', function(...) Hydra.Death.Revive(...) end)
exports('Respawn', function(...) Hydra.Death.Respawn(...) end)
