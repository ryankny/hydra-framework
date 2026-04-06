--[[
    Hydra Bridge - QBox Server Adapter

    QBox (qbx_core) compatibility layer.
    QBox is an evolution of QBCore with some API differences.
]]

Hydra = Hydra or {}

local QBoxBridge = {}

function QBoxBridge.Init()
    -- QBox builds on QBCore patterns but with some differences
    -- Initialize QBCore bridge first for shared functionality
    local qbAdapter = Hydra.Bridge.GetAdapter('qbcore')
    if qbAdapter and qbAdapter.Init then
        qbAdapter.Init()
    end

    -- QBox-specific overrides and additions
    -- qbx_core uses exports primarily instead of the shared object pattern

    -- QBox uses GetPlayer export
    exports('GetPlayer', function(source)
        local Players = Hydra.Use('players')
        if not Players then return nil end
        local data = Players.GetPlayer(source)
        if not data then return nil end
        -- QBox player object is similar to QBCore
        return qbAdapter and qbAdapter._WrapPlayer and qbAdapter._WrapPlayer(source, data) or nil
    end)

    -- QBox login/logout events
    RegisterNetEvent('qbx_core:server:playerLoggedIn')
    RegisterNetEvent('qbx_core:server:playerLoggedOut')

    Hydra.Utils.Log('info', 'QBox bridge adapter initialized (extends QBCore bridge)')
end

Hydra.Bridge.RegisterAdapter('qbox', QBoxBridge)
