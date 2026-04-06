--[[
    Hydra Zones - Shared Geometry Math

    Point-in-polygon, point-in-sphere, point-in-box tests.
    Used by both client and server for zone checks.
]]

Hydra = Hydra or {}
Hydra.Zones = Hydra.Zones or {}
Hydra.Zones.Math = {}

--- Point-in-polygon test (2D, ignores Z)
--- Uses ray-casting algorithm - O(n) per vertex count.
--- @param point vector3|table { x, y }
--- @param polygon table[] array of { x, y } vertices
--- @return boolean
function Hydra.Zones.Math.PointInPoly(point, polygon)
    local px, py = point.x, point.y
    local n = #polygon
    local inside = false

    local j = n
    for i = 1, n do
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y

        if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end

    return inside
end

--- Point-in-sphere test (3D)
--- @param point vector3
--- @param center vector3
--- @param radius number
--- @return boolean
function Hydra.Zones.Math.PointInSphere(point, center, radius)
    local dx = point.x - center.x
    local dy = point.y - center.y
    local dz = point.z - center.z
    return (dx * dx + dy * dy + dz * dz) <= (radius * radius)
end

--- Point-in-box test (axis-aligned bounding box, 3D)
--- @param point vector3
--- @param min vector3 bottom-left-back corner
--- @param max vector3 top-right-front corner
--- @return boolean
function Hydra.Zones.Math.PointInBox(point, min, max)
    return point.x >= min.x and point.x <= max.x
       and point.y >= min.y and point.y <= max.y
       and point.z >= min.z and point.z <= max.z
end

--- Point-in-polygon with height check
--- @param point vector3
--- @param polygon table[]
--- @param minZ number
--- @param maxZ number
--- @return boolean
function Hydra.Zones.Math.PointInPolyZone(point, polygon, minZ, maxZ)
    if point.z < minZ or point.z > maxZ then
        return false
    end
    return Hydra.Zones.Math.PointInPoly(point, polygon)
end

--- Distance from point to line segment (2D, for debug drawing)
--- @param point table { x, y }
--- @param a table { x, y }
--- @param b table { x, y }
--- @return number
function Hydra.Zones.Math.DistToSegment(point, a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    local lenSq = dx * dx + dy * dy
    if lenSq == 0 then
        dx = point.x - a.x
        dy = point.y - a.y
        return math.sqrt(dx * dx + dy * dy)
    end

    local t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / lenSq
    t = math.max(0, math.min(1, t))

    local projX = a.x + t * dx
    local projY = a.y + t * dy
    dx = point.x - projX
    dy = point.y - projY
    return math.sqrt(dx * dx + dy * dy)
end
