--[[
    Hydra AntiCheat - Network Security

    Network-level detection modules:
    - Desync / ping monitoring
    - Chat / command abuse protection
    - Pickup manipulation detection
    - Vision abuse detection
    - Entity ownership validation
    - Weapon damage event filtering

    All enforcement is server-authoritative — client reports are validated.
]]

local cfg = HydraConfig.AntiCheat
local Flag = Hydra.AntiCheat.Flag
local GetPlayer = Hydra.AntiCheat.GetPlayer
local GetPlayerState = Hydra.AntiCheat.GetPlayerState
local GetAllPlayers = Hydra.AntiCheat.GetAllPlayers
local IsModuleEnabled = Hydra.AntiCheat.IsModuleEnabled

local os_time = os.time
local os_clock = os.clock
local math_sqrt = math.sqrt
local string_format = string.format
local string_lower = string.lower
local string_find = string.find
local table_insert = table.insert
local GetPlayerPed = GetPlayerPed
local GetPlayerPing = GetPlayerPing
local GetEntityCoords = GetEntityCoords
local GetPlayerName = GetPlayerName
local DoesEntityExist = DoesEntityExist

-- =========================================================================
-- DESYNC / PING MONITORING
-- =========================================================================

if cfg.desync and cfg.desync.enabled then
    local pingTracking = {}  -- [src] = { consecutiveHigh = n }

    -- Periodic ping check thread
    CreateThread(function()
        local interval = cfg.desync.ping_check_interval or 10000
        local maxPing = cfg.desync.max_ping or 800
        local tolerance = cfg.desync.ping_tolerance or 5

        while true do
            Wait(interval)
            if not IsModuleEnabled('desync') then goto continue end

            for src, p in pairs(GetAllPlayers()) do
                local ping = GetPlayerPing(src)
                if ping and ping > 0 then
                    if not pingTracking[src] then
                        pingTracking[src] = { consecutiveHigh = 0 }
                    end

                    if ping > maxPing then
                        pingTracking[src].consecutiveHigh = pingTracking[src].consecutiveHigh + 1

                        if pingTracking[src].consecutiveHigh >= tolerance then
                            Flag(src, 'desync',
                                string_format('Sustained high ping: %dms (max %d) for %d consecutive checks',
                                    ping, maxPing, pingTracking[src].consecutiveHigh),
                                cfg.desync.severity or 3, cfg.desync.action, {
                                    ping = ping,
                                    maxPing = maxPing,
                                    consecutive = pingTracking[src].consecutiveHigh,
                                })
                            pingTracking[src].consecutiveHigh = 0
                        end
                    else
                        pingTracking[src].consecutiveHigh = 0
                    end
                end
            end

            ::continue::
        end
    end)

    -- Position desync verification
    RegisterNetEvent('hydra:anticheat:report:position_verify', function(clientPos)
        local src = source
        if not IsModuleEnabled('desync') then return end
        if not src or src <= 0 then return end

        local p = GetPlayer(src)
        if not p then return end

        if type(clientPos) ~= 'vector3' and type(clientPos) ~= 'table' then return end
        if type(clientPos) == 'table' and (type(clientPos.x) ~= 'number' or type(clientPos.y) ~= 'number' or type(clientPos.z) ~= 'number') then
            return
        end

        local ped = GetPlayerPed(src)
        if not ped or ped == 0 or not DoesEntityExist(ped) then return end

        local serverPos = GetEntityCoords(ped)
        local dx = (clientPos.x or 0) - serverPos.x
        local dy = (clientPos.y or 0) - serverPos.y
        local dz = (clientPos.z or 0) - serverPos.z
        local dist = math_sqrt(dx * dx + dy * dy + dz * dz)

        local threshold = cfg.desync.position_desync_threshold or 50.0
        if dist > threshold then
            Flag(src, 'desync',
                string_format('Position desync: client vs server %.1fm (threshold %.1f)',
                    dist, threshold),
                cfg.desync.severity or 3, cfg.desync.action, {
                    clientPos = clientPos,
                    serverPos = serverPos,
                    distance = dist,
                })
        end
    end)

    -- Cleanup on drop
    AddEventHandler('playerDropped', function()
        pingTracking[source] = nil
    end)
end

-- =========================================================================
-- CHAT / COMMAND ABUSE PROTECTION
-- =========================================================================

if cfg.chat_protection and cfg.chat_protection.enabled then
    local chatTracking = {}  -- [src] = { messages = {}, commands = {} }

    -- Common injection / exploit patterns to detect in chat
    local injectionPatterns = {
        'TriggerServerEvent',
        'TriggerClientEvent',
        'ExecuteCommand',
        'RegisterCommand',
        'exports%[',
        'loadstring',
        'load%(',
        'pcall%(load',
        'assert%(load',
        '__cfx_internal',
        'Citizen%.InvokeNative',
        'SetEntityCoords',
        'GiveWeaponToPed',
        'SetEntityHealth',
        'DeleteEntity',
    }

    --- Count entries in a time window and prune expired ones
    --- @param entries table list of timestamps
    --- @param windowSec number time window in seconds
    --- @return number count within window
    local function countInWindow(entries, windowSec)
        local now = os_time()
        local cutoff = now - windowSec
        local fresh = {}
        local count = 0

        for i = 1, #entries do
            if entries[i] >= cutoff then
                count = count + 1
                fresh[#fresh + 1] = entries[i]
            end
        end

        -- Replace entries in-place
        for i = 1, #entries do entries[i] = nil end
        for i = 1, #fresh do entries[i] = fresh[i] end

        return count
    end

    local function getTracker(src)
        if not chatTracking[src] then
            chatTracking[src] = { messages = {}, commands = {} }
        end
        return chatTracking[src]
    end

    RegisterNetEvent('hydra:anticheat:report:chat', function(message, isCommand)
        local src = source
        if not IsModuleEnabled('chat_protection') then return end
        if not src or src <= 0 then return end

        local p = GetPlayer(src)
        if not p then return end

        if type(message) ~= 'string' then
            Flag(src, 'chat_protection', 'Invalid chat payload type',
                3, cfg.chat_protection.action, { payload = type(message) })
            return
        end

        local tracker = getTracker(src)
        local ccfg = cfg.chat_protection
        local now = os_time()

        -- ---- Rate limiting ----
        if isCommand then
            table_insert(tracker.commands, now)
            local cmdCount = countInWindow(tracker.commands, 60)
            local maxCmds = ccfg.max_commands_per_minute or 15

            if cmdCount > maxCmds then
                Flag(src, 'chat_protection',
                    string_format('Command spam: %d commands/min (max %d)', cmdCount, maxCmds),
                    ccfg.severity or 3, ccfg.action, {
                        count = cmdCount,
                        maxPerMinute = maxCmds,
                    })
                return
            end
        else
            table_insert(tracker.messages, now)
            local msgCount = countInWindow(tracker.messages, 60)
            local maxMsgs = ccfg.max_messages_per_minute or 20

            if msgCount > maxMsgs then
                Flag(src, 'chat_protection',
                    string_format('Chat spam: %d messages/min (max %d)', msgCount, maxMsgs),
                    ccfg.severity or 3, ccfg.action, {
                        count = msgCount,
                        maxPerMinute = maxMsgs,
                    })
                return
            end
        end

        -- ---- Injection / exploit pattern detection ----
        if ccfg.detect_injection then
            local msgLower = string_lower(message)

            -- Built-in injection patterns
            for _, pattern in ipairs(injectionPatterns) do
                if string_find(msgLower, string_lower(pattern)) then
                    Flag(src, 'chat_protection',
                        string_format('Chat injection attempt: matched pattern "%s"', pattern),
                        4, ccfg.action, {
                            message = message,
                            pattern = pattern,
                        })
                    return
                end
            end

            -- Config-defined blocked patterns
            if ccfg.blocked_patterns then
                for _, pattern in ipairs(ccfg.blocked_patterns) do
                    local ok, matched = pcall(string_find, msgLower, string_lower(pattern))
                    if ok and matched then
                        Flag(src, 'chat_protection',
                            string_format('Chat blocked pattern: matched "%s"', pattern),
                            ccfg.severity or 3, ccfg.action, {
                                message = message,
                                pattern = pattern,
                            })
                        return
                    end
                end
            end
        end
    end)

    -- Cleanup on drop
    AddEventHandler('playerDropped', function()
        chatTracking[source] = nil
    end)
end

-- =========================================================================
-- PICKUP MANIPULATION DETECTION
-- =========================================================================

if cfg.pickups and cfg.pickups.enabled then
    local pickupTracking = {}  -- [src] = { timestamps = {} }

    RegisterNetEvent('hydra:anticheat:report:pickup', function(pickupId, distance)
        local src = source
        if not IsModuleEnabled('pickups') then return end
        if not src or src <= 0 then return end

        local p = GetPlayer(src)
        if not p then return end

        if type(distance) ~= 'number' then distance = 0.0 end

        local pcfg = cfg.pickups

        -- ---- Distance validation ----
        local maxDist = pcfg.max_collect_distance or 10.0
        if distance > maxDist then
            Flag(src, 'pickups',
                string_format('Pickup collected at impossible distance: %.1fm (max %.1f)',
                    distance, maxDist),
                pcfg.severity or 3, pcfg.action, {
                    pickupId = pickupId,
                    distance = distance,
                    maxDistance = maxDist,
                })
            return
        end

        -- ---- Rate limiting ----
        if not pickupTracking[src] then
            pickupTracking[src] = { timestamps = {} }
        end

        local tracker = pickupTracking[src]
        local now = os_time()
        table_insert(tracker.timestamps, now)

        -- Prune entries older than 60 seconds
        local cutoff = now - 60
        local fresh = {}
        for i = 1, #tracker.timestamps do
            if tracker.timestamps[i] >= cutoff then
                fresh[#fresh + 1] = tracker.timestamps[i]
            end
        end
        tracker.timestamps = fresh

        local maxPerMin = pcfg.max_per_minute or 30
        if #fresh > maxPerMin then
            Flag(src, 'pickups',
                string_format('Pickup spam: %d pickups/min (max %d)', #fresh, maxPerMin),
                pcfg.severity or 3, pcfg.action, {
                    count = #fresh,
                    maxPerMinute = maxPerMin,
                })
        end
    end)

    -- Cleanup on drop
    AddEventHandler('playerDropped', function()
        pickupTracking[source] = nil
    end)
end

-- =========================================================================
-- VISION ABUSE DETECTION
-- =========================================================================

if cfg.vision and cfg.vision.enabled then
    local visionTracking = {}  -- [src] = { thermal = bool, nightVision = bool }

    --- Check if a player's job is in the allowed list
    --- @param src number player source
    --- @return boolean
    local function isVisionAllowed(src)
        local allowed = cfg.vision.allowed_jobs or {}
        if #allowed == 0 then return true end

        -- Attempt to get player job via hydra_bridge
        local jobName = nil
        pcall(function()
            local playerData = exports['hydra_bridge']:GetPlayerData(src)
            if playerData and playerData.job then
                jobName = playerData.job.name or playerData.job
            end
        end)

        if not jobName then return false end

        for _, job in ipairs(allowed) do
            if string_lower(tostring(jobName)) == string_lower(job) then
                return true
            end
        end

        return false
    end

    RegisterNetEvent('hydra:anticheat:report:vision', function(visionType, active)
        local src = source
        if not IsModuleEnabled('vision') then return end
        if not src or src <= 0 then return end

        local p = GetPlayer(src)
        if not p then return end

        if type(visionType) ~= 'string' or type(active) ~= 'boolean' then return end

        if not visionTracking[src] then
            visionTracking[src] = { thermal = false, nightVision = false }
        end

        local vcfg = cfg.vision

        if visionType == 'thermal' then
            visionTracking[src].thermal = active
            if active and vcfg.block_thermal and not isVisionAllowed(src) then
                Flag(src, 'vision',
                    'Unauthorised thermal vision active',
                    vcfg.severity or 2, vcfg.action, {
                        visionType = 'thermal',
                        player = GetPlayerName(src) or 'Unknown',
                    })
            end
        elseif visionType == 'nightvision' then
            visionTracking[src].nightVision = active
            if active and vcfg.block_night_vision and not isVisionAllowed(src) then
                Flag(src, 'vision',
                    'Unauthorised night vision active',
                    vcfg.severity or 2, vcfg.action, {
                        visionType = 'nightvision',
                        player = GetPlayerName(src) or 'Unknown',
                    })
            end
        end
    end)

    -- Periodic vision check thread
    CreateThread(function()
        local interval = cfg.vision.check_interval or 5000

        while true do
            Wait(interval)
            if not IsModuleEnabled('vision') then goto continue end

            for src, data in pairs(visionTracking) do
                local p = GetPlayer(src)
                if not p then
                    visionTracking[src] = nil
                    goto nextPlayer
                end

                if (data.thermal or data.nightVision) and not isVisionAllowed(src) then
                    local vType = data.thermal and 'thermal' or 'nightvision'
                    Flag(src, 'vision',
                        string_format('Persistent unauthorised %s vision', vType),
                        cfg.vision.severity or 2, cfg.vision.action, {
                            visionType = vType,
                            thermal = data.thermal,
                            nightVision = data.nightVision,
                        })
                end

                ::nextPlayer::
            end

            ::continue::
        end
    end)

    -- Cleanup on drop
    AddEventHandler('playerDropped', function()
        visionTracking[source] = nil
    end)
end

-- =========================================================================
-- ENTITY OWNERSHIP VALIDATION
-- =========================================================================

do
    local ownershipTracking = {}  -- [src] = { changes = {}, totalChanges = n }
    local MAX_OWNERSHIP_CHANGES_PER_MINUTE = 50

    RegisterNetEvent('hydra:anticheat:report:entity_takeover', function(entityNetId, entityType)
        local src = source
        if not IsModuleEnabled('entities') then return end
        if not src or src <= 0 then return end

        local p = GetPlayer(src)
        if not p then return end

        if type(entityNetId) ~= 'number' then return end

        if not ownershipTracking[src] then
            ownershipTracking[src] = { changes = {}, totalChanges = 0 }
        end

        local tracker = ownershipTracking[src]
        local now = os_time()

        table_insert(tracker.changes, now)

        -- Prune entries older than 60 seconds
        local cutoff = now - 60
        local fresh = {}
        for i = 1, #tracker.changes do
            if tracker.changes[i] >= cutoff then
                fresh[#fresh + 1] = tracker.changes[i]
            end
        end
        tracker.changes = fresh

        local changeCount = #fresh
        if changeCount > MAX_OWNERSHIP_CHANGES_PER_MINUTE then
            Flag(src, 'entities',
                string_format('Excessive entity ownership changes: %d/min (max %d)',
                    changeCount, MAX_OWNERSHIP_CHANGES_PER_MINUTE),
                cfg.entities.excess_severity or 3, cfg.entities.excess_action or 'kick', {
                    changeCount = changeCount,
                    maxPerMinute = MAX_OWNERSHIP_CHANGES_PER_MINUTE,
                    lastEntityNetId = entityNetId,
                    entityType = entityType,
                })
        end
    end)

    -- Cleanup on drop
    AddEventHandler('playerDropped', function()
        ownershipTracking[source] = nil
    end)
end

-- =========================================================================
-- WEAPON DAMAGE EVENT FILTERING (native FiveM server event)
-- =========================================================================

if cfg.damage and cfg.damage.enabled then
    local damageTracking = {}  -- [src] = { total = n, resetTime = t }

    AddEventHandler('weaponDamageEvent', function(src, ev)
        if not IsModuleEnabled('damage') then return end
        if not src or src <= 0 then return end

        local p = GetPlayer(src)
        if not p then return end

        local dcfg = cfg.damage

        -- ---- Validate damage amount ----
        local damage = ev.weaponDamage or 0
        local maxSingle = dcfg.max_single_damage or 500

        if damage > maxSingle then
            Flag(src, 'damage',
                string_format('Impossible damage value: %.1f (max %d)',
                    damage, maxSingle),
                dcfg.excess_damage_severity or 4, dcfg.excess_damage_action, {
                    damage = damage,
                    maxDamage = maxSingle,
                    weaponType = ev.weaponType,
                })
            CancelEvent()
            return
        end

        -- ---- DPS tracking ----
        local now = os_time()
        if not damageTracking[src] or now > damageTracking[src].resetTime then
            damageTracking[src] = { total = 0, resetTime = now + 1 }
        end

        damageTracking[src].total = damageTracking[src].total + damage
        local maxDps = dcfg.max_dps or 2000

        if damageTracking[src].total > maxDps then
            Flag(src, 'damage',
                string_format('DPS exceeds limit: %.1f (max %d)',
                    damageTracking[src].total, maxDps),
                dcfg.excess_damage_severity or 4, dcfg.excess_damage_action, {
                    dps = damageTracking[src].total,
                    maxDps = maxDps,
                })
            CancelEvent()
            return
        end

        -- ---- Distance validation ----
        local maxDist = dcfg.max_damage_distance or 500.0

        local attackerPed = GetPlayerPed(src)
        if attackerPed and attackerPed ~= 0 and DoesEntityExist(attackerPed) then
            local attackerPos = GetEntityCoords(attackerPed)

            -- ev.hitEntityCoord holds the position where damage was dealt
            -- Some weaponDamageEvent variants provide damageFlags and hitComponent
            -- but position is derived from the hit entity if available
            local hitGlobalEntity = ev.hitGlobalId or 0
            if hitGlobalEntity and hitGlobalEntity ~= 0 then
                local hitEntity = NetworkGetEntityFromNetworkId(hitGlobalEntity)
                if hitEntity and hitEntity ~= 0 and DoesEntityExist(hitEntity) then
                    local targetPos = GetEntityCoords(hitEntity)
                    local dx = attackerPos.x - targetPos.x
                    local dy = attackerPos.y - targetPos.y
                    local dz = attackerPos.z - targetPos.z
                    local dist = math_sqrt(dx * dx + dy * dy + dz * dz)

                    if dist > maxDist then
                        Flag(src, 'damage',
                            string_format('Damage from impossible distance: %.1fm (max %.1f)',
                                dist, maxDist),
                            dcfg.distance_severity or 4, dcfg.distance_action, {
                                distance = dist,
                                maxDistance = maxDist,
                                attackerPos = attackerPos,
                                targetPos = targetPos,
                            })
                        CancelEvent()
                        return
                    end
                end
            end
        end
    end)

    -- Cleanup on drop
    AddEventHandler('playerDropped', function()
        damageTracking[source] = nil
    end)
end
