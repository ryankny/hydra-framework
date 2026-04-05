--[[
    Hydra Commands - Configuration

    Central configuration for the command registration system.
    Adjust values here to tune cooldowns, help output, and messaging.
]]

HydraConfig = HydraConfig or {}

HydraConfig.Commands = {
    enabled = true,                -- Master toggle for the command system
    prefix = '/',                  -- Command prefix for display in help text
    cooldown_default = 500,        -- Default cooldown in ms between uses
    max_args = 20,                 -- Maximum arguments per command
    log_usage = true,              -- Log command usage to console / hydra_logs
    log_admin_only = false,        -- Only log commands that require a permission
    help_command = 'help',         -- Name of the built-in help command
    help_per_page = 10,            -- Commands shown per help page
    suggest_on_typo = true,        -- Suggest similar commands on typo
    typo_threshold = 2,            -- Max Levenshtein distance for suggestions
    unknown_message = 'Unknown command. Type /help for a list of commands.',
    cooldown_message = 'Please wait before using this command again.',
    permission_message = 'You do not have permission to use this command.',
    debug = false,
}
