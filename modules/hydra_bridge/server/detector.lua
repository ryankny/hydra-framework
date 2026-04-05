--[[
    Hydra Bridge - Auto-Detection

    Automatically detects which legacy framework scripts are installed
    and activates the appropriate bridge adapter.
]]

Hydra = Hydra or {}

--- Detect installed frameworks by checking for their resources
--- @return string detected framework name or 'native'
function Hydra.Bridge.Detect()
    -- Check for ESX
    if GetResourceState('es_extended') == 'started' or GetResourceState('es_extended') == 'starting' then
        return 'esx'
    end

    -- Check for QBCore
    if GetResourceState('qb-core') == 'started' or GetResourceState('qb-core') == 'starting' then
        return 'qbcore'
    end

    -- Check for QBox
    if GetResourceState('qbx_core') == 'started' or GetResourceState('qbx_core') == 'starting' then
        return 'qbox'
    end

    -- Check for TMC
    if GetResourceState('tmc_core') == 'started' or GetResourceState('tmc_core') == 'starting' then
        return 'tmc'
    end

    -- No legacy framework detected, run native
    return 'native'
end

--- Run detection and set bridge mode
CreateThread(function()
    Wait(0) -- Let resources start

    local detected = Hydra.Bridge.Detect()

    -- Allow convar override
    local override = GetConvar('hydra_bridge_mode', '')
    if override ~= '' then
        detected = override
        Hydra.Utils.Log('info', 'Bridge mode overridden via convar: %s', override)
    end

    Hydra.Bridge.SetMode(detected)

    if detected ~= 'native' then
        Hydra.Utils.Log('info', 'Legacy framework detected: %s - Bridge activated', detected)
        Hydra.Utils.Log('info', 'Legacy scripts will run through Hydra bridge layer')
    else
        Hydra.Utils.Log('info', 'No legacy framework detected - Running in native Hydra mode')
    end
end)
