/**
 * Hydra Identity - Core NUI JavaScript
 *
 * Message router, shared utilities, and screen management.
 */

const HydraIdentity = (() => {
    'use strict';

    let config = {};
    let currentScreen = null;

    // ---- NUI Callback Helper ----
    function callback(name, data) {
        return fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {}),
        }).then(r => r.json()).catch(() => ({}));
    }

    function GetParentResourceName() {
        return window.GetParentResourceName ? window.GetParentResourceName() : 'hydra_identity';
    }

    // ---- Screen Management ----
    function showScreen(screenId) {
        const screens = document.querySelectorAll('.screen');
        screens.forEach(s => {
            if (!s.classList.contains('hidden')) {
                s.classList.add('fade-out');
                setTimeout(() => {
                    s.classList.add('hidden');
                    s.classList.remove('fade-out');
                }, 300);
            }
        });

        setTimeout(() => {
            const target = document.getElementById('screen-' + screenId);
            if (target) {
                target.classList.remove('hidden');
                target.classList.add('fade-in');
                setTimeout(() => target.classList.remove('fade-in'), 400);
            }
            currentScreen = screenId;
        }, currentScreen ? 320 : 0);
    }

    function hideAll() {
        document.querySelectorAll('.screen').forEach(s => s.classList.add('hidden'));
        currentScreen = null;
    }

    // ---- Error Toast ----
    let errorTimeout = null;
    function showError(msg) {
        const toast = document.getElementById('error-toast');
        const msgEl = document.getElementById('error-toast-msg');
        msgEl.textContent = msg;
        toast.classList.remove('hidden');
        clearTimeout(errorTimeout);
        errorTimeout = setTimeout(() => toast.classList.add('hidden'), 4000);
    }

    // ---- Format Money ----
    function formatMoney(n) {
        return '$' + (n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    }

    // ---- NUI Message Handler ----
    window.addEventListener('message', (event) => {
        const { module, action, data } = event.data;
        if (module !== 'identity') return;

        switch (action) {
            case 'show':
                config = data;
                if (data.screen === 'selection') {
                    HydraSelection.init(data);
                    showScreen('selection');
                }
                break;

            case 'hide':
                hideAll();
                break;

            case 'switchScreen':
                if (data.screen === 'selection') {
                    if (data.extra && data.extra.characters) {
                        HydraSelection.updateCharacters(data.extra.characters);
                    }
                    showScreen('selection');
                } else if (data.screen === 'creation') {
                    HydraCreation.init(config);
                    showScreen('creation');
                } else if (data.screen === 'appearance') {
                    HydraAppearance.init(data.extra);
                    showScreen('appearance');
                }
                break;

            case 'updateCharacters':
                if (data.characters) {
                    HydraSelection.updateCharacters(data.characters);
                }
                break;

            case 'showError':
                showError(data.message);
                break;
        }
    });

    // ---- Mouse wheel → zoom camera ----
    document.addEventListener('wheel', (e) => {
        if (currentScreen === 'creation' || currentScreen === 'appearance') {
            // Scroll up = zoom in (negative delta), scroll down = zoom out (positive delta)
            callback('identity:scroll', { delta: e.deltaY > 0 ? -1 : 1 });
        }
    }, { passive: true });

    // ---- Public API ----
    return {
        callback,
        showScreen,
        showError,
        formatMoney,
        getConfig: () => config,
    };
})();
