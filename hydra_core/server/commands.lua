--[[
    Hydra Framework - Server Admin Commands

    Built-in admin commands for framework management.
    All commands require appropriate ACE permissions.
]]

Hydra = Hydra or {}

--- Register framework admin commands
CreateThread(function()
    -- Wait for framework to be ready
    while not Hydra.IsReady() do Wait(100) end

    -- /hydra - Framework info
    RegisterCommand('hydra', function(source, args)
        local src = source
        if src > 0 and not IsPlayerAceAllowed(src, 'hydra.admin.manage') then
            return
        end

        local subcommand = args[1]

        if not subcommand or subcommand == 'info' then
            Hydra.Utils.Log('info', 'Hydra Framework v%s', Hydra.GetVersion())
            local modules = Hydra.Modules.GetAll()
            Hydra.Utils.Log('info', 'Loaded modules: %d', #modules)
            for _, m in ipairs(modules) do
                Hydra.Utils.Log('info', '  - %s v%s [%s]', m.name, m.version, m.state)
            end

        elseif subcommand == 'modules' then
            local modules = Hydra.Modules.GetAll()
            for _, m in ipairs(modules) do
                Hydra.Utils.Log('info', '[%s] %s v%s - %s', m.state, m.name, m.version, m.label)
            end

        elseif subcommand == 'maintenance' then
            local state = args[2] == 'on'
            Hydra.Config.Set('server.maintenance_mode', state)
            Hydra.Utils.Log('info', 'Maintenance mode: %s', state and 'ENABLED' or 'DISABLED')

        elseif subcommand == 'debug' then
            local level = args[2] or 'info'
            Hydra.Config.Set('debug.log_level', level)
            Hydra.Utils.Log('info', 'Debug log level set to: %s', level)

        elseif subcommand == 'reload' then
            local moduleName = args[2]
            if moduleName then
                Hydra.Modules.Unload(moduleName)
                Hydra.Modules.Load(moduleName)
                Hydra.Utils.Log('info', 'Module reloaded: %s', moduleName)
            else
                Hydra.Utils.Log('warn', 'Usage: /hydra reload <module_name>')
            end

        elseif subcommand == 'security' then
            local events = Hydra.Events.GetRegistered()
            local count = 0
            for _ in pairs(events) do count = count + 1 end
            Hydra.Utils.Log('info', 'Registered secure events: %d', count)

        else
            Hydra.Utils.Log('info', 'Usage: /hydra [info|modules|maintenance|debug|reload|security]')
        end
    end, true) -- restricted = true, requires ACE
end)
