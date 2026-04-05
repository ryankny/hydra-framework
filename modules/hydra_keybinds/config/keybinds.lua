--[[
    Hydra Framework - Keybind Configuration

    Central configuration for the keybind management system.
    Modules register their keybinds at runtime through the API.
]]

HydraConfig = HydraConfig or {}

HydraConfig.Keybinds = {
    enabled = true,
    conflict_detection = true,       -- Warn on duplicate key assignments
    conflict_action = 'warn',        -- 'warn' | 'block' | 'allow'
    allow_rebind = true,             -- Allow players to rebind via FiveM settings
    list_command = 'keybinds',       -- Command to list all keybinds
    debug = false,

    -- Default keybind definitions (modules override these)
    defaults = {
        -- Format: { id = string, key = string, description = string, category = string }
        -- Populated at runtime by modules registering keybinds
    },
}
