/**
 * Hydra Context - NUI
 *
 * Renders list-style and radial context menus.
 * Handles item selection, back navigation, and close.
 */
(() => {
    'use strict';

    const backdrop = document.getElementById('context-backdrop');
    const menu = document.getElementById('context-menu');

    function callback(name, data) {
        return fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    function GetParentResourceName() {
        return window.GetParentResourceName ? window.GetParentResourceName() : 'hydra_context';
    }

    // ---- Show Menu ----
    function show(data) {
        const type = data.type || 'list';

        if (type === 'radial') {
            renderRadial(data);
        } else {
            renderList(data);
        }

        backdrop.classList.remove('hidden');
        menu.classList.remove('hidden');
        menu.classList.add('fade-in');
        setTimeout(() => menu.classList.remove('fade-in'), 200);
    }

    // ---- Render List Menu ----
    function renderList(data) {
        menu.className = '';
        let html = '';

        // Header
        html += '<div class="context-header">';
        if (data.canGoBack) {
            html += `<button class="btn-back" id="ctx-back">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
            </button>`;
        }
        html += `<span class="context-title">${esc(data.title)}</span>`;
        html += '</div>';

        // Items
        html += '<div class="context-items">';
        for (const item of data.items) {
            const disabled = item.disabled ? ' disabled' : '';
            html += `<div class="context-item${disabled}" data-index="${item.index}">`;

            if (item.icon) {
                html += `<div class="context-item-icon">${esc(item.icon)}</div>`;
            }

            html += '<div class="context-item-text">';
            html += `<div class="context-item-label">${esc(item.label)}</div>`;
            if (item.description) {
                html += `<div class="context-item-desc">${esc(item.description)}</div>`;
            }
            html += '</div>';

            if (item.hasSubmenu) {
                html += '<svg class="context-item-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 18l6-6-6-6"/></svg>';
            }

            html += '</div>';
        }
        html += '</div>';

        menu.innerHTML = html;

        // Bind item clicks
        menu.querySelectorAll('.context-item').forEach(el => {
            el.addEventListener('click', () => {
                if (el.classList.contains('disabled')) return;
                callback('context:select', { index: parseInt(el.dataset.index) });
            });
        });

        // Back button
        const backBtn = document.getElementById('ctx-back');
        if (backBtn) {
            backBtn.addEventListener('click', () => callback('context:back'));
        }
    }

    // ---- Render Radial Menu ----
    function renderRadial(data) {
        menu.className = 'radial';
        let html = '';

        // Center label
        html += `<div class="radial-center">${esc(data.title)}</div>`;

        // Position items in circle
        const items = data.items;
        const count = items.length;
        const radius = 100;

        for (let i = 0; i < count; i++) {
            const item = items[i];
            const angle = (i / count) * Math.PI * 2 - Math.PI / 2; // Start from top
            const x = Math.cos(angle) * radius;
            const y = Math.sin(angle) * radius;
            const disabled = item.disabled ? ' disabled' : '';

            html += `<div class="radial-item${disabled}" data-index="${item.index}" style="left: calc(50% + ${x}px - 36px); top: calc(50% + ${y}px - 36px);">`;
            if (item.icon) {
                html += `<span class="radial-item-icon">${esc(item.icon)}</span>`;
            }
            html += `<span class="radial-item-label">${esc(item.label)}</span>`;
            html += '</div>';
        }

        menu.innerHTML = html;

        // Bind clicks
        menu.querySelectorAll('.radial-item').forEach(el => {
            el.addEventListener('click', () => {
                if (el.classList.contains('disabled')) return;
                callback('context:select', { index: parseInt(el.dataset.index) });
            });
        });
    }

    // ---- Hide ----
    function hide() {
        backdrop.classList.add('hidden');
        menu.classList.add('hidden');
    }

    // ---- Escape HTML ----
    function esc(str) {
        if (!str) return '';
        const d = document.createElement('div');
        d.textContent = String(str);
        return d.innerHTML;
    }

    // ---- Backdrop click to close ----
    backdrop.addEventListener('click', () => callback('context:close'));

    // ---- Message Handler ----
    window.addEventListener('message', (event) => {
        const { module, action, data } = event.data;
        if (module !== 'context') return;

        if (action === 'show') show(data);
        else if (action === 'hide') hide();
    });
})();
