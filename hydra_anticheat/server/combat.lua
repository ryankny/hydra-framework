--[[
    Hydra AntiCheat - Combat Detection

    Server-side combat validation modules:
    - Aimbot detection (headshot ratio, snap angles, lock-on tracking)
    - No recoil detection (camera pitch variance analysis)
    - Infinite ammo detection (ammo count monitoring)
    - No reload detection (continuous shot tracking)
    - One-hit kill detection (instant-kill pattern recognition)
    - Damage validation (DPS, single-hit, distance checks)
    - Weapon give detection (unauthorised weapon acquisition)
]]

local cfg = HydraConfig.AntiCheat
local Flag = Hydra.AntiCheat.Flag
local GetPlayer = Hydra.AntiCheat.GetPlayer
local GetPlayerState = Hydra.AntiCheat.GetPlayerState
local IsModuleEnabled = Hydra.AntiCheat.IsModuleEnabled

local os_clock = os.clock
local math_sqrt = math.sqrt
local string_format = string.format

-- =========================================================================
-- INTERNAL STATE
-- =========================================================================

local combatStats = {}          -- [src] = { kills, headshots, shots_fired, shots_hit, ... }
local recoilSamples = {}        -- [src] = { samples = {}, weaponHash }
local ammoTracking = {}         -- [src] = { [weaponHash] = { lastAmmo, noDecreaseCount } }
local reloadTracking = {}       -- [src] = { consecutiveShots }
local oneHitTracking = {}       -- [src] = { consecutiveOneHits }
local damageTracking = {}       -- [src] = { hits = { {amount, time} }, ... }
local weaponInventory = {}      -- [src] = { [weaponHash] = true }
local weaponGraceEvents = {}    -- [src] = { lastWhitelistedTime }
local lockOnTracking = {}       -- [src] = { [targetId] = { hits = {}, ... } }

-- =========================================================================
-- CLEANUP ON PLAYER DROP
-- =========================================================================

AddEventHandler('playerDropped', function()
    local src = source
    combatStats[src] = nil
    recoilSamples[src] = nil
    ammoTracking[src] = nil
    reloadTracking[src] = nil
    oneHitTracking[src] = nil
    damageTracking[src] = nil
    weaponInventory[src] = nil
    weaponGraceEvents[src] = nil
    lockOnTracking[src] = nil
end)

-- =========================================================================
-- HELPER: ensure combat state exists for a player
-- =========================================================================

local function ensureCombatState(src)
    if not combatStats[src] then
        combatStats[src] = {
            kills = 0,
            headshots = 0,
            shots_fired = 0,
            shots_hit = 0,
            snap_violations = 0,
        }
    end
    return combatStats[src]
end

-- =========================================================================
-- 1. AIMBOT DETECTION
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:combat', function(data)
    local src = source
    if not IsModuleEnabled('weapons') then return end

    local wcfg = cfg.weapons
    if not wcfg or not wcfg.aimbot or not wcfg.aimbot.enabled then return end

    local acfg = wcfg.aimbot

    if type(data) ~= 'table' then
        Flag(src, 'weapons', 'Invalid combat report payload', 3, 'kick')
        return
    end

    local stats = ensureCombatState(src)
    local now = os_clock()

    -- -----------------------------------------------------------------------
    -- Track kill event
    -- -----------------------------------------------------------------------
    if data.type == 'kill' then
        stats.kills = stats.kills + 1

        if data.headshot then
            stats.headshots = stats.headshots + 1
        end

        -- Headshot ratio analysis (after enough kills)
        if stats.kills >= acfg.min_kills_for_analysis then
            local ratio = stats.headshots / stats.kills
            if ratio > acfg.headshot_ratio_threshold then
                Flag(src, 'weapons',
                    string_format('Aimbot suspected: %.0f%% headshot ratio (%d/%d kills)',
                        ratio * 100, stats.headshots, stats.kills),
                    acfg.severity or 5, acfg.action, {
                        headshots = stats.headshots,
                        kills = stats.kills,
                        ratio = ratio,
                    })
                -- Reset counters after flagging to allow re-analysis
                stats.kills = 0
                stats.headshots = 0
            end
        end

        -- Lock-on detection: same target hit rapidly
        if data.targetId then
            if not lockOnTracking[src] then
                lockOnTracking[src] = {}
            end

            local targetData = lockOnTracking[src][data.targetId]
            if not targetData then
                targetData = { hits = {} }
                lockOnTracking[src][data.targetId] = targetData
            end

            -- Add current hit timestamp
            targetData.hits[#targetData.hits + 1] = now

            -- Prune hits outside the window
            local windowSec = (acfg.lock_on_window or 2000) / 1000
            local fresh = {}
            for _, hitTime in ipairs(targetData.hits) do
                if (now - hitTime) <= windowSec then
                    fresh[#fresh + 1] = hitTime
                end
            end
            targetData.hits = fresh

            if #targetData.hits >= acfg.lock_on_threshold then
                Flag(src, 'weapons',
                    string_format('Aimbot lock-on: %d hits on target %s within %.1fs',
                        #targetData.hits, tostring(data.targetId), windowSec),
                    acfg.severity or 5, acfg.action, {
                        targetId = data.targetId,
                        hits = #targetData.hits,
                        window = windowSec,
                    })
                -- Reset tracking for this target
                lockOnTracking[src][data.targetId] = nil
            end
        end

    -- -----------------------------------------------------------------------
    -- Track shot event
    -- -----------------------------------------------------------------------
    elseif data.type == 'shot' then
        stats.shots_fired = stats.shots_fired + 1
        if data.hit then
            stats.shots_hit = stats.shots_hit + 1
        end

    -- -----------------------------------------------------------------------
    -- Snap angle detection (client reports aim angle delta)
    -- -----------------------------------------------------------------------
    elseif data.type == 'aim_delta' then
        local delta = tonumber(data.delta)
        if delta and delta > acfg.snap_angle_threshold then
            stats.snap_violations = stats.snap_violations + 1
            if stats.snap_violations >= 3 then
                Flag(src, 'weapons',
                    string_format('Aimbot snap angle: %.1f deg delta (%d violations)',
                        delta, stats.snap_violations),
                    acfg.severity or 5, acfg.action, {
                        delta = delta,
                        violations = stats.snap_violations,
                    })
                stats.snap_violations = 0
            end
        end
    end
end)

-- =========================================================================
-- 2. NO RECOIL DETECTION
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:recoil', function(data)
    local src = source
    if not IsModuleEnabled('weapons') then return end

    local wcfg = cfg.weapons
    if not wcfg or not wcfg.no_recoil or not wcfg.no_recoil.enabled then return end

    local rcfg = wcfg.no_recoil

    if type(data) ~= 'table' then return end

    local pitchSample = tonumber(data.pitch)
    local weaponHash = data.weaponHash
    if not pitchSample or not weaponHash then return end

    -- Initialise or reset if weapon changed
    if not recoilSamples[src] or recoilSamples[src].weaponHash ~= weaponHash then
        recoilSamples[src] = { samples = {}, weaponHash = weaponHash }
    end

    local tracker = recoilSamples[src]
    tracker.samples[#tracker.samples + 1] = pitchSample

    -- Once we have enough samples, calculate variance
    if #tracker.samples >= rcfg.sample_count then
        -- Calculate mean
        local sum = 0
        for _, v in ipairs(tracker.samples) do
            sum = sum + v
        end
        local mean = sum / #tracker.samples

        -- Calculate variance
        local varianceSum = 0
        for _, v in ipairs(tracker.samples) do
            local diff = v - mean
            varianceSum = varianceSum + (diff * diff)
        end
        local variance = varianceSum / #tracker.samples

        if variance < rcfg.min_variance_threshold then
            Flag(src, 'weapons',
                string_format('No recoil detected: pitch variance %.4f (min %.4f) over %d shots, weapon 0x%X',
                    variance, rcfg.min_variance_threshold, #tracker.samples, weaponHash),
                rcfg.severity or 4, rcfg.action, {
                    variance = variance,
                    threshold = rcfg.min_variance_threshold,
                    sampleCount = #tracker.samples,
                    weapon = weaponHash,
                })
        end

        -- Reset samples for next window
        tracker.samples = {}
    end
end)

-- =========================================================================
-- 3. INFINITE AMMO DETECTION
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:ammo', function(data)
    local src = source
    if not IsModuleEnabled('weapons') then return end

    local wcfg = cfg.weapons
    if not wcfg or not wcfg.infinite_ammo or not wcfg.infinite_ammo.enabled then return end

    local iacfg = wcfg.infinite_ammo

    if type(data) ~= 'table' then return end

    local weaponHash = data.weaponHash
    local ammo = tonumber(data.ammo)
    local fired = data.fired  -- whether the player has fired since last report

    if not weaponHash or not ammo then return end

    if not ammoTracking[src] then
        ammoTracking[src] = {}
    end

    local wt = ammoTracking[src][weaponHash]

    if not wt then
        ammoTracking[src][weaponHash] = { lastAmmo = ammo, noDecreaseCount = 0 }
        return
    end

    -- Only check if the player has been firing
    if fired then
        if ammo >= wt.lastAmmo and wt.lastAmmo > 0 then
            -- Ammo did not decrease despite firing
            wt.noDecreaseCount = wt.noDecreaseCount + 1

            if wt.noDecreaseCount >= iacfg.tolerance then
                Flag(src, 'weapons',
                    string_format('Infinite ammo: weapon 0x%X, ammo stuck at %d over %d checks',
                        weaponHash, ammo, wt.noDecreaseCount),
                    iacfg.severity or 4, iacfg.action, {
                        weapon = weaponHash,
                        ammo = ammo,
                        checks = wt.noDecreaseCount,
                    })
                wt.noDecreaseCount = 0
            end
        else
            -- Ammo decreased normally
            wt.noDecreaseCount = 0
        end
    end

    wt.lastAmmo = ammo
end)

-- =========================================================================
-- 4. NO RELOAD DETECTION
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:reload', function()
    local src = source
    if not IsModuleEnabled('weapons') then return end

    -- Player reloaded: reset consecutive shot counter
    if reloadTracking[src] then
        reloadTracking[src].consecutiveShots = 0
    end
end)

-- Track shots for no-reload detection via the fire event
-- This hooks into the existing fire report by also counting here
RegisterNetEvent('hydra:anticheat:report:fire', function(weaponHash, timestamp)
    local src = source
    if not IsModuleEnabled('weapons') then return end

    local wcfg = cfg.weapons
    if not wcfg or not wcfg.no_reload or not wcfg.no_reload.enabled then return end

    local nrcfg = wcfg.no_reload

    if not reloadTracking[src] then
        reloadTracking[src] = { consecutiveShots = 0, weaponHash = nil }
    end

    local tracker = reloadTracking[src]

    -- Reset counter if weapon changed (different weapon = new magazine)
    if tracker.weaponHash ~= weaponHash then
        tracker.consecutiveShots = 0
        tracker.weaponHash = weaponHash
    end

    tracker.consecutiveShots = tracker.consecutiveShots + 1

    if tracker.consecutiveShots > nrcfg.max_continuous_shots then
        Flag(src, 'weapons',
            string_format('No reload detected: %d consecutive shots without reload, weapon 0x%X',
                tracker.consecutiveShots, weaponHash),
            nrcfg.severity or 3, nrcfg.action, {
                weapon = weaponHash,
                shots = tracker.consecutiveShots,
                max = nrcfg.max_continuous_shots,
            })
        tracker.consecutiveShots = 0
    end
end)

-- =========================================================================
-- 5. ONE-HIT KILL DETECTION
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:kill', function(data)
    local src = source
    if not IsModuleEnabled('weapons') then return end

    local wcfg = cfg.weapons
    if not wcfg or not wcfg.one_hit_kill then return end

    if type(data) ~= 'table' then return end

    local damageDealt = tonumber(data.damageDealt)
    local victimMaxHealth = tonumber(data.victimMaxHealth)
    local weaponHash = data.weaponHash

    if not damageDealt or not victimMaxHealth then return end

    if not oneHitTracking[src] then
        oneHitTracking[src] = { consecutiveOneHits = 0 }
    end

    local tracker = oneHitTracking[src]

    -- Check if victim was killed in a single hit (damage >= max health)
    if damageDealt >= victimMaxHealth then
        tracker.consecutiveOneHits = tracker.consecutiveOneHits + 1

        if tracker.consecutiveOneHits >= (wcfg.one_hit_tolerance or 3) then
            Flag(src, 'weapons',
                string_format('One-hit kill pattern: %d consecutive instant kills (damage %d, victim HP %d)',
                    tracker.consecutiveOneHits, damageDealt, victimMaxHealth),
                wcfg.damage_severity or 4, wcfg.damage_action or 'kick', {
                    consecutiveOneHits = tracker.consecutiveOneHits,
                    lastDamage = damageDealt,
                    victimMaxHealth = victimMaxHealth,
                    weapon = weaponHash,
                })
            tracker.consecutiveOneHits = 0
        end
    else
        -- Normal kill, reset counter
        tracker.consecutiveOneHits = 0
    end
end)

-- =========================================================================
-- 6. DAMAGE VALIDATION
-- =========================================================================

RegisterNetEvent('hydra:anticheat:report:damage_dealt', function(data)
    local src = source
    if not IsModuleEnabled('weapons') then return end

    local dcfg = cfg.damage
    if not dcfg or not dcfg.enabled then return end

    if type(data) ~= 'table' then return end

    local amount = tonumber(data.amount)
    local distance = tonumber(data.distance)
    local weaponHash = data.weaponHash

    if not amount then return end

    local now = os_clock()

    -- Initialise damage tracking for this player
    if not damageTracking[src] then
        damageTracking[src] = { hits = {} }
    end

    local tracker = damageTracking[src]

    -- -----------------------------------------------------------------------
    -- Single hit damage check
    -- -----------------------------------------------------------------------
    if amount > dcfg.max_single_damage then
        Flag(src, 'weapons',
            string_format('Excessive single hit damage: %.0f (max %d)',
                amount, dcfg.max_single_damage),
            dcfg.excess_damage_severity or 4, dcfg.excess_damage_action or 'kick', {
                damage = amount,
                maxAllowed = dcfg.max_single_damage,
                weapon = weaponHash,
            })
    end

    -- -----------------------------------------------------------------------
    -- Distance check
    -- -----------------------------------------------------------------------
    if distance and distance > dcfg.max_damage_distance then
        Flag(src, 'weapons',
            string_format('Damage at impossible distance: %.1fm (max %.1f)',
                distance, dcfg.max_damage_distance),
            dcfg.distance_severity or 4, dcfg.distance_action or 'kick', {
                distance = distance,
                maxAllowed = dcfg.max_damage_distance,
                weapon = weaponHash,
                damage = amount,
            })
    end

    -- -----------------------------------------------------------------------
    -- DPS tracking (rolling 1-second window)
    -- -----------------------------------------------------------------------
    tracker.hits[#tracker.hits + 1] = { amount = amount, time = now }

    -- Prune hits older than 1 second
    local fresh = {}
    local totalDamage = 0
    for _, hit in ipairs(tracker.hits) do
        if (now - hit.time) <= 1.0 then
            fresh[#fresh + 1] = hit
            totalDamage = totalDamage + hit.amount
        end
    end
    tracker.hits = fresh

    if totalDamage > dcfg.max_dps then
        Flag(src, 'weapons',
            string_format('Excessive DPS: %.0f damage/sec (max %d)',
                totalDamage, dcfg.max_dps),
            dcfg.excess_damage_severity or 4, dcfg.excess_damage_action or 'kick', {
                dps = totalDamage,
                maxAllowed = dcfg.max_dps,
                hitCount = #fresh,
                weapon = weaponHash,
            })
    end
end)

-- =========================================================================
-- 7. WEAPON GIVE DETECTION
-- =========================================================================

--- Called by trusted resources when they legitimately give a weapon
--- This sets a grace window so the weapon change is not flagged
function Hydra.AntiCheat.WhitelistWeaponGive(src)
    weaponGraceEvents[src] = os_clock()
end

exports('WhitelistWeaponGive', Hydra.AntiCheat.WhitelistWeaponGive)

RegisterNetEvent('hydra:anticheat:report:weapon_change', function(data)
    local src = source
    if not IsModuleEnabled('weapons') then return end

    local wcfg = cfg.weapons
    if not wcfg or not wcfg.give_detection or not wcfg.give_detection.enabled then return end

    local gcfg = wcfg.give_detection

    if type(data) ~= 'table' then return end

    local weapons = data.weapons  -- array of weapon hashes currently held

    if type(weapons) ~= 'table' then return end

    -- Initialise inventory tracking
    if not weaponInventory[src] then
        -- First report: seed the inventory, do not flag
        weaponInventory[src] = {}
        for _, hash in ipairs(weapons) do
            weaponInventory[src][hash] = true
        end
        return
    end

    local now = os_clock()
    local inventory = weaponInventory[src]

    -- Check for newly appeared weapons
    for _, hash in ipairs(weapons) do
        if not inventory[hash] then
            -- New weapon detected — check if a whitelisted source fired recently
            local graceTime = weaponGraceEvents[src]
            local isWhitelisted = graceTime and (now - graceTime) < 5.0  -- 5 second grace window

            if not isWhitelisted then
                -- Check whitelisted sources from config (resource-based)
                local fromTrustedSource = false
                for _, whitelisted in ipairs(gcfg.whitelisted_sources or {}) do
                    -- If the resource recently triggered the grace, allow it
                    if Hydra.AntiCheat.IsTrustedResource(whitelisted) then
                        fromTrustedSource = true
                        break
                    end
                end

                if not fromTrustedSource then
                    Flag(src, 'weapons',
                        string_format('Weapon spawned without legitimate source: 0x%X', hash),
                        gcfg.severity or 4, gcfg.action or 'kick', {
                            weapon = hash,
                            currentWeapons = weapons,
                        })
                end
            end

            -- Add to known inventory regardless (avoid repeat flags)
            inventory[hash] = true
        end
    end

    -- Remove weapons the player no longer has (they may have been taken)
    local currentSet = {}
    for _, hash in ipairs(weapons) do
        currentSet[hash] = true
    end
    for hash in pairs(inventory) do
        if not currentSet[hash] then
            inventory[hash] = nil
        end
    end

    -- Clear the grace event after processing
    if weaponGraceEvents[src] and (now - weaponGraceEvents[src]) > 5.0 then
        weaponGraceEvents[src] = nil
    end
end)

-- =========================================================================
-- PERIODIC CLEANUP — prevent stale data from building up
-- =========================================================================

CreateThread(function()
    while true do
        Wait(60000)  -- Every 60 seconds
        local now = os_clock()

        -- Clean up lock-on tracking: prune old hit records
        for src, targets in pairs(lockOnTracking) do
            if not GetPlayer(src) then
                lockOnTracking[src] = nil
            else
                local windowSec = (cfg.weapons and cfg.weapons.aimbot and cfg.weapons.aimbot.lock_on_window or 2000) / 1000
                for targetId, targetData in pairs(targets) do
                    local fresh = {}
                    for _, hitTime in ipairs(targetData.hits) do
                        if (now - hitTime) <= windowSec then
                            fresh[#fresh + 1] = hitTime
                        end
                    end
                    if #fresh == 0 then
                        targets[targetId] = nil
                    else
                        targetData.hits = fresh
                    end
                end
            end
        end

        -- Clean up damage tracking: prune old hits
        for src, tracker in pairs(damageTracking) do
            if not GetPlayer(src) then
                damageTracking[src] = nil
            else
                local fresh = {}
                for _, hit in ipairs(tracker.hits) do
                    if (now - hit.time) <= 5.0 then
                        fresh[#fresh + 1] = hit
                    end
                end
                tracker.hits = fresh
            end
        end

        -- Clean up stale player data for disconnected players
        for _, tbl in ipairs({combatStats, recoilSamples, ammoTracking, reloadTracking, oneHitTracking, weaponInventory, weaponGraceEvents}) do
            for src in pairs(tbl) do
                if not GetPlayer(src) then
                    tbl[src] = nil
                end
            end
        end
    end
end)
