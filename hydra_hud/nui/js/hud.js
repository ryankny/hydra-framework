/**
 * Hydra HUD - Player HUD Renderer
 *
 * Renders player vitals (health, armor, hunger, thirst, oxygen),
 * money display, and job info with smooth animations.
 */

(() => {
    'use strict';

    // DOM references (cached for performance)
    const els = {};
    let config = {};
    let currentMoney = { cash: 0, bank: 0 };
    let hudVisible = true;

    /**
     * Cache DOM references
     */
    function cacheDom() {
        els.player = document.getElementById('hud-player');
        els.healthFill = document.querySelector('.health-fill');
        els.armorFill = document.querySelector('.armor-fill');
        els.armorBar = document.getElementById('vital-armor');
        els.hungerFill = document.querySelector('.hunger-fill');
        els.thirstFill = document.querySelector('.thirst-fill');
        els.oxygenFill = document.querySelector('.oxygen-fill');
        els.oxygenBar = document.getElementById('vital-oxygen');
        els.cashValue = document.getElementById('money-cash');
        els.bankValue = document.getElementById('money-bank');
        els.jobLabel = document.getElementById('job-label');

        // Set vital icons
        setVitalIcons();
    }

    /**
     * Set SVG icons for vitals
     */
    function setVitalIcons() {
        const iconMap = {
            'icon-health': '<svg viewBox="0 0 24 24" fill="currentColor" width="14" height="14"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>',
            'icon-armor': '<svg viewBox="0 0 24 24" fill="currentColor" width="14" height="14"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z"/></svg>',
            'icon-hunger': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M18 8h1a4 4 0 0 1 0 8h-1"/><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"/><line x1="6" y1="1" x2="6" y2="4"/><line x1="10" y1="1" x2="10" y2="4"/><line x1="14" y1="1" x2="14" y2="4"/></svg>',
            'icon-thirst': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"/></svg>',
            'icon-oxygen': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M12 22c5.52 0 10-4.48 10-10S17.52 2 12 2 2 6.48 2 12s4.48 10 10 10z"/><path d="M12 6v6l4 2"/></svg>',
        };

        for (const [id, svg] of Object.entries(iconMap)) {
            const el = document.getElementById(id);
            if (el) el.innerHTML = svg;
        }
    }

    /**
     * Format money with $ and commas
     */
    function formatMoney(n) {
        return '$' + Math.floor(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    }

    /**
     * Animate money value change
     */
    function animateMoney(el, from, to, type) {
        const duration = 600;
        const start = performance.now();

        function tick(now) {
            const elapsed = now - start;
            const t = Math.min(elapsed / duration, 1);
            const eased = 1 - Math.pow(1 - t, 3); // easeOutCubic
            const val = Math.round(from + (to - from) * eased);
            el.textContent = formatMoney(val);

            if (t < 1) {
                requestAnimationFrame(tick);
            }
        }

        // Flash animation
        const flashClass = to > from ? 'increase' : 'decrease';
        el.classList.remove('increase', 'decrease');
        void el.offsetWidth; // Force reflow
        el.classList.add(flashClass);

        setTimeout(() => el.classList.remove(flashClass), 700);

        requestAnimationFrame(tick);
    }

    /**
     * Update vital bar
     */
    function updateVital(fillEl, barEl, value, max, showEl) {
        if (!fillEl) return;
        const percent = Math.min(Math.max((value / max) * 100, 0), 100);
        fillEl.style.width = percent + '%';

        // Critical state (below 25%)
        if (percent < 25) {
            fillEl.classList.add('critical');
        } else {
            fillEl.classList.remove('critical');
        }

        // Show/hide bar
        if (barEl && showEl !== undefined) {
            barEl.style.display = showEl ? 'flex' : 'none';
        }
    }

    // ---- NUI Message Handler ----
    window.addEventListener('message', (event) => {
        const { module, action, data } = event.data;
        if (module !== 'hud') return;

        switch (action) {
            case 'init':
                config = data.config || {};
                cacheDom();
                // Apply initial visibility (starts hidden until character loads)
                hudVisible = data.visible !== undefined ? data.visible : false;
                if (els.player) els.player.classList.toggle('hidden', !hudVisible);
                const navInit = document.getElementById('hud-navigation');
                if (navInit) navInit.classList.toggle('hidden', !hudVisible);
                break;

            case 'setVisible':
                hudVisible = data.visible;
                if (els.player) {
                    els.player.classList.toggle('hidden', !hudVisible);
                }
                // Also toggle navigation
                const nav = document.getElementById('hud-navigation');
                if (nav) nav.classList.toggle('hidden', !hudVisible);
                break;

            case 'playerUpdate':
                if (!els.healthFill) cacheDom();

                updateVital(els.healthFill, null, data.health, data.maxHealth || 100);
                updateVital(els.armorFill, els.armorBar, data.armor, 100, data.armor > 0);
                updateVital(els.hungerFill, null, data.hunger, 100);
                updateVital(els.thirstFill, null, data.thirst, 100);
                updateVital(els.oxygenFill, els.oxygenBar, data.oxygen, 100, data.isUnderwater);
                break;

            case 'playerInit':
                if (!els.cashValue) cacheDom();

                if (data.accounts) {
                    currentMoney.cash = data.accounts.cash || 0;
                    currentMoney.bank = data.accounts.bank || 0;
                    if (els.cashValue) els.cashValue.textContent = formatMoney(currentMoney.cash);
                    if (els.bankValue) els.bankValue.textContent = formatMoney(currentMoney.bank);
                }

                if (data.job && els.jobLabel) {
                    const jobText = data.job.grade_label
                        ? `${data.job.label} - ${data.job.grade_label}`
                        : data.job.label || 'Unemployed';
                    els.jobLabel.textContent = jobText;
                }
                break;

            case 'moneyUpdate':
                if (!els.cashValue) cacheDom();

                const type = data.type === 'money' ? 'cash' : data.type;
                const newAmount = data.amount;
                const el = type === 'cash' ? els.cashValue : els.bankValue;

                if (el) {
                    const oldAmount = currentMoney[type] || 0;
                    animateMoney(el, oldAmount, newAmount, type);
                    currentMoney[type] = newAmount;
                }
                break;

            case 'jobUpdate':
                if (!els.jobLabel) cacheDom();
                if (els.jobLabel && data) {
                    const jobText = data.grade_label
                        ? `${data.label} - ${data.grade_label}`
                        : data.label || 'Unemployed';
                    els.jobLabel.textContent = jobText;
                }
                break;
        }
    });

    // Notify Lua we're ready
    window.addEventListener('DOMContentLoaded', () => {
        cacheDom();
        setTimeout(() => {
            fetch(`https://${GetParentResourceName()}/hydra:hud:ready`, {
                method: 'POST',
                body: JSON.stringify({}),
            }).catch(() => {});
        }, 100);
    });

    function GetParentResourceName() {
        return window.GetParentResourceName ? window.GetParentResourceName() : 'hydra_hud';
    }
})();
