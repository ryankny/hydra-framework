/**
 * Hydra Loading Screen - Config Applier
 *
 * Reads LOADING_CONFIG and applies theme variables to CSS custom properties.
 * Runs before loading.js to ensure theme is set before rendering.
 */

(() => {
    'use strict';

    // Ensure config exists
    if (typeof LOADING_CONFIG === 'undefined') {
        console.warn('[Hydra] No LOADING_CONFIG found, using defaults.');
        window.LOADING_CONFIG = {};
    }

    const cfg = window.LOADING_CONFIG;

    // Apply theme to CSS variables
    if (cfg.theme) {
        const root = document.documentElement.style;
        const t = cfg.theme;
        if (t.primary) root.setProperty('--ls-primary', t.primary);
        if (t.secondary) root.setProperty('--ls-secondary', t.secondary);
        if (t.textPrimary) root.setProperty('--ls-text-primary', t.textPrimary);
        if (t.textSecondary) root.setProperty('--ls-text-secondary', t.textSecondary);
        if (t.textMuted) root.setProperty('--ls-text-muted', t.textMuted);
        if (t.cardBg) root.setProperty('--ls-card-bg', t.cardBg);
        if (t.cardBorder) root.setProperty('--ls-card-border', t.cardBorder);
    }

    // Inject custom CSS
    if (cfg.customCSS) {
        const style = document.createElement('style');
        style.textContent = cfg.customCSS;
        document.head.appendChild(style);
    }
})();
