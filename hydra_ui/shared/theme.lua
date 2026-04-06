--[[
    Hydra UI - Theme Configuration

    Central theme definition used across all Hydra UI modules.
    Developers can override these values to customize the look.
]]

Hydra = Hydra or {}
Hydra.UI = Hydra.UI or {}

Hydra.UI.Theme = {
    -- Color palette
    colors = {
        primary     = '#6C5CE7',    -- Hydra purple
        secondary   = '#00CEC9',    -- Teal accent
        success     = '#00B894',    -- Green
        warning     = '#FDCB6E',    -- Amber
        danger      = '#FF7675',    -- Red
        info        = '#74B9FF',    -- Blue

        -- Backgrounds
        bg_dark     = '#0F0F14',    -- Darkest
        bg_primary  = '#161620',    -- Main background
        bg_card     = '#1E1E2E',    -- Card/panel background
        bg_elevated = '#252536',    -- Elevated surfaces
        bg_hover    = '#2A2A3C',    -- Hover state

        -- Text
        text_primary   = '#FFFFFF',
        text_secondary = '#A0A0B8',
        text_muted     = '#6C6C80',
        text_accent    = '#6C5CE7',

        -- Borders
        border       = '#2A2A3C',
        border_focus = '#6C5CE7',

        -- Overlays
        overlay = 'rgba(0, 0, 0, 0.6)',
    },

    -- Typography
    fonts = {
        primary = "'Plus Jakarta Sans', sans-serif",
        mono    = "'JetBrains Mono', monospace",
    },

    -- Font sizes (rem)
    fontSize = {
        xs   = '0.625rem',  -- 10px
        sm   = '0.75rem',   -- 12px
        base = '0.8125rem', -- 13px
        md   = '0.875rem',  -- 14px
        lg   = '1rem',      -- 16px
        xl   = '1.25rem',   -- 20px
        xxl  = '1.5rem',    -- 24px
        hero = '2rem',      -- 32px
    },

    -- Spacing scale (px)
    spacing = {
        xs = 4,
        sm = 8,
        md = 12,
        lg = 16,
        xl = 24,
        xxl = 32,
    },

    -- Border radius
    radius = {
        sm   = '4px',
        md   = '8px',
        lg   = '12px',
        xl   = '16px',
        full = '9999px',
    },

    -- Shadows
    shadows = {
        sm   = '0 2px 4px rgba(0, 0, 0, 0.3)',
        md   = '0 4px 12px rgba(0, 0, 0, 0.4)',
        lg   = '0 8px 24px rgba(0, 0, 0, 0.5)',
        glow = '0 0 20px rgba(108, 92, 231, 0.3)',
    },

    -- Animation durations (ms)
    animation = {
        fast   = 150,
        normal = 250,
        slow   = 400,
        slide  = 350,
    },

    -- Z-index layers
    zIndex = {
        hud     = 10,
        notify  = 100,
        modal   = 200,
        tooltip = 300,
        top     = 999,
    },
}

return Hydra.UI.Theme
