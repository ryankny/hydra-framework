/**
 * Hydra Notify - Toast Notification Engine
 *
 * Renders toast notifications with smooth animations,
 * auto-dismiss with progress bar, and stacking.
 */

(() => {
    'use strict';

    const MAX_VISIBLE = 6;
    const activeToasts = new Map();
    const queue = [];

    // SVG icons (inline for independence from hydra_ui)
    const icons = {
        info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>',
        success: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>',
        warning: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
        error: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>',
    };

    /**
     * Get position config
     */
    function getPositionConfig(position) {
        const isRight = position.includes('right');
        const isLeft = position.includes('left');
        const isBottom = position.includes('bottom');

        return {
            container: `notify-container-${position.replace(/\s+/g, '-')}`,
            enterAnim: isRight ? 'toast-enter-right' :
                        isLeft ? 'toast-enter-left' :
                        isBottom ? 'toast-enter-up' : 'toast-enter-down',
            exitAnim: isRight ? 'toast-exit-right' :
                       isLeft ? 'toast-exit-left' :
                       'toast-exit-right',
        };
    }

    /**
     * Create a toast element
     */
    function createToast(data) {
        const type = data.type || 'info';
        const position = data.position || 'top-right';
        const duration = data.duration || 5000;
        const posConfig = getPositionConfig(position);

        // Build toast DOM
        const toast = document.createElement('div');
        toast.className = `hydra-toast type-${type} ${posConfig.enterAnim}`;
        toast.dataset.id = data.id;

        // Icon
        const iconDiv = document.createElement('div');
        iconDiv.className = 'hydra-toast-icon';
        iconDiv.innerHTML = icons[type] || icons.info;
        const svg = iconDiv.querySelector('svg');
        if (svg) {
            svg.style.width = '20px';
            svg.style.height = '20px';
        }
        toast.appendChild(iconDiv);

        // Content
        const content = document.createElement('div');
        content.className = 'hydra-toast-content';

        if (data.title) {
            const title = document.createElement('div');
            title.className = 'hydra-toast-title';
            title.textContent = data.title;
            content.appendChild(title);
        }

        const message = document.createElement('div');
        message.className = 'hydra-toast-message' + (data.title ? '' : ' no-title');
        message.textContent = data.message || '';
        content.appendChild(message);

        toast.appendChild(content);

        // Progress bar
        const progress = document.createElement('div');
        progress.className = 'hydra-toast-progress';
        progress.style.animation = `toast-progress ${duration}ms linear forwards`;
        toast.appendChild(progress);

        // Get container
        const containerId = posConfig.container;
        let container = document.getElementById(containerId);
        if (!container) {
            container = document.getElementById('notify-container-top-right');
        }

        // Enforce max visible
        while (container.children.length >= MAX_VISIBLE) {
            const oldest = container.children[0];
            dismissToast(oldest, posConfig.exitAnim, container);
        }

        container.appendChild(toast);

        // Store reference
        const timeoutId = setTimeout(() => {
            dismissToast(toast, posConfig.exitAnim, container);
        }, duration);

        activeToasts.set(data.id, { element: toast, timeout: timeoutId, container });

        // Hover pauses auto-dismiss
        toast.addEventListener('mouseenter', () => {
            clearTimeout(timeoutId);
            progress.style.animationPlayState = 'paused';
        });

        toast.addEventListener('mouseleave', () => {
            // Calculate remaining time from progress width
            const computedWidth = parseFloat(getComputedStyle(progress).width);
            const containerWidth = parseFloat(getComputedStyle(toast).width);
            const remaining = (computedWidth / containerWidth) * duration;

            progress.style.animationPlayState = 'running';

            const newTimeout = setTimeout(() => {
                dismissToast(toast, posConfig.exitAnim, container);
            }, Math.max(remaining, 500));

            const existing = activeToasts.get(data.id);
            if (existing) existing.timeout = newTimeout;
        });
    }

    /**
     * Dismiss a toast with animation
     */
    function dismissToast(toast, exitAnim, container) {
        if (!toast || !toast.parentNode) return;

        // Clear stored reference
        const id = toast.dataset.id;
        if (id && activeToasts.has(id)) {
            clearTimeout(activeToasts.get(id).timeout);
            activeToasts.delete(id);
        }

        // Play exit animation
        toast.style.pointerEvents = 'none';

        // Remove all enter animations and add exit
        toast.className = toast.className.replace(/toast-enter-\w+/g, '').trim();
        toast.classList.add(exitAnim);

        setTimeout(() => {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
            processQueue();
        }, 280);
    }

    /**
     * Clear all notifications
     */
    function clearAll() {
        activeToasts.forEach(({ element, timeout, container }) => {
            clearTimeout(timeout);
            if (element.parentNode) {
                element.parentNode.removeChild(element);
            }
        });
        activeToasts.clear();
        queue.length = 0;
    }

    /**
     * Process queued notifications
     */
    function processQueue() {
        if (queue.length > 0 && activeToasts.size < MAX_VISIBLE) {
            createToast(queue.shift());
        }
    }

    // ---- NUI Message Handler ----
    window.addEventListener('message', (event) => {
        const { module, action, data } = event.data;
        if (module !== 'notify') return;

        switch (action) {
            case 'show':
                if (activeToasts.size >= MAX_VISIBLE) {
                    queue.push(data);
                } else {
                    createToast(data);
                }
                break;

            case 'clearAll':
                clearAll();
                break;

            case 'dismiss':
                if (data.id && activeToasts.has(data.id)) {
                    const toast = activeToasts.get(data.id);
                    dismissToast(toast.element, 'toast-exit-right', toast.container);
                }
                break;
        }
    });
})();
