--[[
    Hydra Framework - Permissions Configuration

    Define permission groups and their access levels.
    Integrates with ACE permissions and framework-level permissions.
]]

HydraConfig = HydraConfig or {}

HydraConfig.Permissions = {
    -- Built-in permission groups (mapped to ACE groups)
    groups = {
        superadmin = {
            label = 'Super Admin',
            priority = 100,
            inherits = { 'admin' },
            ace_group = 'group.admin',
        },
        admin = {
            label = 'Administrator',
            priority = 80,
            inherits = { 'moderator' },
        },
        moderator = {
            label = 'Moderator',
            priority = 60,
            inherits = { 'support' },
        },
        support = {
            label = 'Support',
            priority = 40,
            inherits = { 'vip' },
        },
        vip = {
            label = 'VIP',
            priority = 20,
            inherits = { 'user' },
        },
        user = {
            label = 'User',
            priority = 0,
            inherits = {},
        },
    },

    -- Default group for new players
    default_group = 'user',

    -- Permission nodes registered by modules
    -- Format: 'module.action' = { description, default_group }
    nodes = {
        ['hydra.admin.manage']      = { description = 'Manage server settings', default_group = 'admin' },
        ['hydra.admin.players']     = { description = 'Manage players', default_group = 'moderator' },
        ['hydra.admin.kick']        = { description = 'Kick players', default_group = 'moderator' },
        ['hydra.admin.ban']         = { description = 'Ban players', default_group = 'admin' },
        ['hydra.admin.maintenance'] = { description = 'Toggle maintenance mode', default_group = 'superadmin' },
    },
}

return HydraConfig.Permissions
