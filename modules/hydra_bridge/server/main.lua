--[[
    Hydra Bridge - Server Main

    Registers the bridge as a Hydra module and manages the bridge lifecycle.
]]

Hydra = Hydra or {}

--- Register as Hydra module
Hydra.Modules.Register('bridge', {
    label = 'Hydra Bridge',
    version = '1.0.0',
    author = 'Hydra Framework',
    priority = 85, -- Load after data, before player-facing modules
    dependencies = { 'data' },

    onLoad = function()
        Hydra.Utils.Log('info', 'Bridge system loaded (mode: %s)', Hydra.Bridge.GetMode())
    end,

    onReady = function()
        -- Activate the detected bridge adapter
        local mode = Hydra.Bridge.GetMode()
        local adapter = Hydra.Bridge.GetAdapter(mode)

        if adapter and adapter.Init then
            adapter.Init()
            Hydra.Utils.Log('info', 'Bridge adapter initialized: %s', mode)
        end
    end,

    api = {
        GetMode = Hydra.Bridge.GetMode,
        IsActive = Hydra.Bridge.IsActive,
        GetAdapter = Hydra.Bridge.GetActiveAdapter,
    },
})

-- Exports
exports('GetBridgeMode', function() return Hydra.Bridge.GetMode() end)
exports('IsBridgeActive', function() return Hydra.Bridge.IsActive() end)
