/**
 * Hydra Progressbar - NUI
 *
 * Minimal DOM manipulation. Uses requestAnimationFrame for smooth
 * fill animation instead of CSS transition for precise timing.
 */
(() => {
    'use strict';

    const container = document.getElementById('progress-container');
    const label = document.getElementById('progress-label');
    const fill = document.getElementById('progress-fill');

    let animFrame = null;
    let startTime = 0;
    let duration = 0;

    function show(data) {
        label.textContent = data.label || 'Processing...';
        duration = data.duration || 3000;
        startTime = performance.now();

        fill.style.width = '0%';
        container.classList.remove('hidden', 'fade-out');
        container.classList.add('fade-in');
        setTimeout(() => container.classList.remove('fade-in'), 250);

        if (animFrame) cancelAnimationFrame(animFrame);
        tick();
    }

    function tick() {
        const elapsed = performance.now() - startTime;
        const pct = Math.min((elapsed / duration) * 100, 100);
        fill.style.width = pct + '%';

        if (pct < 100) {
            animFrame = requestAnimationFrame(tick);
        }
    }

    function hide() {
        if (animFrame) {
            cancelAnimationFrame(animFrame);
            animFrame = null;
        }

        container.classList.add('fade-out');
        setTimeout(() => {
            container.classList.add('hidden');
            container.classList.remove('fade-out');
            fill.style.width = '0%';
        }, 200);
    }

    function callback(name, data) {
        return fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    function GetParentResourceName() {
        return window.GetParentResourceName ? window.GetParentResourceName() : 'hydra_progressbar';
    }

    window.addEventListener('message', (event) => {
        const { module, action, data } = event.data;
        if (module !== 'progressbar') return;

        if (action === 'start') show(data);
        else if (action === 'stop') hide();
    });
})();
