--[[
    Hydra Loading Screen - Client

    Handles the manual shutdown of the loading screen
    after the player has fully loaded into the game.
]]

CreateThread(function()
    -- Wait until the player has fully spawned
    while not NetworkIsSessionStarted() do
        Wait(100)
    end

    -- Additional wait to ensure everything is rendered
    Wait(2000)

    -- Trigger the NUI to play exit animation
    SendNUIMessage({ action = 'shutdown' })

    -- Wait for the exit animation to finish
    Wait(1500)

    -- Shut down the loading screen
    ShutdownLoadingScreenNui()
end)
