/**
 * Hydra Framework - Reusable UI Components
 *
 * Component factory functions for common UI elements.
 * Used by HUD, notifications, menus, etc.
 */

const HydraComponents = (() => {
    'use strict';

    const { createElement, getIcon, formatNumber } = HydraUI;

    /**
     * Create a circular progress indicator
     * @param {object} opts - { value, max, size, strokeWidth, color, icon, label }
     * @returns {HTMLElement}
     */
    function circularProgress(opts) {
        const {
            value = 0, max = 100, size = 48, strokeWidth = 3,
            color = 'var(--hydra-primary)', icon, label, showValue = false
        } = opts;

        const wrapper = createElement('div', 'hydra-circular-progress', {
            style: { width: size + 'px', height: size + 'px', position: 'relative' }
        });

        const radius = (size - strokeWidth) / 2;
        const circumference = 2 * Math.PI * radius;
        const percent = Math.min(value / max, 1);
        const offset = circumference * (1 - percent);

        wrapper.innerHTML = `
            <svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" style="transform: rotate(-90deg)">
                <circle cx="${size/2}" cy="${size/2}" r="${radius}"
                    fill="none" stroke="rgba(255,255,255,0.08)" stroke-width="${strokeWidth}"/>
                <circle cx="${size/2}" cy="${size/2}" r="${radius}"
                    fill="none" stroke="${color}" stroke-width="${strokeWidth}"
                    stroke-dasharray="${circumference}" stroke-dashoffset="${offset}"
                    stroke-linecap="round"
                    style="transition: stroke-dashoffset 400ms cubic-bezier(0.4, 0, 0.2, 1)"/>
            </svg>
        `;

        // Center content (icon or value)
        const center = createElement('div', '', {
            style: {
                position: 'absolute', top: '50%', left: '50%',
                transform: 'translate(-50%, -50%)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
            }
        });

        if (icon) {
            center.appendChild(getIcon(icon, size * 0.35));
            center.style.color = color;
        } else if (showValue) {
            center.textContent = Math.round(percent * 100);
            center.style.fontSize = (size * 0.25) + 'px';
            center.style.fontWeight = '600';
            center.style.color = color;
        }

        wrapper.appendChild(center);
        wrapper._update = (newValue) => {
            const newPercent = Math.min(newValue / max, 1);
            const newOffset = circumference * (1 - newPercent);
            const circle = wrapper.querySelectorAll('circle')[1];
            if (circle) circle.setAttribute('stroke-dashoffset', newOffset);
            if (showValue && !icon) {
                center.textContent = Math.round(newPercent * 100);
            }
        };

        return wrapper;
    }

    /**
     * Create a horizontal bar indicator
     * @param {object} opts - { value, max, color, height, label, showPercent }
     * @returns {HTMLElement}
     */
    function barProgress(opts) {
        const {
            value = 0, max = 100, color = 'var(--hydra-primary)',
            height = 4, label, showPercent = false, width = '100%'
        } = opts;

        const wrapper = createElement('div', 'hydra-bar-progress', {
            style: { width }
        });

        if (label) {
            const labelRow = createElement('div', 'hydra-flex hydra-flex-between', {
                style: { marginBottom: '4px', fontSize: 'var(--hydra-text-xs)' }
            });
            const labelEl = createElement('span', 'hydra-text-muted', { text: label });
            labelRow.appendChild(labelEl);

            if (showPercent) {
                const pctEl = createElement('span', 'hydra-text-secondary', {
                    text: Math.round((value / max) * 100) + '%'
                });
                labelRow.appendChild(pctEl);
            }
            wrapper.appendChild(labelRow);
        }

        const track = createElement('div', 'hydra-progress', {
            style: { height: height + 'px' }
        });

        const bar = createElement('div', 'hydra-progress-bar', {
            style: {
                width: Math.min((value / max) * 100, 100) + '%',
                background: `linear-gradient(90deg, ${color}, ${color}dd)`,
            }
        });

        track.appendChild(bar);
        wrapper.appendChild(track);

        wrapper._update = (newValue) => {
            bar.style.width = Math.min((newValue / max) * 100, 100) + '%';
        };

        return wrapper;
    }

    /**
     * Create a stat display (icon + label + value)
     * @param {object} opts - { icon, label, value, color, size }
     */
    function statDisplay(opts) {
        const {
            icon, label, value = '', color = 'var(--hydra-text-secondary)',
            size = 'sm'
        } = opts;

        const wrapper = createElement('div', 'hydra-stat hydra-flex hydra-gap-sm', {
            style: { alignItems: 'center' }
        });

        if (icon) {
            const iconEl = getIcon(icon, size === 'sm' ? 14 : 18);
            iconEl.style.color = color;
            wrapper.appendChild(iconEl);
        }

        const textWrap = createElement('div', 'hydra-flex-col');

        if (label) {
            const labelEl = createElement('span', 'hydra-text-xs hydra-text-muted hydra-text-upper', {
                text: label
            });
            textWrap.appendChild(labelEl);
        }

        const valueEl = createElement('span', '', {
            text: value.toString(),
            style: {
                fontSize: size === 'sm' ? 'var(--hydra-text-sm)' : 'var(--hydra-text-md)',
                fontWeight: '600',
                color: 'var(--hydra-text-primary)',
            }
        });
        textWrap.appendChild(valueEl);
        wrapper.appendChild(textWrap);

        wrapper._updateValue = (newVal) => {
            valueEl.textContent = newVal.toString();
        };

        return wrapper;
    }

    return {
        circularProgress,
        barProgress,
        statDisplay,
    };
})();
