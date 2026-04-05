--[[
    Hydra Target - Raycast Engine

    Efficient raycast from camera with entity/coordinate results.
    Performs a single shape test per frame when active.
]]

Hydra = Hydra or {}
Hydra.Target = Hydra.Target or {}

--- Perform a raycast from the camera forward
--- @param maxDist number
--- @param flags number (default 30 = peds + vehicles + objects + map)
--- @return bool hit, vec3 endCoords, vec3 surfaceNormal, number entityHit
function Hydra.Target.Raycast(maxDist, flags)
    flags = flags or 30 -- 1=map, 2=vehicles, 4=peds_simple, 8=peds, 16=objects
    local camRot = GetGameplayCamRot(2)
    local camPos = GetGameplayCamCoord()

    -- Direction from camera rotation
    local radX = camRot.x * math.pi / 180.0
    local radZ = camRot.z * math.pi / 180.0
    local cosX = math.cos(radX)

    local dir = vector3(
        -math.sin(radZ) * cosX,
        math.cos(radZ) * cosX,
        math.sin(radX)
    )

    local endPos = camPos + dir * maxDist

    local handle = StartShapeTestLosProbe(
        camPos.x, camPos.y, camPos.z,
        endPos.x, endPos.y, endPos.z,
        flags, PlayerPedId(), 0
    )

    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(handle)
    return hit == 1, endCoords, surfaceNormal, entityHit
end

--- Get the entity type (1=ped, 2=vehicle, 3=object)
--- @param entity number
--- @return number
function Hydra.Target.GetEntityType(entity)
    if not entity or entity == 0 then return 0 end
    return GetEntityType(entity)
end

--- Get the model hash of an entity
--- @param entity number
--- @return number
function Hydra.Target.GetEntityModel(entity)
    if not entity or entity == 0 then return 0 end
    return GetEntityModel(entity)
end
