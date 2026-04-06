--[[
    Hydra Target - Client Main

    Eye-targeting system. Press keybind to enter target mode,
    raycast to detect entities/zones, show interaction options.
    Developers register targets on entities, models, bones, or
    coordinates. Uses hydra_context for the option menu.
]]

Hydra = Hydra or {}
Hydra.Target = Hydra.Target or {}

local cfg = HydraTargetConfig

-- State
local isActive = false
local currentEntity = 0
local currentCoords = nil
local highlightedEntity = 0

-- Target registries
local entityTargets = {}     -- [netId] = { options }
local modelTargets = {}      -- [modelHash] = { options }
local boneTargets = {}       -- [modelHash] = { [boneIndex] = { options } }
local globalPedTargets = {}  -- Array of option sets that apply to all peds
local globalVehTargets = {}  -- Array of option sets that apply to all vehicles
local globalObjTargets = {}  -- Array of option sets that apply to all objects
local coordTargets = {}      -- Array of { coords, radius, options }

local nextTargetId = 1

--- Generate unique target ID
local function genId()
    local id = nextTargetId
    nextTargetId = nextTargetId + 1
    return id
end

-- =============================================
-- REGISTRATION API
-- =============================================

--- Add target options to a specific entity
--- @param entity number
--- @param options table[] array of option definitions
--- @return number targetId
function Hydra.Target.AddEntity(entity, options)
    local id = genId()
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId == 0 then netId = entity end -- fallback for non-networked

    if not entityTargets[netId] then entityTargets[netId] = {} end
    entityTargets[netId][id] = { options = sanitizeOptions(options), entity = entity }
    return id
end

--- Remove target from a specific entity
--- @param id number targetId
function Hydra.Target.RemoveEntity(id)
    for netId, targets in pairs(entityTargets) do
        if targets[id] then
            targets[id] = nil
            if not next(targets) then entityTargets[netId] = nil end
            return
        end
    end
end

--- Add target options to all entities matching a model
--- @param model string|number model name or hash
--- @param options table[]
--- @return number targetId
function Hydra.Target.AddModel(model, options)
    local id = genId()
    local hash = type(model) == 'string' and GetHashKey(model) or model
    if not modelTargets[hash] then modelTargets[hash] = {} end
    modelTargets[hash][id] = { options = sanitizeOptions(options) }
    return id
end

--- Remove model target
--- @param id number
function Hydra.Target.RemoveModel(id)
    for hash, targets in pairs(modelTargets) do
        if targets[id] then
            targets[id] = nil
            if not next(targets) then modelTargets[hash] = nil end
            return
        end
    end
end

--- Add target options to a bone on a model
--- @param model string|number
--- @param bone number|string bone index or name
--- @param options table[]
--- @return number targetId
function Hydra.Target.AddBone(model, bone, options)
    local id = genId()
    local hash = type(model) == 'string' and GetHashKey(model) or model
    local boneIdx = type(bone) == 'string' and GetHashKey(bone) or bone

    if not boneTargets[hash] then boneTargets[hash] = {} end
    if not boneTargets[hash][boneIdx] then boneTargets[hash][boneIdx] = {} end
    boneTargets[hash][boneIdx][id] = { options = sanitizeOptions(options) }
    return id
end

--- Add target options to all peds
--- @param options table[]
--- @return number targetId
function Hydra.Target.AddGlobalPed(options)
    local id = genId()
    globalPedTargets[id] = { options = sanitizeOptions(options) }
    return id
end

--- Add target options to all vehicles
--- @param options table[]
--- @return number targetId
function Hydra.Target.AddGlobalVehicle(options)
    local id = genId()
    globalVehTargets[id] = { options = sanitizeOptions(options) }
    return id
end

--- Add target options to all objects
--- @param options table[]
--- @return number targetId
function Hydra.Target.AddGlobalObject(options)
    local id = genId()
    globalObjTargets[id] = { options = sanitizeOptions(options) }
    return id
end

--- Remove a global target by id
--- @param id number
function Hydra.Target.RemoveGlobal(id)
    globalPedTargets[id] = nil
    globalVehTargets[id] = nil
    globalObjTargets[id] = nil
end

--- Add target at a coordinate (sphere zone)
--- @param coords vector3
--- @param radius number
--- @param options table[]
--- @return number targetId
function Hydra.Target.AddCoord(coords, radius, options)
    local id = genId()
    coordTargets[id] = {
        coords = coords,
        radius = radius or 1.5,
        options = sanitizeOptions(options),
    }
    return id
end

--- Remove a coord target
--- @param id number
function Hydra.Target.RemoveCoord(id)
    coordTargets[id] = nil
end

-- =============================================
-- OPTION SANITIZATION
-- =============================================

--- Ensure options have the right shape
--- @param options table[]
--- @return table[]
function sanitizeOptions(options)
    local clean = {}
    for i, opt in ipairs(options) do
        clean[i] = {
            label = opt.label or 'Interact',
            icon = opt.icon or nil,
            event = opt.event or nil,
            serverEvent = opt.serverEvent or nil,
            args = opt.args or nil,
            onSelect = opt.onSelect or nil,
            canInteract = opt.canInteract or nil, -- function(entity, coords, args) -> bool
            job = opt.job or nil,       -- string or table of job names
            distance = opt.distance or cfg.max_distance,
        }
    end
    return clean
end

-- =============================================
-- OPTION FILTERING
-- =============================================

--- Filter options by distance and conditions
--- @param options table[]
--- @param entity number|nil
--- @param coords vector3
--- @return table[] filtered
local function filterOptions(options, entity, coords)
    local playerPos = GetEntityCoords(PlayerPedId())
    local filtered = {}

    for _, opt in ipairs(options) do
        local pass = true

        -- Distance check
        local dist = #(playerPos - coords)
        if dist > (opt.distance or cfg.max_distance) then
            pass = false
        end

        -- Job check
        if pass and opt.job then
            local playerJob = nil
            local pData = Hydra.Players and Hydra.Players.GetLocalData and Hydra.Players.GetLocalData()
            if pData and pData.job then
                playerJob = pData.job.name
            end
            if type(opt.job) == 'string' then
                if playerJob ~= opt.job then pass = false end
            elseif type(opt.job) == 'table' then
                local found = false
                for _, j in ipairs(opt.job) do
                    if playerJob == j then found = true; break end
                end
                if not found then pass = false end
            end
        end

        -- canInteract callback
        if pass and opt.canInteract then
            local ok, result = pcall(opt.canInteract, entity, coords, opt.args)
            if not ok or not result then
                pass = false
            end
        end

        if pass then
            filtered[#filtered + 1] = opt
        end
    end

    return filtered
end

-- =============================================
-- GATHER ALL OPTIONS FOR A HIT
-- =============================================

--- Collect all matching options for a raycast hit
--- @param entity number
--- @param coords vector3
--- @return table[]
local function gatherOptions(entity, coords)
    local all = {}

    -- Coord-based targets
    local playerPos = GetEntityCoords(PlayerPedId())
    for _, ct in pairs(coordTargets) do
        if #(playerPos - ct.coords) <= ct.radius then
            for _, opt in ipairs(ct.options) do all[#all + 1] = opt end
        end
    end

    if entity and entity ~= 0 then
        local entType = GetEntityType(entity)
        local modelHash = GetEntityModel(entity)

        -- Entity-specific targets
        local netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or entity
        if entityTargets[netId] then
            for _, t in pairs(entityTargets[netId]) do
                for _, opt in ipairs(t.options) do all[#all + 1] = opt end
            end
        end

        -- Model targets
        if modelTargets[modelHash] then
            for _, t in pairs(modelTargets[modelHash]) do
                for _, opt in ipairs(t.options) do all[#all + 1] = opt end
            end
        end

        -- Global type targets
        if entType == 1 and entity ~= PlayerPedId() then -- Ped
            for _, t in pairs(globalPedTargets) do
                for _, opt in ipairs(t.options) do all[#all + 1] = opt end
            end
        elseif entType == 2 then -- Vehicle
            for _, t in pairs(globalVehTargets) do
                for _, opt in ipairs(t.options) do all[#all + 1] = opt end
            end
        elseif entType == 3 then -- Object
            for _, t in pairs(globalObjTargets) do
                for _, opt in ipairs(t.options) do all[#all + 1] = opt end
            end
        end
    end

    return filterOptions(all, entity, coords)
end

-- =============================================
-- TARGET MODE LOOP
-- =============================================

--- Enable target mode
local function enableTargeting()
    if isActive then return end
    isActive = true
end

--- Disable target mode
local function disableTargeting()
    if not isActive then return end
    isActive = false
    clearHighlight()
    currentEntity = 0
    currentCoords = nil
end

--- Apply highlight to entity
local function applyHighlight(entity)
    if highlightedEntity == entity then return end
    clearHighlight()

    if entity and entity ~= 0 and cfg.highlight.enabled then
        highlightedEntity = entity
        local c = cfg.highlight.color
        SetEntityDrawOutline(entity, true)
        SetEntityDrawOutlineColor(c.r, c.g, c.b, c.a)
    end
end

--- Clear highlight
function clearHighlight()
    if highlightedEntity ~= 0 and DoesEntityExist(highlightedEntity) then
        SetEntityDrawOutline(highlightedEntity, false)
    end
    highlightedEntity = 0
end

-- Keybind registration (via hydra_keybinds if available)
CreateThread(function()
    Wait(500)
    local ok = pcall(function()
        exports['hydra_keybinds']:Register('target', {
            key = cfg.key,
            description = cfg.key_description,
            category = 'interaction',
            module = 'hydra_target',
            isHold = true,
            onPress = enableTargeting,
            onRelease = disableTargeting,
        })
    end)
    if not ok then
        RegisterCommand('+hydra_target', function() enableTargeting() end, false)
        RegisterCommand('-hydra_target', function() disableTargeting() end, false)
        RegisterKeyMapping('+hydra_target', cfg.key_description, 'keyboard', cfg.key)
    end
end)

-- Main target loop
CreateThread(function()
    while true do
        if isActive then
            Wait(cfg.tick_rate)

            local hit, endCoords, _, entityHit = Hydra.Target.Raycast(cfg.max_distance)

            if hit then
                currentEntity = entityHit
                currentCoords = endCoords
                applyHighlight(entityHit)
            else
                currentEntity = 0
                currentCoords = GetEntityCoords(PlayerPedId())
                clearHighlight()
            end

            -- Draw center indicator
            if cfg.draw_sprite then
                DrawSprite('shared', 'emptydot_32', 0.5, 0.5, 0.006, 0.01, 0.0, 108, 92, 231, 200)
            end

            -- Left click to interact
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 140, true) -- Melee
            DisableControlAction(0, 141, true) -- Melee
            DisableControlAction(0, 142, true) -- Melee

            if IsDisabledControlJustPressed(0, 24) then
                local options = gatherOptions(currentEntity, currentCoords or GetEntityCoords(PlayerPedId()))

                if #options > 0 then
                    disableTargeting()
                    showOptions(options, currentEntity, currentCoords)
                end
            end
        else
            Wait(200)
        end
    end
end)

-- =============================================
-- SHOW OPTIONS MENU
-- =============================================

--- Show gathered options (uses hydra_context if available, otherwise raw NUI)
--- @param options table[]
--- @param entity number
--- @param coords vector3
function showOptions(options, entity, coords)
    local items = {}
    for i, opt in ipairs(options) do
        items[i] = {
            label = opt.label,
            icon = opt.icon,
            description = nil,
            args = { option = opt, entity = entity, coords = coords },
            onSelect = function(args)
                local o = args.option
                if o.onSelect then
                    o.onSelect(args.entity, args.coords, o.args)
                end
                if o.event then
                    TriggerEvent(o.event, {
                        entity = args.entity,
                        coords = args.coords,
                        args = o.args,
                    })
                end
                if o.serverEvent then
                    TriggerServerEvent(o.serverEvent, {
                        coords = args.coords,
                        args = o.args,
                    })
                end
            end,
        }
    end

    -- Use hydra_context if available
    if Hydra.Context and Hydra.Context.Show then
        Hydra.Context.Show({
            title = 'Interact',
            items = items,
        })
    else
        -- Fallback: trigger first option directly
        if items[1] and items[1].args then
            local args = items[1].args
            local o = args.option
            if o.onSelect then o.onSelect(entity, coords, o.args) end
            if o.event then TriggerEvent(o.event, { entity = entity, coords = coords, args = o.args }) end
            if o.serverEvent then TriggerServerEvent(o.serverEvent, { coords = coords, args = o.args }) end
        end
    end
end

-- =============================================
-- EXPORTS
-- =============================================

exports('AddEntity', function(...) return Hydra.Target.AddEntity(...) end)
exports('RemoveEntity', function(...) Hydra.Target.RemoveEntity(...) end)
exports('AddModel', function(...) return Hydra.Target.AddModel(...) end)
exports('RemoveModel', function(...) Hydra.Target.RemoveModel(...) end)
exports('AddBone', function(...) return Hydra.Target.AddBone(...) end)
exports('AddGlobalPed', function(...) return Hydra.Target.AddGlobalPed(...) end)
exports('AddGlobalVehicle', function(...) return Hydra.Target.AddGlobalVehicle(...) end)
exports('AddGlobalObject', function(...) return Hydra.Target.AddGlobalObject(...) end)
exports('RemoveGlobal', function(...) Hydra.Target.RemoveGlobal(...) end)
exports('AddCoord', function(...) return Hydra.Target.AddCoord(...) end)
exports('RemoveCoord', function(...) Hydra.Target.RemoveCoord(...) end)
exports('IsActive', function() return isActive end)
exports('Disable', function() disableTargeting() end)
exports('Enable', function() enableTargeting() end)
