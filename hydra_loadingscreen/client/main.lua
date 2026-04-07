--[[
    Hydra Loading Screen - Client

    Handles the shutdown of both the native GTA loading screen
    and the custom NUI loading screen.

    Flow:
    1. Wait for session to start
    2. Kill native GTA "Loading Story Mode" screen
    3. Play NUI exit animation
    4. Kill the NUI loading screen

    After this completes, hydra_core fires hydra:playerLoaded
    which triggers identity/character selection.
]]

CreateThread(function()
    -- Wait until network session is active
    while not NetworkIsSessionStarted() do
        Wait(100)
    end

    -- Kill the native GTA "Loading Story Mode" screen immediately
    ShutdownLoadingScreen()

    -- Let the custom NUI loading screen show for a moment
    Wait(1500)

    -- Trigger the NUI to play its exit animation
    SendNUIMessage({ action = 'shutdown' })

    -- Wait for the exit animation to complete
    Wait(1500)

    -- Kill the custom NUI loading screen
    ShutdownLoadingScreenNui()
end)
