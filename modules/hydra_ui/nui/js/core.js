/**
 * Hydra Framework - Core UI Engine (JavaScript)
 *
 * Central message router and utility layer for all NUI modules.
 * Each module (notify, hud, etc.) registers handlers here.
 */

const HydraUI = (() => {
    'use strict';

    // Module handler registry
    const modules = {};

    // Theme (updated from Lua)
    let theme = {};

    // ---- Module Registration ----

    /**
     * Register a UI module's message handler
     * @param {string} name - Module name (e.g., 'notify', 'hud')
     * @param {object} handler - { init(), onMessage(action, data) }
     */
    function registerModule(name, handler) {
        modules[name] = handler;
        if (handler.init) {
            handler.init();
        }
    }

    // ---- NUI Message Listener ----

    window.addEventListener('message', (event) => {
        const { module, action, data } = event.data;
        if (!module) return;

        // Core module handles theme
        if (module === 'core') {
            if (action === 'setTheme') {
                theme = data;
                applyTheme(data);
            }
            return;
        }

        // Route to registered module
        const handler = modules[module];
        if (handler && handler.onMessage) {
            handler.onMessage(action, data);
        }
    });

    // ---- Theme Application ----

    function applyTheme(t) {
        if (!t || !t.colors) return;
        const root = document.documentElement.style;
        const c = t.colors;
        if (c.primary) root.setProperty('--hydra-primary', c.primary);
        if (c.secondary) root.setProperty('--hydra-secondary', c.secondary);
        if (c.success) root.setProperty('--hydra-success', c.success);
        if (c.warning) root.setProperty('--hydra-warning', c.warning);
        if (c.danger) root.setProperty('--hydra-danger', c.danger);
        if (c.info) root.setProperty('--hydra-info', c.info);
        if (c.bg_dark) root.setProperty('--hydra-bg-dark', c.bg_dark);
        if (c.bg_primary) root.setProperty('--hydra-bg-primary', c.bg_primary);
        if (c.bg_card) root.setProperty('--hydra-bg-card', c.bg_card);
        if (c.bg_elevated) root.setProperty('--hydra-bg-elevated', c.bg_elevated);
        if (c.text_primary) root.setProperty('--hydra-text-primary', c.text_primary);
        if (c.text_secondary) root.setProperty('--hydra-text-secondary', c.text_secondary);
        if (c.text_muted) root.setProperty('--hydra-text-muted', c.text_muted);
    }

    // ---- Utility Functions ----

    /**
     * Create a DOM element with classes and attributes
     */
    function createElement(tag, classes, attrs) {
        const el = document.createElement(tag);
        if (classes) {
            if (Array.isArray(classes)) {
                el.classList.add(...classes);
            } else {
                el.className = classes;
            }
        }
        if (attrs) {
            for (const [key, val] of Object.entries(attrs)) {
                if (key === 'text') {
                    el.textContent = val;
                } else if (key === 'html') {
                    el.innerHTML = val;
                } else if (key === 'style' && typeof val === 'object') {
                    Object.assign(el.style, val);
                } else {
                    el.setAttribute(key, val);
                }
            }
        }
        return el;
    }

    /**
     * Format a number with commas
     */
    function formatNumber(n) {
        return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    }

    /**
     * Lerp between two values
     */
    function lerp(start, end, t) {
        return start + (end - start) * t;
    }

    /**
     * Clamp a value
     */
    function clamp(val, min, max) {
        return Math.min(Math.max(val, min), max);
    }

    /**
     * Send NUI callback to Lua
     */
    function callback(name, data) {
        return fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {}),
        }).then(r => r.json()).catch(() => ({}));
    }

    /**
     * Get the parent resource name
     */
    function GetParentResourceName() {
        return window.GetParentResourceName ? window.GetParentResourceName() : 'hydra_ui';
    }

    // ---- SVG Icon Library ---- //
    const icons = {
        info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>',
        success: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>',
        warning: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
        error: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>',
        health: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>',
        armor: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z"/></svg>',
        hunger: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 8h1a4 4 0 0 1 0 8h-1"/><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"/><line x1="6" y1="1" x2="6" y2="4"/><line x1="10" y1="1" x2="10" y2="4"/><line x1="14" y1="1" x2="14" y2="4"/></svg>',
        thirst: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"/></svg>',
        fuel: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2z"/><path d="M16 10h2a2 2 0 0 1 2 2v2a2 2 0 0 0 2 2"/><line x1="6" y1="6" x2="14" y2="6"/></svg>',
        speed: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 12m-10 0a10 10 0 1 0 20 0a10 10 0 1 0 -20 0"/><path d="M12 12l4 -4"/><path d="M12 7v1"/></svg>',
        compass: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76"/></svg>',
        location: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>',
        clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>',
        car: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 17h14v-5l-2-5H7L5 12v5z"/><circle cx="7.5" cy="17" r="1.5"/><circle cx="16.5" cy="17" r="1.5"/></svg>',
        plane: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17.8 19.2L16 11l3.5-3.5C21 6 21.5 4 21 3c-1-.5-3 0-4.5 1.5L13 8 4.8 6.2c-.5-.1-.9.1-1.1.5l-.3.5c-.2.5-.1 1 .3 1.3L9 12l-2 3H4l-1 1 3 2 2 3 1-1v-3l3-2 3.5 5.3c.3.4.8.5 1.3.3l.5-.2c.4-.3.6-.7.5-1.2z"/></svg>',
        boat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 20a6 6 0 0 0 12 0 6 6 0 0 0 8 0"/><path d="M4 18l8-14 8 14"/><line x1="12" y1="4" x2="12" y2="18"/></svg>',
        engine: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="6" width="20" height="12" rx="2"/><line x1="6" y1="10" x2="6" y2="14"/><line x1="10" y1="10" x2="10" y2="14"/></svg>',
        seatbelt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="5" r="3"/><path d="M12 8v8"/><path d="M8 21l4-5 4 5"/></svg>',
        lock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>',
        signal: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/></svg>',
        altitude: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2v20"/><path d="M8 6l4-4 4 4"/><path d="M4 18h16"/></svg>',
    };

    /**
     * Get an SVG icon by name
     */
    function getIcon(name, size) {
        size = size || 16;
        const svg = icons[name] || icons.info;
        const wrapper = document.createElement('div');
        wrapper.className = 'hydra-icon';
        wrapper.style.width = size + 'px';
        wrapper.style.height = size + 'px';
        wrapper.innerHTML = svg;
        const svgEl = wrapper.querySelector('svg');
        if (svgEl) {
            svgEl.style.width = '100%';
            svgEl.style.height = '100%';
        }
        return wrapper;
    }

    // ---- Notify Lua that NUI is ready ----
    window.addEventListener('DOMContentLoaded', () => {
        setTimeout(() => {
            callback('hydra:ui:ready', {});
        }, 50);
    });

    // ---- Public API ----
    return {
        registerModule,
        createElement,
        formatNumber,
        lerp,
        clamp,
        callback,
        getIcon,
        icons,
        getTheme: () => theme,
    };
})();
