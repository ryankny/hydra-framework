--[[
    Hydra Framework - Client Main

    Clean boot sequence:
    1. Wait for session
    2. Wait for loading screen to fully close
    3. Request config from server
    4. Mark framework ready
    5. Tell server we're loaded (triggers identity/spawn)
]]

Hydra = Hydra or {}

local playerLoaded = false

--- Boot sequence
CreateThread(function()
    -- Step 1: Wait for network session
    while not NetworkIsSessionStarted() do
        Wait(100)
    end

    Hydra.Utils.Log('info', 'Hydra client initializing...')

    -- Step 2: Wait for the loading screen to fully shut down
    -- This ensures a clean handoff — no overlap with character selection
    while GetIsLoadingScreenActive() do
        Wait(100)
    end
    -- Extra wait for the NUI fade animation to complete
    Wait(2000)

    -- Step 3: Request config from server
    Hydra.Events.EmitServer('requestConfig')

    local timeout = GetGameTimer() + 10000
    while not Hydra.Config.IsLoaded() and GetGameTimer() < timeout do
        Wait(100)
    end

    if not Hydra.Config.IsLoaded() then
        Hydra.Utils.Log('warn', 'Config load timed out, using defaults')
    end

    -- Step 4: Initialize client callbacks
    if Hydra.ClientCallbacks and Hydra.ClientCallbacks.Init then
        Hydra.ClientCallbacks.Init()
    end

    -- Step 5: Mark framework ready
    Hydra._SetReady()

    -- Step 6: Tell server we're loaded
    -- Identity module will receive this and show character selection
    TriggerServerEvent('hydra:playerLoaded')
    playerLoaded = true

    -- Safety net: if nothing happens within 60 seconds, force fade in
    SetTimeout(60000, function()
        if IsScreenFadedOut() then
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
