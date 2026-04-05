--[[
    Hydra Bridge - Client Main

    Sets up client-side bridge adapters.
    Receives bridge mode from server and activates appropriate adapter.
]]

Hydra = Hydra or {}

--- Receive bridge mode from server
RegisterNetEvent('hydra:bridge:setMode')
AddEventHandler('hydra:bridge:setMode', function(mode)
    Hydra.Bridge.SetMode(mode)

    local adapter = Hydra.Bridge.GetAdapter(mode)
    if adapter and adapter.Init then
        adapter.Init()
    end
end)

--- Request bridge mode when client loads
CreateThread(function()
    while not Hydra.IsReady() do Wait(100) end
    TriggerServerEvent('hydra:bridge:requestMode')
end)

--- Server responds with bridge mode
RegisterNetEvent('hydra:bridge:mode')
AddEventHandler('hydra:bridge:mode', function(mode)
    Hydra.Bridge.SetMode(mode)
    local adapter = Hydra.Bridge.GetAdapter(mode)
    if adapter and adapter.Init then
        adapter.Init()
    end
end)
