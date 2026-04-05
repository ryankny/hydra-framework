--[[
    Hydra Death - Client

    Detects player death, manages last-stand state, renders
    respawn UI, disables controls, and handles respawn/revive.
]]

Hydra = Hydra or {}
Hydra.Death = {}

local cfg = HydraDeathConfig

-- State
local isDead = false
local lastStandStart = 0
local lastStandExpired = false
local respawnCountdown = 0
local respawnHoldTime = 0

-- =============================================
-- DEATH DETECTION
-- =============================================

CreateThread(function()
    while true do
        Wait(500)

        local ped = PlayerPedId()

        if not isDead and IsEntityDead(ped) then
            isDead = true
            lastStandStart = GetGameTimer()
            lastStandExpired = false
            respawnCountdown = cfg.respawn_timer
            respawnHoldTime = 0

            -- Notify server
            TriggerServerEvent('hydra:death:died')

            -- Trigger local event
            TriggerEvent('hydra:death:onDeath')

            -- Notify
            TriggerEvent('hydra:notify:show', {
                type = 'error',
                title = 'You are down',
                message = 'Wait for EMS or hold E to respawn',
                duration = 5000,
            })
        end
    end
end)

-- =============================================
-- LAST STAND / RESPAWN LOOP
-- =============================================

CreateThread(function()
    while true do
        if isDead then
            Wait(0)

            local ped = PlayerPedId()

            -- Disable controls
            if cfg.disable_while_dead.movement then
                DisableControlAction(0, 30, true)
                DisableControlAction(0, 31, true)
                DisableControlAction(0, 21, true)
            end
            if cfg.disable_while_dead.combat then
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 47, true)
                DisableControlAction(0, 58, true)
            end
            if cfg.disable_while_dead.vehicle_entry then
                DisableControlAction(0, 23, true)
                DisableControlAction(0, 75, true)
            end

            -- Calculate timers
            local elapsed = (GetGameTimer() - lastStandStart) / 1000.0
            local lastStandRemaining = cfg.last_stand_duration - elapsed

            -- Last stand phase
            if lastStandRemaining > 0 and not lastStandExpired then
                -- Show last stand timer
                drawDeathUI(('Wait for EMS - %d:%02d'):format(
                    math.floor(lastStandRemaining / 60),
                    math.floor(lastStandRemaining % 60)
                ))
            else
                -- Last stand expired, show respawn prompt
                if not lastStandExpired then
                    lastStandExpired = true
                    respawnCountdown = cfg.respawn_timer
                end

                if respawnCountdown > 0 then
                    respawnCountdown = respawnCountdown - GetFrameTime()
                    drawDeathUI(('Respawn available in %d...'):format(math.ceil(respawnCountdown)))
                else
                    -- Can hold E to respawn
                    drawDeathUI('Hold [E] to respawn at hospital')

                    if IsControlPressed(0, 38) then -- E key
                        respawnHoldTime = respawnHoldTime + GetFrameTime()

                        -- Draw hold progress
                        local progress = math.min(respawnHoldTime / 2.0, 1.0) -- 2 second hold
                        drawProgressBar(progress)

                        if respawnHoldTime >= 2.0 then
                            TriggerServerEvent('hydra:death:requestRespawn')
                            respawnHoldTime = 0
                        end
                    else
                        respawnHoldTime = 0
                    end
                end
            end
        else
            Wait(500)
        end
    end
end)

-- =============================================
-- REVIVE (from EMS or admin)
-- =============================================

RegisterNetEvent('hydra:death:revive')
AddEventHandler('hydra:death:revive', function(coords)
    if not isDead then return end
    isDead = false

    local ped = PlayerPedId()

    -- Resurrect
    NetworkResurrectLocalPlayer(
        coords and coords.x or GetEntityCoords(ped).x,
        coords and coords.y or GetEntityCoords(ped).y,
        coords and coords.z or GetEntityCoords(ped).z,
        coords and coords.heading or GetEntityHeading(ped),
        true, false
    )

    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ClearPedTasks(ped)

    TriggerEvent('hydra:death:onRevive')

    TriggerEvent('hydra:notify:show', {
        type = 'success', title = 'Revived',
        message = 'You have been revived.',
        duration = 3000,
    })
end)

-- =============================================
-- RESPAWN (at hospital)
-- =============================================

RegisterNetEvent('hydra:death:respawn')
AddEventHandler('hydra:death:respawn', function(data)
    if not isDead then return end
    isDead = false

    local coords = data.coords

    -- Screen fade (use hydra_camera if available, fallback to native)
    if cfg.effects.screen_fade then
        local camOk = pcall(function()
            exports['hydra_camera']:FadeOut(500)
        end)
        if not camOk then
            DoScreenFadeOut(500)
        end
        Wait(600)
    end

    local ped = PlayerPedId()

    -- Resurrect at hospital
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, data.heading or 0.0, true, false)
    ped = PlayerPedId()

    -- Wait for collision
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local t = 0
    while not HasCollisionLoadedAroundEntity(ped) and t < 3000 do
        Wait(10)
        t = t + 10
    end

    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, data.heading or 0.0)

    -- Heal
    if data.healOnRespawn then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        SetPedArmour(ped, 0)
    end

    -- Remove weapons
    if data.removeWeapons then
        RemoveAllPedWeapons(ped, true)
    end

    ClearPedBloodDamage(ped)
    ClearPedTasks(ped)

    if cfg.effects.screen_fade then
        local camOk = pcall(function()
            exports['hydra_camera']:FadeIn(1000)
        end)
        if not camOk then
            DoScreenFadeIn(1000)
        end
    end

    TriggerEvent('hydra:death:onRespawn')

    TriggerEvent('hydra:notify:show', {
        type = 'info', title = 'Hospital',
        message = ('Respawned at %s'):format(data.label or 'Hospital'),
        duration = 5000,
    })
end)

-- =============================================
-- UI DRAWING (minimal, no NUI needed)
-- =============================================

--- Draw death UI text at top of screen
--- @param text string
function drawDeathUI(text)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.0, 0.4)
    SetTextColour(255, 255, 255, 200)
    SetTextDropshadow(1, 0, 0, 0, 200)
    SetTextEdge(1, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(0.5, 0.85)
end

--- Draw respawn hold progress bar
--- @param progress number 0.0-1.0
function drawProgressBar(progress)
    local x, y = 0.5, 0.9
    local w, h = 0.12, 0.012

    -- Background
    DrawRect(x, y, w, h, 0, 0, 0, 150)
    -- Fill
    local fillW = w * progress
    local fillX = x - (w / 2) + (fillW / 2)
    DrawRect(fillX, y, fillW, h, 108, 92, 231, 220)
end

-- =============================================
-- CLIENT API
-- =============================================

function Hydra.Death.IsDead()
    return isDead
end

function Hydra.Death.IsLastStandExpired()
    return lastStandExpired
end

exports('IsDead', function() return isDead end)
exports('IsLastStandExpired', function() return lastStandExpired end)
