--[[
    Hydra Framework - Server Module Manager

    Handles server-side module discovery, dependency resolution,
    and hot-reload capabilities.
]]

Hydra = Hydra or {}

--- Auto-discover modules from other resources
--- Resources can register as Hydra modules by exporting a GetHydraModule function
CreateThread(function()
    Wait(100) -- Wait for resources to start

    local numResources = GetNumResources()
    for i = 0, numResources - 1 do
        local resourceName = GetResourceByFindIndex(i)
        if resourceName and resourceName ~= GetCurrentResourceName() then
            -- Check if resource has a Hydra module export
            local moduleExport = exports[resourceName]
            if moduleExport then
                local ok, moduleDef = pcall(function()
                    return moduleExport:GetHydraModule()
                end)
                if ok and moduleDef then
                    Hydra.Modules.Register(moduleDef.name or resourceName, moduleDef)
                    Hydra.Utils.Log('debug', 'Auto-discovered module from resource: %s', resourceName)
                end
            end
        end
    end
end)

--- Handle resource restart - unload/reload modules
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Framework stopping, unload everything
        local allModules = Hydra.Modules.GetAll()
        for _, mod in ipairs(allModules) do
            Hydra.Modules.Unload(mod.name)
        end
        return
    end
end)

--- Resource start - check for new modules
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end

    -- Delayed check for module registration
    SetTimeout(500, function()
        local ok, moduleDef = pcall(function()
            return exports[resourceName]:GetHydraModule()
        end)
        if ok and moduleDef then
            local name = moduleDef.name or resourceName
            if Hydra.Modules.Register(name, moduleDef) then
                Hydra.Modules.Load(name)
                Hydra.Utils.Log('info', 'Hot-loaded module: %s', name)
            end
        end
    end)
end)
