--[[
    Hydra Blips - Configuration
]]

HydraBlipsConfig = {
    -- Default blip settings when not specified
    defaults = {
        sprite = 1,
        color = 0,
        scale = 0.8,
        short_range = true,
        display = 4,
    },

    -- Categories for easy management (toggle visibility by category)
    categories = {
        job      = { label = 'Job Locations',   visible = true },
        shop     = { label = 'Shops',           visible = true },
        service  = { label = 'Services',        visible = true },
        housing  = { label = 'Housing',         visible = true },
        event    = { label = 'Events',          visible = true },
        custom   = { label = 'Custom',          visible = true },
    },
}

return HydraBlipsConfig
