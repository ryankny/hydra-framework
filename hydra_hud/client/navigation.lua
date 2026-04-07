--[[
    Hydra HUD - Navigation Display

    Provides compass direction, street name, zone, and time.
    Updates efficiently with change detection.
]]

Hydra = Hydra or {}
Hydra.HUD = Hydra.HUD or {}

local lastNavData = {}
local DIRECTIONS = { 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'N' }

--- Get cardinal direction from heading
--- @param heading number 0-360
--- @return string
local function getDirection(heading)
    local index = math.floor(((heading + 22.5) % 360) / 45) + 1
    return DIRECTIONS[index] or 'N'
end

--- Get the current street name
--- @param coords vector3
--- @return string streetName
--- @return string crossingName
local function getStreetNames(coords)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash) or ''
    local crossing = ''
    if crossingHash and crossingHash ~= 0 then
        crossing = GetStreetNameFromHashKey(crossingHash) or ''
    end
    return street, crossing
end

--- Get the current zone name
--- @param coords vector3
--- @return string
local function getZoneName(coords)
    local zoneHash = GetNameOfZone(coords.x, coords.y, coords.z)
    return GetLabelText(zoneHash) or zoneHash or ''
end

--- Get formatted game time
--- @return string
local function getGameTime()
    local h = GetClockHours()
    local m = GetClockMinutes()
    local format = HydraHUDConfig.navigation.time_format or '12h'

    if format == '12h' then
        local period = h >= 12 and 'PM' or 'AM'
        h = h % 12
        if h == 0 then h = 12 end
        return string.format('%d:%02d %s', h, m, period)
    else
        return string.format('%02d:%02d', h, m)
    end
end

--- Check if navigation data changed
local function hasChanged(newData, oldData)
    if not oldData then return true end
    for k, v in pairs(newData) do
        if oldData[k] ~= v then return true end
    end
    return false
end

--- Compass heading update (fast — runs every frame for smooth compass)
CreateThread(function()
    -- Wait for HUD to become visible (not IsReady which may fail cross-resource)
    while not Hydra.HUD.IsVisible() do Wait(500) end

    local navConfig = HydraHUDConfig.navigation or {}
    if not navConfig.enabled then return end

    local lastHeading = -1

    while true do
        if Hydra.HUD.IsVisible() then
            -- Use camera rotation for compass (matches what player sees)
            local camRot = GetGameplayCamRot(2)
            local heading = (360.0 - camRot.z) % 360.0
            local rounded = math.floor(heading)

            if rounded ~= lastHeading then
                Hydra.HUD.Send('navUpdate', {
                    heading = rounded,
                    direction = getDirection(heading),
                })
                lastHeading = rounded
            end
        end
        Wait(0) -- Every frame for smooth compass
    end
end)

--- Street/zone/time update (slow — doesn't change often)
CreateThread(function()
    while not Hydra.HUD.IsVisible() do Wait(500) end

    local navConfig = HydraHUDConfig.navigation or {}
    if not navConfig.enabled then return end

    local lastStreet, lastZone = '', ''

    while true do
        if Hydra.HUD.IsVisible() then
            local coords = GetEntityCoords(PlayerPedId())
            local street, crossing = getStreetNames(coords)
            local zone = getZoneName(coords)
            local time = getGameTime()

            if street ~= lastStreet or zone ~= lastZone then
                Hydra.HUD.Send('navUpdate', {
                    street = street,
                    crossing = crossing,
                    zone = zone,
                    time = time,
                })
                lastStreet = street
                lastZone = zone
            end
        end
        Wait(1000) -- Street names don't change fast
    end
end)
