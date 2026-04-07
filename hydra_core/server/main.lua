--[[
    Hydra Framework - Server Main

    Boot sequence:
    1. Load configuration
    2. Initialize security system
    3. Initialize callback system
    4. Load all registered modules
    5. Mark framework as ready
]]

Hydra = Hydra or {}

local bootStart = GetGameTimer()

--- Boot sequence
CreateThread(function()
    Hydra.Utils.Log('info', '========================================')
    Hydra.Utils.Log('info', '  Hydra Framework v1.0.0')
    Hydra.Utils.Log('info', '  High-Performance FiveM Framework')
    Hydra.Utils.Log('info', '========================================')

    -- Step 1: Load configuration
    Hydra.Utils.Log('info', 'Loading configuration...')
    local defaultConfig = HydraConfig and HydraConfig.Default or {}
    Hydra.Config.Load(defaultConfig)

    -- Step 1b: Apply server.cfg convar overrides immediately
    if Hydra.ConfigManager and Hydra.ConfigManager.LoadConvars then
        Hydra.ConfigManager.LoadConvars()
    end

    -- Step 2: Initialize security
    Hydra.Utils.Log('info', 'Initializing security system...')
    if Hydra.Security and Hydra.Security.Init then
        Hydra.Security.Init()
    end

    -- Step 3: Initialize callbacks
    Hydra.Utils.Log('info', 'Initializing callback system...')
    if Hydra.Callbacks and Hydra.Callbacks.Init then
        Hydra.Callbacks.Init()
    end

    -- Step 4: Wait for all resources to finish starting
    -- Other hydra modules register via Hydra.Modules.Register() in their server scripts.
    -- We need to wait until all ensure'd resources have started before loading modules.
    local totalResources = GetNumResources()
    local waited = 0
    local maxWait = 30000 -- 30 second safety cap
    while waited < maxWait do
        local allStarted = true
        for i = 0, totalResources - 1 do
            local resName = GetResourceByFindIndex(i)
            if resName and resName:find('^hydra_') and resName ~= GetCurrentResourceName() then
                if GetResourceState(resName) == 'starting' then
                    allStarted = false
                    break
                end
            end
        end
        if allStarted then break end
        Wait(500)
        waited = waited + 500
    end

    -- Extra buffer for module registration calls to complete
    Wait(1000)

    -- Step 5: Mark modules as ready
    Hydra.Utils.Log('info', 'Loading modules...')
    local loaded = Hydra.Modules.ReadyAll()
    Hydra.Utils.Log('info', 'Loaded %d modules', loaded)

    -- Step 6: Mark ready
    local bootTime = GetGameTimer() - bootStart
    Hydra._SetReady()

    Hydra.Utils.Log('info', '========================================')
    Hydra.Utils.Log('info', '  Hydra Framework - Ready! (%dms)', bootTime)
    Hydra.Utils.Log('info', '========================================')
end)

--- Handle player connecting
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source

    deferrals.defer()
    Wait(0)

    -- Check maintenance mode
    if Hydra.Config.Get('server.maintenance_mode', false) then
        -- Check if player has bypass permission
        if not IsPlayerAceAllowed(src, 'hydra.maintenance.bypass') then
            deferrals.done(Hydra.Config.Get('server.maintenance_message', 'Server is under maintenance.'))
            return
        end
    end

    deferrals.update('[Hydra] Validating...')
    Wait(0)

    -- Security validation
    if Hydra.Security and Hydra.Security.ValidatePlayer then
        local valid, reason = Hydra.Security.ValidatePlayer(src)
        if not valid then
            deferrals.done(reason or 'Connection rejected by Hydra security.')
            return
        end
    end

    deferrals.update('[Hydra] Loading your data...')
    Wait(0)

    -- Broadcast to modules
    Hydra.Modules.Broadcast('onPlayerConnecting', src, name, deferrals)

    deferrals.done()
end)

--- Handle player fully joined
--- Identity and Players modules listen for this event directly via RegisterNetEvent
RegisterNetEvent('hydra:playerLoaded')
AddEventHandler('hydra:playerLoaded', function()
    local src = source
    Hydra.Utils.Log('info', 'Player %d triggered hydra:playerLoaded', src)
end)

--- Handle player dropping
AddEventHandler('playerDropped', function(reason)
    local src = source
    Hydra.Modules.Broadcast('onPlayerDrop', src, reason)
    Hydra.Utils.Log('debug', 'Player %d dropped: %s', src, reason)

    -- Clean up security data
    if Hydra.Security and Hydra.Security.CleanupPlayer then
        Hydra.Security.CleanupPlayer(src)
    end
end)

--- Utility: Get all online player sources
--- @return table array of player source numbers
function Hydra.GetPlayers()
    local players = {}
    for i = 0, GetNumPlayerIndices() - 1 do
        players[#players + 1] = GetPlayerFromIndex(i)
    end
    return players
end

exports('GetPlayers', Hydra.GetPlayers)

--- Send config to client on request
Hydra.Events.Register('requestConfig', function(src)
    -- Send filtered config (no sensitive server-side data)
    local clientConfig = {
        framework_name = Hydra.Config.Get('framework_name', 'Hydra'),
        version = Hydra.Config.Get('version', '1.0.0'),
        locale = Hydra.Config.Get('locale', 'en'),
        debug = Hydra.Config.Get('debug', {}),
    }
    Hydra.Events.EmitClient('receiveConfig', src, clientConfig)
end)
