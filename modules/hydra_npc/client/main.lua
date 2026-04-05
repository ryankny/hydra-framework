--[[
    Hydra NPC - Client
    Centralized NPC spawning, management, proximity engine, dialogue,
    walk routes, and hook system for the Hydra FiveM framework.
]]

Hydra = Hydra or {}
Hydra.NPC = Hydra.NPC or {}

local cfg = HydraConfig.NPC
if not cfg.enabled then return end

-- ── State ───────────────────────────────────────────────────────────────────

local npcs         = {}
local modelCache   = {}   -- [hash] = { refCount = N, loaded = bool }
local npcCounter   = 0
local hooksPre     = {}
local hooksPost    = {}
local hooksInteract = {}

local RELATIONSHIP_MAP = {
    companion = 0,
    respect   = 1,
    like      = 2,
    neutral   = 3,
    dislike   = 4,
    hate      = 5,
}

-- ── Utilities ───────────────────────────────────────────────────────────────

local function debugLog(msg, ...)
    if cfg.debug then
        print(('[Hydra NPC] ' .. msg):format(...))
    end
end

local function generateId()
    npcCounter = npcCounter + 1
    return ('npc_%d_%d'):format(GetGameTimer(), npcCounter)
end

local function vec3Dist(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function getPlayerCoords()
    return GetEntityCoords(PlayerPedId())
end

local function fireHooks(hookTable, ...)
    for i = 1, #hookTable do
        local ok, err = pcall(hookTable[i], ...)
        if not ok then
            debugLog('Hook error: %s', tostring(err))
        end
    end
end

local function getSpawnedCount()
    local count = 0
    for _, npc in pairs(npcs) do
        if npc.spawned then count = count + 1 end
    end
    return count
end

-- ── Model Loading (ref-counted, cached) ─────────────────────────────────────

local function loadModel(modelName)
    local hash = type(modelName) == 'number' and modelName or joaat(modelName)

    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        debugLog('Invalid model: %s', tostring(modelName))
        return nil
    end

    if modelCache[hash] then
        modelCache[hash].refCount = modelCache[hash].refCount + 1
        if HasModelLoaded(hash) then
            modelCache[hash].loaded = true
            return hash
        end
    else
        modelCache[hash] = { refCount = 1, loaded = false }
    end

    RequestModel(hash)
    local timeout = cfg.model_timeout or 5000
    local start = GetGameTimer()
    while not HasModelLoaded(hash) do
        if GetGameTimer() - start > timeout then
            debugLog('Model load timeout: %s', tostring(modelName))
            modelCache[hash].refCount = modelCache[hash].refCount - 1
            if modelCache[hash].refCount <= 0 then
                modelCache[hash] = nil
            end
            return nil
        end
        Citizen.Wait(0)
    end

    modelCache[hash].loaded = true
    return hash
end

local function releaseModel(hash)
    if not hash or not modelCache[hash] then return end
    modelCache[hash].refCount = modelCache[hash].refCount - 1
    if modelCache[hash].refCount <= 0 then
        SetModelAsNoLongerNeeded(hash)
        modelCache[hash] = nil
        debugLog('Released model: 0x%X', hash)
    end
end

-- ── Relationship Groups ─────────────────────────────────────────────────────

local function applyRelationship(entity, relationship)
    if not entity or not DoesEntityExist(entity) then return end

    local relName = relationship or cfg.behavior.default_relationship or 'companion'
    local relValue = RELATIONSHIP_MAP[relName]
    if relValue == nil then relValue = RELATIONSHIP_MAP.neutral end

    local groupHash = GetHashKey('HYDRA_NPC_' .. tostring(entity))
    AddRelationshipGroup('HYDRA_NPC_' .. tostring(entity), groupHash)
    SetPedRelationshipGroupHash(entity, groupHash)

    local playerGroup = GetHashKey('PLAYER')
    SetRelationshipBetweenGroups(relValue, groupHash, playerGroup)
    SetRelationshipBetweenGroups(relValue, playerGroup, groupHash)
end

-- ── Target Registration ─────────────────────────────────────────────────────

local function registerInteractions(npcId, entity, interactions)
    if not interactions or #interactions == 0 then return end
    if not entity or not DoesEntityExist(entity) then return end

    local targetOpts = {}
    for i, inter in ipairs(interactions) do
        targetOpts[i] = {
            label = inter.label,
            icon = inter.icon,
            action = function()
                if inter.onSelect then
                    inter.onSelect(npcId, entity)
                end
                fireHooks(hooksInteract, npcId, entity)
            end,
            canInteract = inter.canInteract and function()
                return inter.canInteract(npcId, entity)
            end or nil,
        }
    end

    local ok, err = pcall(function()
        exports['hydra_target']:AddEntity(entity, targetOpts)
    end)
    if not ok then
        debugLog('hydra_target not available: %s', tostring(err))
    end
end

local function unregisterInteractions(entity)
    if not entity or not DoesEntityExist(entity) then return end
    local ok, _ = pcall(function()
        exports['hydra_target']:RemoveEntity(entity)
    end)
end

-- ── Dialogue System ─────────────────────────────────────────────────────────

local function showDialogueNode(npcId, entity, dialogue, nodeIndex)
    if not dialogue or not dialogue[nodeIndex] then return end

    local node = dialogue[nodeIndex]
    local menuItems = {}

    if node.options then
        for _, opt in ipairs(node.options) do
            menuItems[#menuItems + 1] = {
                label = opt.label,
                action = function()
                    if opt.event then
                        TriggerEvent(opt.event, npcId, entity, opt.args)
                    end
                    if opt.serverEvent then
                        TriggerServerEvent(opt.serverEvent, npcId, opt.args)
                    end
                    if opt.next then
                        showDialogueNode(npcId, entity, dialogue, opt.next)
                    end
                end,
            }
        end
    end

    local ok, err = pcall(function()
        exports['hydra_context']:Show({
            title = node.text,
            options = menuItems,
        })
    end)
    if not ok then
        debugLog('hydra_context not available for dialogue: %s', tostring(err))
    end
end

-- ── Walk Route Thread ───────────────────────────────────────────────────────

local function startWalkRoute(npcId)
    local npc = npcs[npcId]
    if not npc or not npc.walkRoute or #npc.walkRoute == 0 then return end
    if npc._walkThread then return end

    npc._walkThread = true

    Citizen.CreateThread(function()
        local waypointIdx = 1
        local speed = npc.walkSpeed or 1.0

        while npcs[npcId] and npcs[npcId].spawned and npcs[npcId]._walkThread do
            local entity = npcs[npcId].entity
            if not entity or not DoesEntityExist(entity) then break end

            local route = npcs[npcId].walkRoute
            if not route or #route == 0 then break end

            local wp = route[waypointIdx]
            TaskGoToCoordAnyMeans(entity, wp.x, wp.y, wp.z, speed, 0, false, 786603, 0.0)

            -- Wait until near waypoint or NPC removed
            while npcs[npcId] and npcs[npcId].spawned do
                local ent = npcs[npcId].entity
                if not ent or not DoesEntityExist(ent) then break end
                local eCoords = GetEntityCoords(ent)
                if vec3Dist(eCoords, wp) < 2.0 then break end
                Citizen.Wait(500)
            end

            waypointIdx = waypointIdx + 1
            if waypointIdx > #route then
                if npcs[npcId] and npcs[npcId].walkLoop ~= false then
                    waypointIdx = 1
                else
                    break
                end
            end

            Citizen.Wait(100)
        end

        if npcs[npcId] then
            npcs[npcId]._walkThread = nil
        end
    end)
end

local function stopWalkRoute(npcId)
    if npcs[npcId] then
        npcs[npcId]._walkThread = nil
    end
end

-- ── Core: Spawn ─────────────────────────────────────────────────────────────

function Hydra.NPC.Spawn(npcId)
    local npc = npcs[npcId]
    if not npc then
        debugLog('Spawn: NPC %s does not exist', tostring(npcId))
        return nil
    end
    if npc.spawned and npc.entity and DoesEntityExist(npc.entity) then
        return npc.entity
    end

    -- Fire pre-spawn hooks
    fireHooks(hooksPre, npcId)

    -- Load model
    local hash = loadModel(npc.model)
    if not hash then
        debugLog('Spawn: Could not load model for %s', npcId)
        return nil
    end
    npc._modelHash = hash

    -- Extract coords
    local x, y, z = npc.coords.x, npc.coords.y, npc.coords.z
    local heading = npc.heading or (npc.coords.w and npc.coords.w) or 0.0
    local networked = npc.networked

    -- Create ped
    local entity = CreatePed(28, hash, x, y, z, heading, networked, false)
    if not entity or entity == 0 then
        debugLog('Spawn: CreatePed failed for %s', npcId)
        releaseModel(hash)
        return nil
    end

    npc.entity = entity
    npc.spawned = true

    -- Core properties
    SetEntityInvincible(entity, npc.invincible)
    FreezeEntityPosition(entity, npc.frozen)
    SetBlockingOfNonTemporaryEvents(entity, not npc.blocking)
    SetPedFleeAttributes(entity, 0, false)
    SetPedCombatAttributes(entity, 46, true)
    SetPedCanRagdollFromPlayerImpact(entity, false)

    -- Weapon
    if npc.weapon then
        local weapHash = type(npc.weapon) == 'number' and npc.weapon or joaat(npc.weapon)
        GiveWeaponToPed(entity, weapHash, 999, false, true)
    end

    -- Components
    if npc.components then
        for compId, comp in pairs(npc.components) do
            SetPedComponentVariation(
                entity,
                tonumber(compId),
                comp.drawable or 0,
                comp.texture or 0,
                comp.palette or 0
            )
        end
    end

    -- Props
    if npc.props then
        for propId, prop in pairs(npc.props) do
            SetPedPropIndex(
                entity,
                tonumber(propId),
                prop.drawable or 0,
                prop.texture or 0,
                true
            )
        end
    end

    -- Scenario
    if npc.scenario then
        local scenarioApplied = false
        local ok, _ = pcall(function()
            exports['hydra_anims']:PlayScenario(entity, npc.scenario)
            scenarioApplied = true
        end)
        if not scenarioApplied then
            TaskStartScenarioInPlace(entity, npc.scenario, 0, true)
        end
    end

    -- Animation
    if npc.anim and npc.anim.dict and npc.anim.name then
        local animApplied = false
        local ok, _ = pcall(function()
            exports['hydra_anims']:PlayAnim(entity, npc.anim.dict, npc.anim.name, npc.anim.flag or -1)
            animApplied = true
        end)
        if not animApplied then
            RequestAnimDict(npc.anim.dict)
            local aStart = GetGameTimer()
            while not HasAnimDictLoaded(npc.anim.dict) do
                if GetGameTimer() - aStart > 2000 then break end
                Citizen.Wait(0)
            end
            if HasAnimDictLoaded(npc.anim.dict) then
                TaskPlayAnim(entity, npc.anim.dict, npc.anim.name, 8.0, -8.0, -1, npc.anim.flag or 1, 0, false, false, false)
            end
        end
    end

    -- Interactions
    if npc.interactions and #npc.interactions > 0 then
        registerInteractions(npcId, entity, npc.interactions)
    end

    -- Dialogue: auto-register interaction if present and no explicit interactions
    if npc.dialogue and #npc.dialogue > 0 and (not npc.interactions or #npc.interactions == 0) then
        registerInteractions(npcId, entity, {
            {
                label = 'Talk',
                icon = 'fas fa-comment',
                onSelect = function(id, ent)
                    showDialogueNode(id, ent, npc.dialogue, 1)
                end,
            },
        })
    end

    -- Relationship
    applyRelationship(entity, npc.relationship)

    -- Walk route
    if npc.walkRoute and #npc.walkRoute > 0 then
        -- Unfreeze for walking
        FreezeEntityPosition(entity, false)
        startWalkRoute(npcId)
    end

    -- Callbacks
    if npc.onSpawn then
        local ok, err = pcall(npc.onSpawn, npcId, entity)
        if not ok then debugLog('onSpawn error: %s', tostring(err)) end
    end

    -- Fire post-spawn hooks
    fireHooks(hooksPost, npcId, entity)

    debugLog('Spawned NPC %s (entity %d)', npcId, entity)
    return entity
end

-- ── Core: Despawn ───────────────────────────────────────────────────────────

function Hydra.NPC.Despawn(npcId)
    local npc = npcs[npcId]
    if not npc then return end
    if not npc.spawned then return end

    stopWalkRoute(npcId)

    local entity = npc.entity

    -- Remove interactions
    if entity then
        unregisterInteractions(entity)
    end

    -- Delete entity
    if entity and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
        debugLog('Despawned NPC %s (entity %d)', npcId, entity)
    end

    -- Release model reference
    if npc._modelHash then
        releaseModel(npc._modelHash)
        npc._modelHash = nil
    end

    -- Fire callback
    if npc.onDespawn then
        local ok, err = pcall(npc.onDespawn, npcId)
        if not ok then debugLog('onDespawn error: %s', tostring(err)) end
    end

    npc.entity = nil
    npc.spawned = false
end

-- ── Core: Create ────────────────────────────────────────────────────────────

function Hydra.NPC.Create(options)
    if not options or not options.model or not options.coords then
        debugLog('Create: Missing required fields (model, coords)')
        return nil
    end

    local npcId = generateId()

    npcs[npcId] = {
        id              = npcId,
        model           = options.model,
        coords          = options.coords,
        heading         = options.heading or (options.coords.w and options.coords.w) or 0.0,
        scenario        = options.scenario,
        anim            = options.anim,
        invincible      = options.invincible ~= nil and options.invincible or cfg.default_invincible,
        frozen          = options.frozen ~= nil and options.frozen or cfg.default_frozen,
        blocking        = options.blocking ~= nil and options.blocking or cfg.default_blocking,
        weapon          = options.weapon,
        components      = options.components,
        props           = options.props,
        networked       = options.networked ~= nil and options.networked or cfg.network_npcs,
        owner           = options.owner,
        tag             = options.tag,
        metadata        = options.metadata or {},
        spawnDistance    = options.spawnDistance or cfg.spawn_distance,
        despawnDistance  = options.despawnDistance or cfg.despawn_distance,
        interactions    = options.interactions,
        dialogue        = options.dialogue,
        walkRoute       = options.walkRoute,
        walkSpeed       = options.walkSpeed or 1.0,
        walkLoop        = options.walkLoop ~= nil and options.walkLoop or true,
        onSpawn         = options.onSpawn,
        onDespawn       = options.onDespawn,
        onInteract      = options.onInteract,
        relationship    = options.relationship,
        spawned         = false,
        entity          = nil,
        _modelHash      = nil,
        _walkThread     = nil,
    }

    debugLog('Created NPC definition %s (model: %s)', npcId, tostring(options.model))
    return npcId
end

-- ── Core: CreateFromTemplate ────────────────────────────────────────────────

function Hydra.NPC.CreateFromTemplate(templateName, coords, overrides)
    local template = cfg.templates and cfg.templates[templateName]
    if not template then
        debugLog('CreateFromTemplate: Template "%s" not found', tostring(templateName))
        return nil
    end

    local merged = {}
    for k, v in pairs(template) do merged[k] = v end
    if overrides then
        for k, v in pairs(overrides) do merged[k] = v end
    end
    merged.coords = coords

    return Hydra.NPC.Create(merged)
end

-- ── Core: Remove ────────────────────────────────────────────────────────────

function Hydra.NPC.Remove(npcId)
    if not npcs[npcId] then return end
    Hydra.NPC.Despawn(npcId)
    npcs[npcId] = nil
    debugLog('Removed NPC %s', npcId)
end

function Hydra.NPC.RemoveByOwner(owner)
    local count = 0
    for npcId, npc in pairs(npcs) do
        if npc.owner == owner then
            Hydra.NPC.Remove(npcId)
            count = count + 1
        end
    end
    debugLog('Removed %d NPCs by owner "%s"', count, tostring(owner))
    return count
end

function Hydra.NPC.RemoveByTag(tag)
    local count = 0
    for npcId, npc in pairs(npcs) do
        if npc.tag == tag then
            Hydra.NPC.Remove(npcId)
            count = count + 1
        end
    end
    debugLog('Removed %d NPCs by tag "%s"', count, tostring(tag))
    return count
end

function Hydra.NPC.RemoveAll()
    local count = 0
    for npcId in pairs(npcs) do
        Hydra.NPC.Remove(npcId)
        count = count + 1
    end
    debugLog('Removed all %d NPCs', count)
    return count
end

-- ── Queries ─────────────────────────────────────────────────────────────────

function Hydra.NPC.IsSpawned(npcId)
    local npc = npcs[npcId]
    return npc ~= nil and npc.spawned == true
end

function Hydra.NPC.Exists(npcId)
    return npcs[npcId] ~= nil
end

function Hydra.NPC.GetEntity(npcId)
    local npc = npcs[npcId]
    if npc and npc.spawned then return npc.entity end
    return nil
end

function Hydra.NPC.Get(npcId)
    local npc = npcs[npcId]
    if not npc then return nil end
    return {
        id             = npc.id,
        model          = npc.model,
        coords         = npc.coords,
        heading        = npc.heading,
        tag            = npc.tag,
        owner          = npc.owner,
        spawned        = npc.spawned,
        entity         = npc.entity,
        metadata       = npc.metadata,
        spawnDistance   = npc.spawnDistance,
        despawnDistance = npc.despawnDistance,
    }
end

function Hydra.NPC.GetAll()
    local result = {}
    for npcId, npc in pairs(npcs) do
        result[npcId] = Hydra.NPC.Get(npcId)
    end
    return result
end

function Hydra.NPC.GetByTag(tag)
    local result = {}
    for npcId, npc in pairs(npcs) do
        if npc.tag == tag then
            result[npcId] = Hydra.NPC.Get(npcId)
        end
    end
    return result
end

function Hydra.NPC.GetNearby(coords, radius)
    local result = {}
    for npcId, npc in pairs(npcs) do
        if vec3Dist(npc.coords, coords) <= radius then
            result[npcId] = Hydra.NPC.Get(npcId)
        end
    end
    return result
end

function Hydra.NPC.GetCount()
    local count = 0
    for _ in pairs(npcs) do count = count + 1 end
    return count
end

function Hydra.NPC.GetSpawnedCount()
    return getSpawnedCount()
end

-- ── Mutators ────────────────────────────────────────────────────────────────

function Hydra.NPC.SetCoords(npcId, coords)
    local npc = npcs[npcId]
    if not npc then return end
    npc.coords = coords
    if npc.spawned and npc.entity and DoesEntityExist(npc.entity) then
        SetEntityCoords(npc.entity, coords.x, coords.y, coords.z, false, false, false, false)
    end
end

function Hydra.NPC.SetHeading(npcId, heading)
    local npc = npcs[npcId]
    if not npc then return end
    npc.heading = heading
    if npc.spawned and npc.entity and DoesEntityExist(npc.entity) then
        SetEntityHeading(npc.entity, heading)
    end
end

function Hydra.NPC.SetScenario(npcId, scenario)
    local npc = npcs[npcId]
    if not npc then return end
    npc.scenario = scenario
    if npc.spawned and npc.entity and DoesEntityExist(npc.entity) then
        if scenario then
            ClearPedTasks(npc.entity)
            TaskStartScenarioInPlace(npc.entity, scenario, 0, true)
        else
            ClearPedTasks(npc.entity)
        end
    end
end

function Hydra.NPC.PlayAnim(npcId, dict, name, flag)
    local npc = npcs[npcId]
    if not npc or not npc.spawned or not npc.entity then return end
    if not DoesEntityExist(npc.entity) then return end

    local entity = npc.entity
    local animApplied = false

    local ok, _ = pcall(function()
        exports['hydra_anims']:PlayAnim(entity, dict, name, flag or -1)
        animApplied = true
    end)

    if not animApplied then
        RequestAnimDict(dict)
        local aStart = GetGameTimer()
        while not HasAnimDictLoaded(dict) do
            if GetGameTimer() - aStart > 2000 then break end
            Citizen.Wait(0)
        end
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(entity, dict, name, 8.0, -8.0, -1, flag or 1, 0, false, false, false)
        end
    end
end

function Hydra.NPC.StopAnim(npcId)
    local npc = npcs[npcId]
    if not npc or not npc.spawned or not npc.entity then return end
    if not DoesEntityExist(npc.entity) then return end
    ClearPedTasks(npc.entity)
end

function Hydra.NPC.SetFrozen(npcId, frozen)
    local npc = npcs[npcId]
    if not npc then return end
    npc.frozen = frozen
    if npc.spawned and npc.entity and DoesEntityExist(npc.entity) then
        FreezeEntityPosition(npc.entity, frozen)
    end
end

function Hydra.NPC.SetInvincible(npcId, invincible)
    local npc = npcs[npcId]
    if not npc then return end
    npc.invincible = invincible
    if npc.spawned and npc.entity and DoesEntityExist(npc.entity) then
        SetEntityInvincible(npc.entity, invincible)
    end
end

function Hydra.NPC.SetVisible(npcId, visible)
    local npc = npcs[npcId]
    if not npc or not npc.spawned or not npc.entity then return end
    if not DoesEntityExist(npc.entity) then return end
    SetEntityVisible(npc.entity, visible, false)
end

function Hydra.NPC.SetWeapon(npcId, weapon)
    local npc = npcs[npcId]
    if not npc then return end
    npc.weapon = weapon
    if npc.spawned and npc.entity and DoesEntityExist(npc.entity) then
        RemoveAllPedWeapons(npc.entity, true)
        if weapon then
            local weapHash = type(weapon) == 'number' and weapon or joaat(weapon)
            GiveWeaponToPed(npc.entity, weapHash, 999, false, true)
        end
    end
end

function Hydra.NPC.LookAt(npcId, coords, duration)
    local npc = npcs[npcId]
    if not npc or not npc.spawned or not npc.entity then return end
    if not DoesEntityExist(npc.entity) then return end
    TaskLookAtCoord(npc.entity, coords.x, coords.y, coords.z, duration or 5000, 2048, 3)
end

function Hydra.NPC.WalkTo(npcId, coords, speed)
    local npc = npcs[npcId]
    if not npc or not npc.spawned or not npc.entity then return end
    if not DoesEntityExist(npc.entity) then return end
    FreezeEntityPosition(npc.entity, false)
    TaskGoToCoordAnyMeans(npc.entity, coords.x, coords.y, coords.z, speed or 1.0, 0, false, 786603, 0.0)
end

function Hydra.NPC.RunTo(npcId, coords)
    Hydra.NPC.WalkTo(npcId, coords, 3.0)
end

function Hydra.NPC.SetRelationship(npcId, relationship)
    local npc = npcs[npcId]
    if not npc then return end
    npc.relationship = relationship
    if npc.spawned and npc.entity and DoesEntityExist(npc.entity) then
        applyRelationship(npc.entity, relationship)
    end
end

-- ── Metadata ────────────────────────────────────────────────────────────────

function Hydra.NPC.SetMetadata(npcId, key, value)
    local npc = npcs[npcId]
    if not npc then return end
    if not npc.metadata then npc.metadata = {} end
    npc.metadata[key] = value
end

function Hydra.NPC.GetMetadata(npcId, key)
    local npc = npcs[npcId]
    if not npc or not npc.metadata then return nil end
    if key then return npc.metadata[key] end
    return npc.metadata
end

-- ── Hooks ───────────────────────────────────────────────────────────────────

function Hydra.NPC.OnPreSpawn(fn)
    if type(fn) == 'function' then
        hooksPre[#hooksPre + 1] = fn
    end
end

function Hydra.NPC.OnPostSpawn(fn)
    if type(fn) == 'function' then
        hooksPost[#hooksPost + 1] = fn
    end
end

function Hydra.NPC.OnInteract(fn)
    if type(fn) == 'function' then
        hooksInteract[#hooksInteract + 1] = fn
    end
end

-- ── Proximity Spawn/Despawn Thread ──────────────────────────────────────────

if cfg.enable_proximity_spawning then
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(cfg.proximity_check_rate or 1000)

            local playerPos = getPlayerCoords()
            local spawnedCount = getSpawnedCount()

            for npcId, npc in pairs(npcs) do
                local dist = vec3Dist(playerPos, npc.coords)

                if npc.spawned then
                    -- Despawn if beyond distance
                    if dist > npc.despawnDistance then
                        Hydra.NPC.Despawn(npcId)
                        spawnedCount = spawnedCount - 1
                        debugLog('Proximity despawn: %s (dist: %.1f)', npcId, dist)
                    end
                else
                    -- Spawn if within distance and under cap
                    if dist <= npc.spawnDistance and spawnedCount < cfg.max_npcs then
                        local entity = Hydra.NPC.Spawn(npcId)
                        if entity then
                            spawnedCount = spawnedCount + 1
                            debugLog('Proximity spawn: %s (dist: %.1f)', npcId, dist)
                        end
                    end
                end
            end
        end
    end)
end

-- ── Cleanup Thread ──────────────────────────────────────────────────────────

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(cfg.cleanup_interval or 15000)

        for npcId, npc in pairs(npcs) do
            if npc.spawned then
                if not npc.entity or not DoesEntityExist(npc.entity) then
                    debugLog('Cleanup: Entity gone for %s, marking despawned', npcId)
                    if npc._modelHash then
                        releaseModel(npc._modelHash)
                        npc._modelHash = nil
                    end
                    stopWalkRoute(npcId)
                    npc.entity = nil
                    npc.spawned = false
                end
            end
        end
    end
end)

-- ── Server Events ───────────────────────────────────────────────────────────

RegisterNetEvent('hydra:npc:create', function(options)
    if not options then return end
    local npcId = Hydra.NPC.Create(options)
    if npcId then
        debugLog('Server-created NPC: %s', npcId)
    end
end)

RegisterNetEvent('hydra:npc:remove', function(npcId)
    if not npcId then return end
    Hydra.NPC.Remove(npcId)
end)

RegisterNetEvent('hydra:npc:removeByTag', function(tag)
    if not tag then return end
    Hydra.NPC.RemoveByTag(tag)
end)

RegisterNetEvent('hydra:npc:removeAll', function()
    Hydra.NPC.RemoveAll()
end)

-- ── Resource Cleanup ────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    debugLog('Resource stopping, cleaning up all NPCs')

    for npcId, npc in pairs(npcs) do
        if npc.spawned and npc.entity and DoesEntityExist(npc.entity) then
            stopWalkRoute(npcId)
            unregisterInteractions(npc.entity)
            SetEntityAsMissionEntity(npc.entity, true, true)
            DeleteEntity(npc.entity)
        end
    end

    -- Release all cached models
    for hash, cache in pairs(modelCache) do
        if HasModelLoaded(hash) then
            SetModelAsNoLongerNeeded(hash)
        end
    end

    npcs = {}
    modelCache = {}
end)

-- ── Exports ─────────────────────────────────────────────────────────────────

exports('Create', function(...) return Hydra.NPC.Create(...) end)
exports('CreateFromTemplate', function(...) return Hydra.NPC.CreateFromTemplate(...) end)
exports('Remove', function(...) return Hydra.NPC.Remove(...) end)
exports('RemoveByOwner', function(...) return Hydra.NPC.RemoveByOwner(...) end)
exports('RemoveByTag', function(...) return Hydra.NPC.RemoveByTag(...) end)
exports('RemoveAll', function(...) return Hydra.NPC.RemoveAll(...) end)
exports('Spawn', function(...) return Hydra.NPC.Spawn(...) end)
exports('Despawn', function(...) return Hydra.NPC.Despawn(...) end)
exports('IsSpawned', function(...) return Hydra.NPC.IsSpawned(...) end)
exports('Exists', function(...) return Hydra.NPC.Exists(...) end)
exports('GetEntity', function(...) return Hydra.NPC.GetEntity(...) end)
exports('Get', function(...) return Hydra.NPC.Get(...) end)
exports('GetAll', function(...) return Hydra.NPC.GetAll(...) end)
exports('GetByTag', function(...) return Hydra.NPC.GetByTag(...) end)
exports('GetNearby', function(...) return Hydra.NPC.GetNearby(...) end)
exports('SetCoords', function(...) return Hydra.NPC.SetCoords(...) end)
exports('SetHeading', function(...) return Hydra.NPC.SetHeading(...) end)
exports('SetScenario', function(...) return Hydra.NPC.SetScenario(...) end)
exports('PlayAnim', function(...) return Hydra.NPC.PlayAnim(...) end)
exports('StopAnim', function(...) return Hydra.NPC.StopAnim(...) end)
exports('SetFrozen', function(...) return Hydra.NPC.SetFrozen(...) end)
exports('SetInvincible', function(...) return Hydra.NPC.SetInvincible(...) end)
exports('SetVisible', function(...) return Hydra.NPC.SetVisible(...) end)
exports('SetWeapon', function(...) return Hydra.NPC.SetWeapon(...) end)
exports('LookAt', function(...) return Hydra.NPC.LookAt(...) end)
exports('WalkTo', function(...) return Hydra.NPC.WalkTo(...) end)
exports('RunTo', function(...) return Hydra.NPC.RunTo(...) end)
exports('SetRelationship', function(...) return Hydra.NPC.SetRelationship(...) end)
exports('SetMetadata', function(...) return Hydra.NPC.SetMetadata(...) end)
exports('GetMetadata', function(...) return Hydra.NPC.GetMetadata(...) end)
exports('OnPreSpawn', function(...) return Hydra.NPC.OnPreSpawn(...) end)
exports('OnPostSpawn', function(...) return Hydra.NPC.OnPostSpawn(...) end)
exports('OnInteract', function(...) return Hydra.NPC.OnInteract(...) end)
exports('GetCount', function(...) return Hydra.NPC.GetCount(...) end)
exports('GetSpawnedCount', function(...) return Hydra.NPC.GetSpawnedCount(...) end)
