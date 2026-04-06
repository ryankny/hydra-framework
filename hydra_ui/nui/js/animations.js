/**
 * Hydra Framework - Animation Utilities
 *
 * Provides programmatic animation helpers beyond CSS classes.
 * Uses requestAnimationFrame for smooth, GPU-accelerated animations.
 */

const HydraAnimate = (() => {
    'use strict';

    /**
     * Animate a numeric value with easing
     * @param {object} opts - { from, to, duration, easing, onUpdate, onComplete }
     */
    function tween(opts) {
        const { from, to, duration = 300, easing = 'easeOutCubic', onUpdate, onComplete } = opts;
        const start = performance.now();

        function tick(now) {
            const elapsed = now - start;
            const t = Math.min(elapsed / duration, 1);
            const easedT = easings[easing] ? easings[easing](t) : t;
            const value = from + (to - from) * easedT;

            if (onUpdate) onUpdate(value, t);

            if (t < 1) {
                requestAnimationFrame(tick);
            } else if (onComplete) {
                onComplete(to);
            }
        }

        requestAnimationFrame(tick);
    }

    /**
     * Smoothly count a number up/down
     * @param {HTMLElement} el - Target element
     * @param {number} from - Start value
     * @param {number} to - End value
     * @param {number} duration - ms
     * @param {function} formatter - Optional format function
     */
    function countTo(el, from, to, duration = 500, formatter) {
        tween({
            from, to, duration,
            easing: 'easeOutCubic',
            onUpdate: (val) => {
                const rounded = Math.round(val);
                el.textContent = formatter ? formatter(rounded) : rounded.toString();
            }
        });
    }

    /**
     * Stagger animation of child elements
     * @param {HTMLElement} container
     * @param {string} animClass - CSS animation class to apply
     * @param {number} delay - Delay between each child (ms)
     */
    function stagger(container, animClass, delay = 50) {
        const children = container.children;
        for (let i = 0; i < children.length; i++) {
            children[i].style.animationDelay = `${i * delay}ms`;
            children[i].classList.add(animClass);
        }
    }

    /**
     * Animate element out, then remove from DOM
     * @param {HTMLElement} el
     * @param {string} animClass - Exit animation class
     * @param {number} duration - Animation duration before removal
     */
    function removeWithAnimation(el, animClass, duration = 300) {
        if (!el || !el.parentNode) return;
        el.classList.add(animClass);
        setTimeout(() => {
            if (el.parentNode) {
                el.parentNode.removeChild(el);
            }
        }, duration);
    }

    /**
     * Smoothly interpolate CSS property
     */
    function smoothSet(el, prop, value, duration = 300) {
        el.style.transition = `${prop} ${duration}ms cubic-bezier(0.4, 0, 0.2, 1)`;
        el.style[prop] = value;
    }

    // ---- Easing Functions ----
    const easings = {
        linear: t => t,
        easeInQuad: t => t * t,
        easeOutQuad: t => t * (2 - t),
        easeInOutQuad: t => t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t,
        easeInCubic: t => t * t * t,
        easeOutCubic: t => (--t) * t * t + 1,
        easeInOutCubic: t => t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1,
        easeOutBack: t => {
            const c = 1.70158;
            return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2);
        },
        easeOutElastic: t => {
            if (t === 0 || t === 1) return t;
            return Math.pow(2, -10 * t) * Math.sin((t - 0.075) * (2 * Math.PI) / 0.3) + 1;
        },
    };

    return {
        tween,
        countTo,
        stagger,
        removeWithAnimation,
        smoothSet,
        easings,
    };
})();
