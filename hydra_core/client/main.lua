--[[
    Hydra Framework - Client Main

    Client boot sequence:
    1. Request config from server
    2. Initialize client systems
    3. Notify server we're loaded
    4. Mark ready
]]

Hydra = Hydra or {}

local playerLoaded = false

--- Boot sequence
CreateThread(function()
    -- Wait for game to be ready
    while not NetworkIsSessionStarted() do
        Wait(100)
    end

    Hydra.Utils.Log('info', 'Hydra client initializing...')

    -- Request config from server
    Hydra.Events.EmitServer('requestConfig')

    -- Wait for config
    local timeout = GetGameTimer() + 10000
    while not Hydra.Config.IsLoaded() and GetGameTimer() < timeout do
        Wait(100)
    end

    if not Hydra.Config.IsLoaded() then
        Hydra.Utils.Log('warn', 'Config load timed out, using defaults')
    end

    -- Initialize client callbacks
    if Hydra.ClientCallbacks and Hydra.ClientCallbacks.Init then
        Hydra.ClientCallbacks.Init()
    end

    -- Mark framework ready on client (modules can start waiting for events)
    Hydra._SetReady()

    -- Ensure screen is faded out before identity/spawn takes over
    if not IsScreenFadedOut() then
        DoScreenFadeOut(0)
    end

    -- Tell server we're loaded — this triggers identity/character selection
    TriggerServerEvent('hydra:playerLoaded')
    playerLoaded = true

    -- Safety net: if nothing fades the screen in within 30 seconds, force it
    SetTimeout(30000, function()
        if IsScreenFadedOut() or not IsScreenFadingIn() then
            DoScreenFadeIn(1000)
            Hydra.Utils.Log('warn', 'Safety fade-in triggered — identity/spawn may have failed')
        end
    end)
end)

--- Receive config from server
Hydra.Events.Register('receiveConfig', function(config)
    if config then
        Hydra.Config.Load(config)
        Hydra.Utils.Log('debug', 'Received server config')
    end
end)

--- Check if local player is loaded
--- @return boolean
function Hydra.IsPlayerLoaded()
    return playerLoaded
end

--- Get local player server ID
--- @return number
function Hydra.GetPlayerId()
    return GetPlayerServerId(PlayerId())
end

--- Get local player ped
--- @return number
function Hydra.GetPlayerPed()
    return PlayerPedId()
end

--- Get local player coords
--- @param includeHeading boolean
--- @return vector3|vector4
function Hydra.GetPlayerCoords(includeHeading)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    if includeHeading then
        return vector4(coords.x, coords.y, coords.z, GetEntityHeading(ped))
    end
    return coords
end
