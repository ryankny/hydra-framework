--[[
    Hydra Object - Client

    Centralized prop/object spawning, attachment, tracking, and
    cleanup. Prevents orphaned entities from jobs, interactions,
    scenes, and animations. Every spawned object is tracked by
    owner, tag, and creation time for reliable lifecycle management.
]]

Hydra = Hydra or {}
Hydra.Object = {}

local cfg = HydraConfig.Object
if not cfg.enabled then return end

-- ── Internal State ──

local objects = {}          -- { [objId] = { entity, model, owner, tag, coords, attached, frozen, createdAt, ... } }
local modelCache = {}       -- { [hash] = { refCount, lastUsed, loaded } }
local objCounter = 0
local hooksPre = {}         -- Pre-spawn hooks
local hooksPost = {}        -- Post-spawn hooks
local hooksDelete = {}      -- On-delete hooks

-- ── Helpers ──

local function dbg(msg, ...)
    if cfg.debug then
        print(('[hydra_object] ' .. msg):format(...))
    end
end

local function nextId()
    objCounter = objCounter + 1
    return 'obj_' .. objCounter
end

local function getHash(model)
    if type(model) == 'number' then return model end
    return GetHashKey(model)
end

local function objectCount()
    local n = 0
    for _ in pairs(objects) do n = n + 1 end
    return n
end

local function countByOwner(owner)
    if not owner then return 0 end
    local n = 0
    for _, obj in pairs(objects) do
        if obj.owner == owner then n = n + 1 end
    end
    return n
end

-- ── Model Loading (Cached, Ref-Counted) ──

local function evictModels()
    local evictable = {}
    for hash, entry in pairs(modelCache) do
        if entry.refCount <= 0 then
            evictable[#evictable + 1] = { hash = hash, lastUsed = entry.lastUsed }
        end
    end
    if #evictable == 0 then return end

    table.sort(evictable, function(a, b) return a.lastUsed < b.lastUsed end)

    local toEvict = math.max(1, math.floor(#evictable * 0.1))
    for i = 1, toEvict do
        local hash = evictable[i].hash
        SetModelAsNoLongerNeeded(hash)
        modelCache[hash] = nil
        dbg('Evicted model %s', hash)
    end
end

local function loadModel(model)
    local hash = getHash(model)
    local entry = modelCache[hash]

    if entry and entry.loaded then
        entry.refCount = entry.refCount + 1
        entry.lastUsed = GetGameTimer()
        return hash
    end

    if not IsModelValid(hash) then
        dbg('Invalid model: %s', tostring(model))
        return nil
    end

    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < cfg.model_timeout do
        Wait(10)
        t = t + 10
    end

    if not HasModelLoaded(hash) then
        dbg('Model load timeout: %s (%dms)', tostring(model), cfg.model_timeout)
        return nil
    end

    -- Evict if cache full
    local count = 0
    for _ in pairs(modelCache) do count = count + 1 end
    if count >= cfg.model_cache_size then
        evictModels()
    end

    modelCache[hash] = { refCount = 1, lastUsed = GetGameTimer(), loaded = true }
    return hash
end

local function releaseModel(hash)
    local entry = modelCache[hash]
    if entry then
        entry.refCount = math.max(0, entry.refCount - 1)
    end
end

-- ── Pre-load Models (Bulk) ──

function Hydra.Object.Preload(models)
    if type(models) ~= 'table' then return end
    for _, model in ipairs(models) do
        loadModel(model)
    end
end

-- ── Core: Spawn Object ──

function Hydra.Object.Create(options)
    if not options or not options.model then
        dbg('Create called without model')
        return nil
    end

    -- Enforce limits
    if objectCount() >= cfg.max_objects then
        dbg('Max objects reached (%d)', cfg.max_objects)
        return nil
    end

    if options.owner and countByOwner(options.owner) >= cfg.max_per_owner then
        dbg('Max objects for owner "%s" reached (%d)', options.owner, cfg.max_per_owner)
        return nil
    end

    -- Pre-spawn hooks
    for _, hook in ipairs(hooksPre) do
        if hook(options) == false then
            dbg('Pre-spawn hook cancelled creation')
            return nil
        end
    end

    -- Load model
    local hash = loadModel(options.model)
    if not hash then return nil end

    -- Resolve position
    local coords = options.coords
    if not coords then
        local ped = PlayerPedId()
        coords = GetEntityCoords(ped)
    end

    if options.snapToGround then
        local ground = Hydra.Object.GetGroundCoords(coords)
        if ground then coords = ground end
    end

    -- Spawn
    local isNetwork = options.network ~= nil and options.network or cfg.default_network
    local entity = CreateObject(hash, coords.x, coords.y, coords.z, isNetwork, true, false)

    if not entity or entity == 0 then
        dbg('CreateObject returned invalid entity')
        releaseModel(hash)
        return nil
    end

    -- Rotation
    if options.rotation then
        SetEntityRotation(entity, options.rotation.x, options.rotation.y, options.rotation.z, 2, true)
    elseif options.heading then
        SetEntityHeading(entity, options.heading)
    end

    -- Collision
    if options.collision ~= nil then
        SetEntityCollision(entity, options.collision, options.collision)
    elseif not cfg.default_collision then
        SetEntityCollision(entity, false, false)
    end

    -- Freeze
    local frozen = options.freeze ~= nil and options.freeze or cfg.default_freeze
    if frozen then
        FreezeEntityPosition(entity, true)
    end

    -- LOD
    if options.lodDistance then
        SetEntityLodDist(entity, math.floor(options.lodDistance))
    elseif cfg.default_lod_distance ~= 200.0 then
        SetEntityLodDist(entity, math.floor(cfg.default_lod_distance))
    end

    -- Invincible
    if options.invincible then
        SetEntityInvincible(entity, true)
    end

    -- Alpha / transparency
    if options.alpha and options.alpha < 255 then
        SetEntityAlpha(entity, options.alpha, false)
    end

    -- Visibility
    if options.visible == false then
        SetEntityVisible(entity, false, false)
    end

    -- Register
    local objId = nextId()
    objects[objId] = {
        entity = entity,
        model = hash,
        modelName = tostring(options.model),
        owner = options.owner or GetCurrentResourceName(),
        tag = options.tag,
        coords = coords,
        rotation = options.rotation,
        attached = false,
        attachTarget = nil,
        frozen = frozen,
        network = isNetwork,
        createdAt = GetGameTimer(),
        metadata = options.metadata,
        onDelete = options.onDelete,
    }

    -- Post-spawn hooks
    for _, hook in ipairs(hooksPost) do
        hook(objId, entity, options)
    end

    dbg('Created object %s (entity=%d model=%s owner=%s tag=%s)',
        objId, entity, tostring(options.model), objects[objId].owner, tostring(options.tag))

    return objId, entity
end

-- ── Attach to Entity ──

function Hydra.Object.Attach(objId, targetEntity, options)
    local obj = objects[objId]
    if not obj then return false end
    if not DoesEntityExist(obj.entity) then
        Hydra.Object.Remove(objId)
        return false
    end
    if not DoesEntityExist(targetEntity) then return false end

    local opts = options or {}
    local offset = opts.offset or vector3(0.0, 0.0, 0.0)
    local rotation = opts.rotation or vector3(0.0, 0.0, 0.0)
    local bone = opts.bone

    if bone and IsEntityAPed(targetEntity) then
        bone = GetPedBoneIndex(targetEntity, bone)
    else
        bone = 0
    end

    AttachEntityToEntity(obj.entity, targetEntity, bone,
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        true, true, false, true, 1, true)

    obj.attached = true
    obj.attachTarget = targetEntity

    dbg('Attached %s to entity %d (bone=%s)', objId, targetEntity, tostring(opts.bone))
    return true
end

-- ── Detach from Entity ──

function Hydra.Object.Detach(objId, options)
    local obj = objects[objId]
    if not obj or not obj.attached then return false end
    if not DoesEntityExist(obj.entity) then
        Hydra.Object.Remove(objId)
        return false
    end

    DetachEntity(obj.entity, true, true)
    obj.attached = false
    obj.attachTarget = nil

    local opts = options or {}
    if opts.freeze then
        FreezeEntityPosition(obj.entity, true)
        obj.frozen = true
    end
    if opts.coords then
        SetEntityCoords(obj.entity, opts.coords.x, opts.coords.y, opts.coords.z, false, false, false, false)
    end

    dbg('Detached %s', objId)
    return true
end

-- ── Create + Attach Shorthand ──

function Hydra.Object.CreateAttached(targetEntity, options)
    if not options or not options.model then return nil end
    if not DoesEntityExist(targetEntity) then return nil end

    local objId, entity = Hydra.Object.Create(options)
    if not objId then return nil end

    local ok = Hydra.Object.Attach(objId, targetEntity, {
        bone = options.bone,
        offset = options.offset or vector3(0.0, 0.0, 0.0),
        rotation = options.rotation or vector3(0.0, 0.0, 0.0),
    })

    if not ok then
        Hydra.Object.Remove(objId)
        return nil
    end

    return objId, entity
end

-- ── Remove / Delete ──

function Hydra.Object.Remove(objId)
    local obj = objects[objId]
    if not obj then return false end

    -- Fire delete hooks
    for _, hook in ipairs(hooksDelete) do
        hook(objId, obj.entity, obj)
    end

    -- Fire per-object callback
    if obj.onDelete then
        pcall(obj.onDelete, objId, obj.entity)
    end

    -- Detach if attached
    if obj.attached and DoesEntityExist(obj.entity) then
        DetachEntity(obj.entity, true, true)
    end

    -- Delete entity
    if DoesEntityExist(obj.entity) then
        SetEntityAsMissionEntity(obj.entity, true, true)
        DeleteEntity(obj.entity)
    end

    -- Release model ref
    releaseModel(obj.model)

    objects[objId] = nil
    dbg('Removed object %s', objId)
    return true
end

-- ── Bulk Removal ──

function Hydra.Object.RemoveByOwner(owner)
    local removed = 0
    local toRemove = {}
    for id, obj in pairs(objects) do
        if obj.owner == owner then
            toRemove[#toRemove + 1] = id
        end
    end
    for _, id in ipairs(toRemove) do
        Hydra.Object.Remove(id)
        removed = removed + 1
    end
    dbg('Removed %d objects for owner "%s"', removed, owner)
    return removed
end

function Hydra.Object.RemoveByTag(tag)
    local removed = 0
    local toRemove = {}
    for id, obj in pairs(objects) do
        if obj.tag == tag then
            toRemove[#toRemove + 1] = id
        end
    end
    for _, id in ipairs(toRemove) do
        Hydra.Object.Remove(id)
        removed = removed + 1
    end
    dbg('Removed %d objects with tag "%s"', removed, tag)
    return removed
end

function Hydra.Object.RemoveAll()
    local toRemove = {}
    for id in pairs(objects) do
        toRemove[#toRemove + 1] = id
    end
    for _, id in ipairs(toRemove) do
        Hydra.Object.Remove(id)
    end
    dbg('Removed all %d objects', #toRemove)
    return #toRemove
end

-- ── Query API ──

function Hydra.Object.Get(objId)
    local obj = objects[objId]
    if not obj then return nil end
    return {
        id = objId,
        entity = obj.entity,
        model = obj.modelName,
        owner = obj.owner,
        tag = obj.tag,
        attached = obj.attached,
        frozen = obj.frozen,
        createdAt = obj.createdAt,
        metadata = obj.metadata,
    }
end

function Hydra.Object.GetEntity(objId)
    local obj = objects[objId]
    return obj and obj.entity or nil
end

function Hydra.Object.Exists(objId)
    local obj = objects[objId]
    if not obj then return false end
    if not DoesEntityExist(obj.entity) then
        objects[objId] = nil
        releaseModel(obj.model)
        return false
    end
    return true
end

function Hydra.Object.GetAll()
    local result = {}
    for id in pairs(objects) do
        result[#result + 1] = id
    end
    return result
end

function Hydra.Object.GetByOwner(owner)
    local result = {}
    for id, obj in pairs(objects) do
        if obj.owner == owner then
            result[#result + 1] = id
        end
    end
    return result
end

function Hydra.Object.GetByTag(tag)
    local result = {}
    for id, obj in pairs(objects) do
        if obj.tag == tag then
            result[#result + 1] = id
        end
    end
    return result
end

function Hydra.Object.GetCount(owner)
    if owner then return countByOwner(owner) end
    return objectCount()
end

function Hydra.Object.GetNearby(coords, radius)
    local result = {}
    local r2 = radius * radius
    for id, obj in pairs(objects) do
        if DoesEntityExist(obj.entity) then
            local objCoords = GetEntityCoords(obj.entity)
            local dx = objCoords.x - coords.x
            local dy = objCoords.y - coords.y
            local dz = objCoords.z - coords.z
            if (dx * dx + dy * dy + dz * dz) <= r2 then
                result[#result + 1] = { id = id, entity = obj.entity, distance = math.sqrt(dx * dx + dy * dy + dz * dz) }
            end
        end
    end
    table.sort(result, function(a, b) return a.distance < b.distance end)
    return result
end

-- ── Modify Existing Objects ──

function Hydra.Object.SetCoords(objId, coords)
    local obj = objects[objId]
    if not obj or not DoesEntityExist(obj.entity) then return false end
    SetEntityCoords(obj.entity, coords.x, coords.y, coords.z, false, false, false, false)
    obj.coords = coords
    return true
end

function Hydra.Object.SetRotation(objId, rotation)
    local obj = objects[objId]
    if not obj or not DoesEntityExist(obj.entity) then return false end
    SetEntityRotation(obj.entity, rotation.x, rotation.y, rotation.z, 2, true)
    obj.rotation = rotation
    return true
end

function Hydra.Object.SetHeading(objId, heading)
    local obj = objects[objId]
    if not obj or not DoesEntityExist(obj.entity) then return false end
    SetEntityHeading(obj.entity, heading)
    return true
end

function Hydra.Object.Freeze(objId, frozen)
    local obj = objects[objId]
    if not obj or not DoesEntityExist(obj.entity) then return false end
    FreezeEntityPosition(obj.entity, frozen)
    obj.frozen = frozen
    return true
end

function Hydra.Object.SetVisible(objId, visible)
    local obj = objects[objId]
    if not obj or not DoesEntityExist(obj.entity) then return false end
    SetEntityVisible(obj.entity, visible, false)
    return true
end

function Hydra.Object.SetAlpha(objId, alpha)
    local obj = objects[objId]
    if not obj or not DoesEntityExist(obj.entity) then return false end
    SetEntityAlpha(obj.entity, alpha, false)
    return true
end

function Hydra.Object.SetCollision(objId, enabled)
    local obj = objects[objId]
    if not obj or not DoesEntityExist(obj.entity) then return false end
    SetEntityCollision(obj.entity, enabled, enabled)
    return true
end

function Hydra.Object.SetInvincible(objId, invincible)
    local obj = objects[objId]
    if not obj or not DoesEntityExist(obj.entity) then return false end
    SetEntityInvincible(obj.entity, invincible)
    return true
end

function Hydra.Object.SetMetadata(objId, key, value)
    local obj = objects[objId]
    if not obj then return false end
    if not obj.metadata then obj.metadata = {} end
    obj.metadata[key] = value
    return true
end

function Hydra.Object.GetMetadata(objId, key)
    local obj = objects[objId]
    if not obj or not obj.metadata then return nil end
    return obj.metadata[key]
end

-- ── Ground Snap Utility ──

function Hydra.Object.GetGroundCoords(coords)
    local start = vector3(coords.x, coords.y, coords.z + 2.0)
    local target = vector3(coords.x, coords.y, coords.z - cfg.ground_raycast_distance)
    local ray = StartShapeTestRay(start.x, start.y, start.z, target.x, target.y, target.z, 1 + 16, PlayerPedId(), 0)
    local _, hit, hitCoords = GetShapeTestResult(ray)

    if hit == 1 then
        return vector3(hitCoords.x, hitCoords.y, hitCoords.z + cfg.ground_snap_offset)
    end

    -- Fallback: native ground Z
    local foundZ, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 5.0, false)
    if foundZ then
        return vector3(coords.x, coords.y, groundZ + cfg.ground_snap_offset)
    end

    return nil
end

-- ── Hooks ──

function Hydra.Object.OnPreCreate(fn)
    hooksPre[#hooksPre + 1] = fn
end

function Hydra.Object.OnPostCreate(fn)
    hooksPost[#hooksPost + 1] = fn
end

function Hydra.Object.OnDelete(fn)
    hooksDelete[#hooksDelete + 1] = fn
end

-- ── Validation Thread (detect deleted entities) ──

CreateThread(function()
    while true do
        Wait(cfg.validate_interval)

        local invalid = {}
        for id, obj in pairs(objects) do
            if not DoesEntityExist(obj.entity) then
                invalid[#invalid + 1] = id
            elseif obj.attached and obj.attachTarget and not DoesEntityExist(obj.attachTarget) then
                -- Attachment target gone — orphaned prop
                invalid[#invalid + 1] = id
            end
        end

        for _, id in ipairs(invalid) do
            dbg('Auto-removing invalid/orphaned object %s', id)
            Hydra.Object.Remove(id)
        end
    end
end)

-- ── Model Cache Cleanup Thread ──

CreateThread(function()
    while true do
        Wait(cfg.cleanup_interval)

        local now = GetGameTimer()
        local evicted = 0

        for hash, entry in pairs(modelCache) do
            if entry.refCount <= 0 and (now - entry.lastUsed) > 60000 then
                SetModelAsNoLongerNeeded(hash)
                modelCache[hash] = nil
                evicted = evicted + 1
            end
        end

        if evicted > 0 then
            dbg('Cache cleanup: evicted %d unused models', evicted)
        end
    end
end)

-- ── Orphan Cleanup Thread ──

if cfg.orphan_timeout > 0 then
    CreateThread(function()
        while true do
            Wait(cfg.cleanup_interval)

            local now = GetGameTimer()
            local orphans = {}

            for id, obj in pairs(objects) do
                -- Only auto-clean objects without an owner tag (truly orphaned)
                if not obj.tag and (now - obj.createdAt) > cfg.orphan_timeout then
                    orphans[#orphans + 1] = id
                end
            end

            for _, id in ipairs(orphans) do
                dbg('Auto-removing orphaned object %s (age > %ds)', id, cfg.orphan_timeout / 1000)
                Hydra.Object.Remove(id)
            end
        end
    end)
end

-- ── Resource Stop Cleanup ──

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        -- Full cleanup on own stop
        for id in pairs(objects) do
            local obj = objects[id]
            if obj and DoesEntityExist(obj.entity) then
                if obj.attached then DetachEntity(obj.entity, true, true) end
                SetEntityAsMissionEntity(obj.entity, true, true)
                DeleteEntity(obj.entity)
            end
        end
        objects = {}

        for hash in pairs(modelCache) do
            SetModelAsNoLongerNeeded(hash)
        end
        modelCache = {}
        return
    end

    -- Clean objects owned by stopping resource
    if cfg.cleanup_on_owner_stop then
        local removed = 0
        local toRemove = {}
        for id, obj in pairs(objects) do
            if obj.owner == resource then
                toRemove[#toRemove + 1] = id
            end
        end
        for _, id in ipairs(toRemove) do
            Hydra.Object.Remove(id)
            removed = removed + 1
        end
        if removed > 0 then
            dbg('Cleaned %d objects owned by stopping resource "%s"', removed, resource)
        end
    end
end)

-- ── Server Event Handlers ──

RegisterNetEvent('hydra:object:create')
AddEventHandler('hydra:object:create', function(options)
    Hydra.Object.Create(options)
end)

RegisterNetEvent('hydra:object:removeByTag')
AddEventHandler('hydra:object:removeByTag', function(tag)
    Hydra.Object.RemoveByTag(tag)
end)

RegisterNetEvent('hydra:object:removeAll')
AddEventHandler('hydra:object:removeAll', function()
    Hydra.Object.RemoveAll()
end)

-- ── Exports ──

exports('Create', function(options) return Hydra.Object.Create(options) end)
exports('CreateAttached', function(target, options) return Hydra.Object.CreateAttached(target, options) end)
exports('Remove', function(id) return Hydra.Object.Remove(id) end)
exports('RemoveByOwner', function(owner) return Hydra.Object.RemoveByOwner(owner) end)
exports('RemoveByTag', function(tag) return Hydra.Object.RemoveByTag(tag) end)
exports('RemoveAll', function() return Hydra.Object.RemoveAll() end)
exports('Attach', function(id, target, opts) return Hydra.Object.Attach(id, target, opts) end)
exports('Detach', function(id, opts) return Hydra.Object.Detach(id, opts) end)
exports('Get', function(id) return Hydra.Object.Get(id) end)
exports('GetEntity', function(id) return Hydra.Object.GetEntity(id) end)
exports('Exists', function(id) return Hydra.Object.Exists(id) end)
exports('GetAll', function() return Hydra.Object.GetAll() end)
exports('GetByOwner', function(owner) return Hydra.Object.GetByOwner(owner) end)
exports('GetByTag', function(tag) return Hydra.Object.GetByTag(tag) end)
exports('GetCount', function(owner) return Hydra.Object.GetCount(owner) end)
exports('GetNearby', function(coords, radius) return Hydra.Object.GetNearby(coords, radius) end)
exports('SetCoords', function(id, c) return Hydra.Object.SetCoords(id, c) end)
exports('SetRotation', function(id, r) return Hydra.Object.SetRotation(id, r) end)
exports('SetHeading', function(id, h) return Hydra.Object.SetHeading(id, h) end)
exports('Freeze', function(id, f) return Hydra.Object.Freeze(id, f) end)
exports('SetVisible', function(id, v) return Hydra.Object.SetVisible(id, v) end)
exports('SetAlpha', function(id, a) return Hydra.Object.SetAlpha(id, a) end)
exports('SetCollision', function(id, e) return Hydra.Object.SetCollision(id, e) end)
exports('SetInvincible', function(id, i) return Hydra.Object.SetInvincible(id, i) end)
exports('SetMetadata', function(id, k, v) return Hydra.Object.SetMetadata(id, k, v) end)
exports('GetMetadata', function(id, k) return Hydra.Object.GetMetadata(id, k) end)
exports('GetGroundCoords', function(c) return Hydra.Object.GetGroundCoords(c) end)
exports('Preload', function(models) return Hydra.Object.Preload(models) end)
exports('OnPreCreate', function(fn) return Hydra.Object.OnPreCreate(fn) end)
exports('OnPostCreate', function(fn) return Hydra.Object.OnPostCreate(fn) end)
exports('OnDelete', function(fn) return Hydra.Object.OnDelete(fn) end)
