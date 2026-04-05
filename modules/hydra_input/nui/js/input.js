/**
 * Hydra Input - NUI
 *
 * Renders input forms and confirm dialogs dynamically.
 * Handles validation, focus management, and submit.
 */
(() => {
    'use strict';

    const backdrop = document.getElementById('input-backdrop');
    const dialog = document.getElementById('input-dialog');
    let fields = [];

    function callback(name, data) {
        return fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    function GetParentResourceName() {
        return window.GetParentResourceName ? window.GetParentResourceName() : 'hydra_input';
    }

    // ---- Show Form Dialog ----
    function showForm(data) {
        fields = data.fields || [];
        let html = '';

        html += `<div class="input-title">${esc(data.title)}</div>`;
        if (data.description) {
            html += `<div class="input-description">${esc(data.description)}</div>`;
        }

        html += '<div class="input-fields">';
        for (let i = 0; i < fields.length; i++) {
            const f = fields[i];
            const name = f.name || `field_${i}`;
            const id = `input-field-${i}`;

            if (f.type === 'checkbox') {
                html += `<div class="field-group field-checkbox">
                    <input type="checkbox" id="${id}" data-name="${esc(name)}" ${f.default ? 'checked' : ''}>
                    <label for="${id}">${esc(f.label || name)}</label>
                </div>`;
            } else if (f.type === 'select') {
                html += `<div class="field-group">
                    <label for="${id}">${esc(f.label || name)}</label>
                    <select id="${id}" data-name="${esc(name)}">`;
                for (const opt of (f.options || [])) {
                    const val = typeof opt === 'object' ? opt.value : opt;
                    const label = typeof opt === 'object' ? opt.label : opt;
                    const selected = f.default == val ? ' selected' : '';
                    html += `<option value="${esc(String(val))}"${selected}>${esc(String(label))}</option>`;
                }
                html += `</select></div>`;
            } else if (f.type === 'textarea') {
                html += `<div class="field-group">
                    <label for="${id}">${esc(f.label || name)}</label>
                    <textarea id="${id}" data-name="${esc(name)}" placeholder="${esc(f.placeholder || '')}" rows="3">${esc(f.default || '')}</textarea>
                </div>`;
            } else {
                const type = f.type || 'text';
                const extras = [];
                if (f.min != null) extras.push(`min="${f.min}"`);
                if (f.max != null) extras.push(`max="${f.max}"`);
                if (f.required) extras.push('required');

                html += `<div class="field-group">
                    <label for="${id}">${esc(f.label || name)}</label>
                    <input type="${type}" id="${id}" data-name="${esc(name)}" placeholder="${esc(f.placeholder || '')}" value="${esc(f.default || '')}" ${extras.join(' ')}>
                </div>`;
            }
        }
        html += '</div>';

        html += `<div class="input-actions">
            <button class="btn btn-ghost" id="btn-cancel">${esc(data.cancelText || 'Cancel')}</button>
            <button class="btn btn-primary" id="btn-submit">${esc(data.submitText || 'Confirm')}</button>
        </div>`;

        dialog.innerHTML = html;
        showDialog();

        // Bind
        document.getElementById('btn-cancel').onclick = () => callback('input:cancel');
        document.getElementById('btn-submit').onclick = () => submitForm();

        // Focus first input
        const first = dialog.querySelector('input:not([type="checkbox"]), select, textarea');
        if (first) setTimeout(() => first.focus(), 100);

        // Submit on enter
        dialog.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && e.target.tagName !== 'TEXTAREA') {
                e.preventDefault();
                submitForm();
            }
        });
    }

    function submitForm() {
        const values = {};
        for (let i = 0; i < fields.length; i++) {
            const f = fields[i];
            const name = f.name || `field_${i}`;
            const el = document.getElementById(`input-field-${i}`);
            if (!el) continue;

            if (f.type === 'checkbox') {
                values[name] = el.checked;
            } else if (f.type === 'number') {
                values[name] = el.value !== '' ? parseFloat(el.value) : null;
            } else {
                values[name] = el.value;
            }

            // Required validation
            if (f.required && (values[name] === '' || values[name] === null)) {
                el.style.borderColor = '#FF7675';
                el.focus();
                setTimeout(() => el.style.borderColor = '', 2000);
                return;
            }
        }

        callback('input:submit', { values });
    }

    // ---- Show Confirm Dialog ----
    function showConfirm(data) {
        let html = `
            <div class="confirm-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
            </div>
            <div class="input-title" style="text-align:center">${esc(data.title)}</div>
            <div class="confirm-message">${esc(data.message)}</div>
            <div class="input-actions" style="justify-content:center">
                <button class="btn btn-ghost" id="btn-cancel">Cancel</button>
                <button class="btn btn-primary" id="btn-submit">Confirm</button>
            </div>
        `;

        dialog.innerHTML = html;
        showDialog();

        document.getElementById('btn-cancel').onclick = () => callback('input:cancel');
        document.getElementById('btn-submit').onclick = () => callback('input:submit', { values: { confirmed: true } });
    }

    // ---- Visibility ----
    function showDialog() {
        backdrop.classList.remove('hidden');
        dialog.classList.remove('hidden');
        dialog.classList.add('fade-in');
        setTimeout(() => dialog.classList.remove('fade-in'), 250);
    }

    function hideDialog() {
        backdrop.classList.add('hidden');
        dialog.classList.add('hidden');
    }

    // ---- Escape HTML ----
    function esc(str) {
        if (!str) return '';
        const d = document.createElement('div');
        d.textContent = String(str);
        return d.innerHTML;
    }

    // ---- Message Handler ----
    window.addEventListener('message', (event) => {
        const { module, action, data } = event.data;
        if (module !== 'input') return;

        if (action === 'show') showForm(data);
        else if (action === 'confirm') showConfirm(data);
        else if (action === 'hide') hideDialog();
    });
})();
