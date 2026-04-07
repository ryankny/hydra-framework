/**
 * Hydra HUD - Navigation Renderer
 *
 * Renders the compass strip with cardinal/intercardinal directions,
 * street name, zone, and time.
 */

(() => {
    'use strict';

    const els = {};
    const COMPASS_WIDTH = 360;
    const TICK_WIDTH = 10;
    const DEGREES_VISIBLE = 180;

    // Cardinal and intercardinal labels
    const LABELS = {
        0: 'N', 45: 'NE', 90: 'E', 135: 'SE',
        180: 'S', 225: 'SW', 270: 'W', 315: 'NW',
    };

    let compassBuilt = false;

    function cacheDom() {
        els.nav = document.getElementById('hud-navigation');
        els.compassStrip = document.getElementById('compass-strip');
        els.street = document.getElementById('nav-street');
        els.crossing = document.getElementById('nav-crossing');
        els.zone = document.getElementById('nav-zone');
        els.direction = document.getElementById('nav-direction');
        els.time = document.getElementById('nav-time');
    }

    /**
     * Build the compass tick marks (0-360 degrees)
     */
    function buildCompass() {
        if (!els.compassStrip || compassBuilt) return;

        // Add center mark
        const centerMark = document.createElement('div');
        centerMark.className = 'center-mark';
        els.compassStrip.parentElement.appendChild(centerMark);

        // We need 720 degrees worth of ticks to allow seamless wrapping
        // (360 before + 360 after for smooth scroll)
        const fragment = document.createDocumentFragment();

        for (let deg = -180; deg <= 540; deg += 5) {
            const normalizedDeg = ((deg % 360) + 360) % 360;
            const tick = document.createElement('div');

            const isCardinal = normalizedDeg % 90 === 0;
            const isIntercardinal = normalizedDeg % 45 === 0 && !isCardinal;
            const isMajor = normalizedDeg % 15 === 0;

            let className = 'compass-tick';
            if (isCardinal || isIntercardinal) className += ' major cardinal';
            else if (isMajor) className += ' major';
            if (normalizedDeg === 0) className += ' north';

            tick.className = className;

            // Tick line
            const line = document.createElement('div');
            line.className = 'tick-line';
            tick.appendChild(line);

            // Label for cardinal/intercardinal
            const label = LABELS[normalizedDeg];
            if (label) {
                const labelEl = document.createElement('span');
                labelEl.className = 'tick-label';
                labelEl.textContent = label;
                tick.appendChild(labelEl);
            } else if (isMajor) {
                const labelEl = document.createElement('span');
                labelEl.className = 'tick-label';
                labelEl.textContent = normalizedDeg;
                labelEl.style.fontSize = '0.5rem';
                labelEl.style.color = 'rgba(160, 160, 184, 0.5)';
                tick.appendChild(labelEl);
            }

            fragment.appendChild(tick);
        }

        els.compassStrip.appendChild(fragment);
        compassBuilt = true;
    }

    /**
     * Update compass rotation based on heading
     */
    function updateCompass(heading) {
        if (!els.compassStrip) return;

        // Each 5 degrees = 1 tick = TICK_WIDTH px
        const totalTicks = 720 / 5; // 144 ticks for full range
        const pixelsPerDegree = TICK_WIDTH / 5;

        // Calculate offset so that current heading is centered
        // The strip starts at -180 degrees, so heading 0 is at tick 36 (180/5)
        const centerOffset = COMPASS_WIDTH / 2;
        const headingOffset = (heading + 180) * pixelsPerDegree;
        const translateX = centerOffset - headingOffset;

        els.compassStrip.style.transform = `translateX(${translateX}px)`;
    }

    // ---- NUI Message Handler ----
    window.addEventListener('message', (event) => {
        const { module, action, data } = event.data;
        if (module !== 'hud') return;

        switch (action) {
            case 'navUpdate':
                if (!els.street) cacheDom();
                if (!compassBuilt) buildCompass();

                // Compass heading (sent every frame)
                if (data.heading !== undefined) {
                    updateCompass(data.heading);
                }
                if (data.direction !== undefined && els.direction) {
                    els.direction.textContent = data.direction;
                }

                // Street/zone/time (sent less frequently)
                if (data.street !== undefined && els.street) {
                    els.street.textContent = data.street;
                }
                if (data.crossing !== undefined && els.crossing) {
                    els.crossing.textContent = data.crossing;
                }
                if (data.zone !== undefined && els.zone) {
                    els.zone.textContent = data.zone;
                }
                if (data.time !== undefined && els.time) {
                    els.time.textContent = data.time;
                }
                break;

            case 'setVisible':
                if (els.nav) {
                    els.nav.classList.toggle('hidden', !data.visible);
                }
                break;
        }
    });

    window.addEventListener('DOMContentLoaded', () => {
        cacheDom();
        buildCompass();
    });
})();
