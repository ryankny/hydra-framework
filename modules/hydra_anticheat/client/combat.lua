--[[
    Hydra AntiCheat - Client Combat Monitoring

    Client-side combat telemetry threads: kill tracking, aim snap detection,
    recoil sampling, ammo monitoring, reload detection, weapon inventory
    scanning, and damage dealt reporting.

    The client NEVER makes enforcement decisions — it only reports data to the
    server via TriggerServerEvent. All validation and punishment logic lives in
    server/combat.lua.
]]

local cfg = HydraConfig.AntiCheat

-- ---------------------------------------------------------------------------
-- Localise natives for performance
-- ---------------------------------------------------------------------------
local GetGameTimer          = GetGameTimer
local PlayerPedId           = PlayerPedId
local PlayerId              = PlayerId
local GetEntityCoords       = GetEntityCoords
local DoesEntityExist       = DoesEntityExist
local IsPedShooting         = IsPedShooting
local IsPedReloading        = IsPedReloading
local IsPedDeadOrDying      = IsPedDeadOrDying
local GetSelectedPedWeapon  = GetSelectedPedWeapon
local GetAmmoInPedWeapon    = GetAmmoInPedWeapon
local GetGameplayCamRot     = GetGameplayCamRot
local GetEntityBoneIndexByName = GetEntityBoneIndexByName
local GetPedLastDamageBone  = GetPedLastDamageBone
local HasPedGotWeapon       = HasPedGotWeapon
local GetWeapontypeGroup    = GetWeapontypeGroup
local NetworkIsPlayerActive = NetworkIsPlayerActive
local NetworkGetEntityOwner = NetworkGetEntityOwner
local TriggerServerEvent    = TriggerServerEvent
local Wait                  = Wait

local math_abs  = math.abs
local math_sqrt = math.sqrt

-- ---------------------------------------------------------------------------
-- Weapon group hashes used for inventory scanning
-- ---------------------------------------------------------------------------
local WEAPON_GROUPS = {
    -- Melee
    `WEAPON_DAGGER`, `WEAPON_BAT`, `WEAPON_BOTTLE`, `WEAPON_CROWBAR`,
    `WEAPON_FLASHLIGHT`, `WEAPON_GOLFCLUB`, `WEAPON_HAMMER`, `WEAPON_HATCHET`,
    `WEAPON_KNUCKLE`, `WEAPON_KNIFE`, `WEAPON_MACHETE`, `WEAPON_SWITCHBLADE`,
    `WEAPON_NIGHTSTICK`, `WEAPON_WRENCH`, `WEAPON_BATTLEAXE`, `WEAPON_POOLCUE`,
    `WEAPON_STONE_HATCHET`,
    -- Handguns
    `WEAPON_PISTOL`, `WEAPON_PISTOL_MK2`, `WEAPON_COMBATPISTOL`,
    `WEAPON_APPISTOL`, `WEAPON_STUNGUN`, `WEAPON_PISTOL50`, `WEAPON_SNSPISTOL`,
    `WEAPON_SNSPISTOL_MK2`, `WEAPON_HEAVYPISTOL`, `WEAPON_VINTAGEPISTOL`,
    `WEAPON_FLAREGUN`, `WEAPON_MARKSMANPISTOL`, `WEAPON_REVOLVER`,
    `WEAPON_REVOLVER_MK2`, `WEAPON_DOUBLEACTION`, `WEAPON_RAYPISTOL`,
    `WEAPON_CERAMICPISTOL`, `WEAPON_NAVYREVOLVER`, `WEAPON_GADGETPISTOL`,
    -- SMGs
    `WEAPON_MICROSMG`, `WEAPON_SMG`, `WEAPON_SMG_MK2`, `WEAPON_ASSAULTSMG`,
    `WEAPON_COMBATPDW`, `WEAPON_MACHINEPISTOL`, `WEAPON_MINISMG`,
    `WEAPON_RAYCARBINE`,
    -- Shotguns
    `WEAPON_PUMPSHOTGUN`, `WEAPON_PUMPSHOTGUN_MK2`, `WEAPON_SAWNOFFSHOTGUN`,
    `WEAPON_ASSAULTSHOTGUN`, `WEAPON_BULLPUPSHOTGUN`, `WEAPON_MUSKET`,
    `WEAPON_HEAVYSHOTGUN`, `WEAPON_DBSHOTGUN`, `WEAPON_AUTOSHOTGUN`,
    `WEAPON_COMBATSHOTGUN`,
    -- Assault rifles
    `WEAPON_ASSAULTRIFLE`, `WEAPON_ASSAULTRIFLE_MK2`, `WEAPON_CARBINERIFLE`,
    `WEAPON_CARBINERIFLE_MK2`, `WEAPON_ADVANCEDRIFLE`, `WEAPON_SPECIALCARBINE`,
    `WEAPON_SPECIALCARBINE_MK2`, `WEAPON_BULLPUPRIFLE`, `WEAPON_BULLPUPRIFLE_MK2`,
    `WEAPON_COMPACTRIFLE`, `WEAPON_MILITARYRIFLE`, `WEAPON_HEAVYRIFLE`,
    -- LMGs
    `WEAPON_MG`, `WEAPON_COMBATMG`, `WEAPON_COMBATMG_MK2`, `WEAPON_GUSENBERG`,
    -- Sniper rifles
    `WEAPON_SNIPERRIFLE`, `WEAPON_HEAVYSNIPER`, `WEAPON_HEAVYSNIPER_MK2`,
    `WEAPON_MARKSMANRIFLE`, `WEAPON_MARKSMANRIFLE_MK2`,
    -- Heavy weapons
    `WEAPON_RPG`, `WEAPON_GRENADELAUNCHER`, `WEAPON_GRENADELAUNCHER_SMOKE`,
    `WEAPON_MINIGUN`, `WEAPON_FIREWORK`, `WEAPON_RAILGUN`, `WEAPON_HOMINGLAUNCHER`,
    `WEAPON_COMPACTLAUNCHER`, `WEAPON_RAYMINIGUN`, `WEAPON_EMPLAUNCHER`,
    -- Throwables
    `WEAPON_GRENADE`, `WEAPON_BZGAS`, `WEAPON_MOLOTOV`, `WEAPON_STICKYBOMB`,
    `WEAPON_PROXMINE`, `WEAPON_SNOWBALL`, `WEAPON_PIPEBOMB`, `WEAPON_BALL`,
    `WEAPON_SMOKEGRENADE`, `WEAPON_FLARE`,
    -- Misc
    `WEAPON_PETROLCAN`, `WEAPON_FIREEXTINGUISHER`, `WEAPON_HAZARDCAN`,
}

-- Head bone index for headshot detection
local SKEL_HEAD = 31086

-- =========================================================================
-- HELPER: distance between two vec3 coordinates
-- =========================================================================

local function distanceBetween(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math_sqrt(dx * dx + dy * dy + dz * dz)
end

-- =========================================================================
-- HELPER: angle between two rotation vectors (degrees)
-- =========================================================================

local function angleDelta(rotA, rotB)
    local dx = math_abs(rotA.x - rotB.x)
    local dy = math_abs(rotA.y - rotB.y)
    local dz = math_abs(rotA.z - rotB.z)
    -- Wrap yaw (z) around 360
    if dz > 180.0 then dz = 360.0 - dz end
    return math_sqrt(dx * dx + dy * dy + dz * dz)
end

-- =========================================================================
-- Guard: bail out early if weapons monitoring is disabled
-- =========================================================================

if not cfg.weapons or not cfg.weapons.enabled then return end

local wcfg = cfg.weapons

-- =========================================================================
-- 1. KILL TRACKING & 7. DAMAGE DEALT REPORTING
--    (via gameEventTriggered — CEventNetworkEntityDamage)
-- =========================================================================

do
    local kills      = 0
    local headshots   = 0
    local shotsFired  = 0
    local shotsHit    = 0
    local lastCombatReport = 0
    local COMBAT_REPORT_INTERVAL = 15000  -- send summary every 15s if active

    AddEventHandler('gameEventTriggered', function(event, data)
        if event ~= 'CEventNetworkEntityDamage' then return end

        --[[
            data indices for CEventNetworkEntityDamage:
            [1] = victim entity
            [2] = attacker entity
            [3] = ?
            [4] = damage (may be 0 for kill event)
            [5] = ?
            [6] = isFatal (bool)
            [7] = weaponHash
            [8] = ?
            [9] = ?
            [10] = ?
            [11] = ?
        ]]
        local victim     = data[1]
        local attacker   = data[2]
        local isFatal    = data[6]
        local weaponHash = data[7]

        local ped = PlayerPedId()

        -- Only process events where the local player is the attacker
        if attacker ~= ped then return end
        if not DoesEntityExist(victim) then return end

        local pedCoords    = GetEntityCoords(ped)
        local victimCoords = GetEntityCoords(victim)
        local distance     = distanceBetween(pedCoords, victimCoords)

        -- Determine headshot via last damage bone
        local boneOk, lastBone = GetPedLastDamageBone(victim)
        local isHeadshot = boneOk and lastBone == SKEL_HEAD

        -- -------------------------------------------------------------------
        -- Damage dealt reporting (every hit)
        -- -------------------------------------------------------------------
        shotsHit = shotsHit + 1

        TriggerServerEvent('hydra:anticheat:report:damage_dealt', {
            amount     = data[4] or 0,
            weaponHash = weaponHash,
            distance   = distance,
            targetType = IsEntityAPed(victim) and 'ped' or 'entity',
        })

        -- -------------------------------------------------------------------
        -- Kill tracking (only if victim is dead / fatal event)
        -- -------------------------------------------------------------------
        if isFatal or IsPedDeadOrDying(victim, true) then
            kills = kills + 1
            if isHeadshot then
                headshots = headshots + 1
            end

            -- Individual kill report for one-hit / aimbot analysis
            TriggerServerEvent('hydra:anticheat:report:kill', {
                weaponHash     = weaponHash,
                headshot       = isHeadshot,
                distance       = distance,
                damageDealt    = data[4] or 0,
                victimMaxHealth = GetEntityMaxHealth(victim) or 200,
            })

            -- Also feed into the combat summary event (type = kill)
            TriggerServerEvent('hydra:anticheat:report:combat', {
                type     = 'kill',
                headshot = isHeadshot,
                targetId = NetworkGetNetworkIdFromEntity(victim),
            })
        end
    end)

    -- Periodic combat summary reporting
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(3000)

        while true do
            local now = GetGameTimer()
            if kills > 0 and (now - lastCombatReport) >= COMBAT_REPORT_INTERVAL then
                TriggerServerEvent('hydra:anticheat:report:combat', {
                    type      = 'summary',
                    kills     = kills,
                    headshots = headshots,
                    shotsFired = shotsFired,
                    shotsHit  = shotsHit,
                })
                kills      = 0
                headshots  = 0
                shotsFired = 0
                shotsHit   = 0
                lastCombatReport = now
            end
            Wait(COMBAT_REPORT_INTERVAL)
        end
    end)

    -- Count shots fired (piggy-back off the rapid-fire thread in monitors.lua,
    -- but also maintain our own counter here via a fast check)
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(3000)

        while true do
            local ped    = PlayerPedId()
            local weapon = GetSelectedPedWeapon(ped)

            if weapon ~= `WEAPON_UNARMED` and DoesEntityExist(ped) then
                if IsPedShooting(ped) then
                    shotsFired = shotsFired + 1

                    TriggerServerEvent('hydra:anticheat:report:combat', {
                        type = 'shot',
                        hit  = false,  -- server correlates with damage events
                    })
                end
                Wait(0)  -- frame-rate polling while weapon is out
            else
                Wait(1000)
            end
        end
    end)
end

-- =========================================================================
-- 2. AIM ANGLE TRACKING (snap detection)
-- =========================================================================

if wcfg.aimbot and wcfg.aimbot.enabled then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(5000)

        local snapThreshold = wcfg.aimbot.snap_angle_threshold or 120.0
        local prevRot       = nil

        while true do
            local ped    = PlayerPedId()
            local weapon = GetSelectedPedWeapon(ped)

            if weapon ~= `WEAPON_UNARMED` and DoesEntityExist(ped) then
                local curRot = GetGameplayCamRot(2)

                if prevRot then
                    local delta = angleDelta(prevRot, curRot)

                    if delta > snapThreshold and IsPedShooting(ped) then
                        TriggerServerEvent('hydra:anticheat:report:combat', {
                            type     = 'aim_delta',
                            delta    = delta,
                            shooting = true,
                        })
                    end
                end

                prevRot = curRot
                Wait(0)  -- per-frame while armed
            else
                prevRot = nil
                Wait(1000)
            end
        end
    end)
end

-- =========================================================================
-- 3. RECOIL MONITORING (no-recoil detection)
-- =========================================================================

if wcfg.no_recoil and wcfg.no_recoil.enabled then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(7000)

        local sampleCount   = wcfg.no_recoil.sample_count or 15
        local pitchSamples  = {}
        local currentWeapon = 0

        while true do
            local ped    = PlayerPedId()
            local weapon = GetSelectedPedWeapon(ped)

            if weapon ~= `WEAPON_UNARMED` and DoesEntityExist(ped) then
                -- Reset buffer on weapon change
                if weapon ~= currentWeapon then
                    pitchSamples  = {}
                    currentWeapon = weapon
                end

                if IsPedShooting(ped) then
                    local rot = GetGameplayCamRot(2)
                    pitchSamples[#pitchSamples + 1] = rot.x  -- pitch axis

                    if #pitchSamples >= sampleCount then
                        TriggerServerEvent('hydra:anticheat:report:recoil', {
                            pitch      = pitchSamples[#pitchSamples],
                            weaponHash = weapon,
                            samples    = pitchSamples,
                        })
                        pitchSamples = {}
                    end
                end

                Wait(0)  -- frame-rate during combat
            else
                -- Idle — clear state and sleep
                if #pitchSamples > 0 then
                    pitchSamples = {}
                end
                currentWeapon = 0
                Wait(1000)
            end
        end
    end)
end

-- =========================================================================
-- 4. AMMO TRACKING (infinite ammo detection)
-- =========================================================================

if wcfg.infinite_ammo and wcfg.infinite_ammo.enabled then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(9000)

        local checkInterval = wcfg.infinite_ammo.check_interval or 10000
        local lastAmmo      = 0
        local lastWeapon    = 0
        local hasFired      = false

        -- Track whether the player has fired between checks
        CreateThread(function()
            while true do
                local ped = PlayerPedId()
                if DoesEntityExist(ped) and IsPedShooting(ped) then
                    hasFired = true
                end
                local weapon = GetSelectedPedWeapon(ped)
                if weapon ~= `WEAPON_UNARMED` then
                    Wait(100)
                else
                    Wait(1000)
                end
            end
        end)

        while true do
            Wait(checkInterval)

            local ped    = PlayerPedId()
            local weapon = GetSelectedPedWeapon(ped)

            if weapon ~= `WEAPON_UNARMED` and DoesEntityExist(ped) then
                local ammo = GetAmmoInPedWeapon(ped, weapon)

                -- Reset tracking on weapon switch
                if weapon ~= lastWeapon then
                    lastWeapon = weapon
                    lastAmmo   = ammo
                    hasFired   = false
                else
                    TriggerServerEvent('hydra:anticheat:report:ammo', {
                        weaponHash = weapon,
                        ammo       = ammo,
                        fired      = hasFired,
                    })
                    lastAmmo = ammo
                    hasFired = false
                end
            end
        end
    end)
end

-- =========================================================================
-- 5. RELOAD DETECTION (no-reload detection)
-- =========================================================================

if wcfg.no_reload and wcfg.no_reload.enabled then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(11000)

        local wasReloading = false

        while true do
            local ped    = PlayerPedId()
            local weapon = GetSelectedPedWeapon(ped)

            if weapon ~= `WEAPON_UNARMED` and DoesEntityExist(ped) then
                local isReloading = IsPedReloading(ped)

                -- Detect the start of a reload (transition from not-reloading to reloading)
                if isReloading and not wasReloading then
                    TriggerServerEvent('hydra:anticheat:report:reload', weapon)
                end

                wasReloading = isReloading
                Wait(100)
            else
                wasReloading = false
                Wait(1000)
            end
        end
    end)
end

-- =========================================================================
-- 6. WEAPON CHANGE TRACKING (weapon give detection)
-- =========================================================================

if wcfg.give_detection and wcfg.give_detection.enabled then
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        Wait(13000)

        local knownWeapons = {}
        local isFirstScan  = true

        while true do
            local ped = PlayerPedId()

            if DoesEntityExist(ped) then
                local currentWeapons = {}
                local newWeapons     = {}

                -- Scan all known weapon hashes
                for i = 1, #WEAPON_GROUPS do
                    local hash = WEAPON_GROUPS[i]
                    if HasPedGotWeapon(ped, hash, false) then
                        currentWeapons[#currentWeapons + 1] = hash

                        if not isFirstScan and not knownWeapons[hash] then
                            newWeapons[#newWeapons + 1] = hash
                        end
                    end
                end

                -- Build the known set from current scan
                local newKnown = {}
                for i = 1, #currentWeapons do
                    newKnown[currentWeapons[i]] = true
                end

                if isFirstScan then
                    -- First scan seeds the inventory on the server
                    TriggerServerEvent('hydra:anticheat:report:weapon_change', {
                        weapons = currentWeapons,
                    })
                    isFirstScan = false
                elseif #newWeapons > 0 then
                    -- New weapons appeared — report full current set plus the new ones
                    TriggerServerEvent('hydra:anticheat:report:weapon_change', {
                        weapons = currentWeapons,
                    })
                end

                knownWeapons = newKnown
            end

            Wait(10000)
        end
    end)
end
