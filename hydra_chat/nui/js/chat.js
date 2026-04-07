/**
 * Hydra Chat - NUI
 *
 * Chat window, input handling, message rendering,
 * auto-fade, command suggestions, and channel display.
 */
(() => {
    'use strict';

    const messagesEl = document.getElementById('chat-messages');
    const inputArea = document.getElementById('chat-input-area');
    const inputEl = document.getElementById('chat-input');
    const channelTag = document.getElementById('chat-channel-tag');
    const suggestionsEl = document.getElementById('chat-suggestions');

    const MAX_MESSAGES = 100;
    let isOpen = false;
    let fadeTimer = null;
    let fadeTimeout = 10000; // ms
    let suggestions = {};
    let messageHistory = [];
    let historyIndex = -1;

    // ---- NUI Callback ----
    function callback(name, data) {
        return fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {}),
        }).then(r => r.json()).catch(() => ({}));
    }

    function GetParentResourceName() {
        return window.GetParentResourceName ? window.GetParentResourceName() : 'hydra_chat';
    }

    // ---- Message Rendering ----
    function addMessage(data) {
        const el = document.createElement('div');
        el.className = 'chat-msg';

        let html = '';

        // Timestamp
        if (data.timestamp) {
            html += `<span class="msg-timestamp">${esc(data.timestamp)}</span>`;
        }

        // Tags
        if (data.tags && data.tags.length > 0) {
            for (const tag of data.tags) {
                const bg = hexToRgba(tag.color, 0.15);
                html += `<span class="msg-tag" style="background:${bg};color:${esc(tag.color)}">${esc(tag.text)}</span>`;
            }
        }

        // Format the message
        let formatted = data.format || '{name}: {message}';
        formatted = formatted.replace('{tag}', '');
        formatted = formatted.replace('{name}', `<span class="msg-name" style="color:${esc(data.channelColor || '#fff')}">${esc(data.name || '')}</span>`);
        formatted = formatted.replace('{message}', `<span class="msg-text">${esc(data.message || '')}</span>`);

        html += formatted;
        el.innerHTML = html;

        appendMessage(el);
    }

    function addSystemMessage(data) {
        const el = document.createElement('div');
        el.className = 'chat-msg system-msg';
        el.style.borderLeftColor = data.color || '#A0A0B8';
        el.innerHTML = `<span class="msg-text" style="color:${esc(data.color || '#A0A0B8')}">${esc(data.message || '')}</span>`;
        appendMessage(el);
    }

    function appendMessage(el) {
        messagesEl.appendChild(el);

        // Trim old messages
        while (messagesEl.children.length > MAX_MESSAGES) {
            messagesEl.removeChild(messagesEl.firstChild);
        }

        // Scroll to bottom
        messagesEl.scrollTop = messagesEl.scrollHeight;

        // Show and reset fade
        showMessages();
        resetFade();
    }

    function showMessages() {
        messagesEl.classList.remove('faded');
    }

    function fadeMessages() {
        if (!isOpen) {
            messagesEl.classList.add('faded');
        }
    }

    function resetFade() {
        clearTimeout(fadeTimer);
        if (fadeTimeout > 0 && !isOpen) {
            fadeTimer = setTimeout(fadeMessages, fadeTimeout);
        }
    }

    // ---- Input ----
    function openInput(data) {
        isOpen = true;
        inputArea.classList.remove('hidden');
        inputEl.value = '';
        inputEl.focus();
        historyIndex = -1;

        if (data) {
            setChannelDisplay(data.channelLabel, data.channelColor);
        }

        showMessages();
        clearTimeout(fadeTimer);
    }

    function closeInput() {
        isOpen = false;
        inputArea.classList.add('hidden');
        suggestionsEl.classList.add('hidden');
        resetFade();
    }

    function setChannelDisplay(label, color) {
        channelTag.textContent = label || 'Global';
        channelTag.style.background = hexToRgba(color || '#6C5CE7', 0.15);
        channelTag.style.color = color || '#6C5CE7';
    }

    // ---- Key Handling ----
    inputEl.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            const msg = inputEl.value.trim();
            if (msg.length > 0) {
                messageHistory.unshift(msg);
                if (messageHistory.length > 50) messageHistory.pop();
            }
            callback('chat:send', { message: msg });
            closeInput();
        } else if (e.key === 'Escape') {
            e.preventDefault();
            callback('chat:close');
            closeInput();
        } else if (e.key === 'Tab') {
            e.preventDefault();
            callback('chat:cycleChannel').then(data => {
                if (data && data.ok) {
                    setChannelDisplay(data.channelLabel, data.channelColor);
                }
            });
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            if (messageHistory.length > 0) {
                historyIndex = Math.min(historyIndex + 1, messageHistory.length - 1);
                inputEl.value = messageHistory[historyIndex];
            }
        } else if (e.key === 'ArrowDown') {
            e.preventDefault();
            if (historyIndex > 0) {
                historyIndex--;
                inputEl.value = messageHistory[historyIndex];
            } else {
                historyIndex = -1;
                inputEl.value = '';
            }
        }
    });

    // Command suggestions
    inputEl.addEventListener('input', () => {
        const val = inputEl.value;
        if (val.startsWith('/') && val.length > 1) {
            const query = val.toLowerCase();
            const matches = [];
            for (const [name, sug] of Object.entries(suggestions)) {
                if (name.toLowerCase().startsWith(query)) {
                    matches.push(sug);
                }
            }
            if (matches.length > 0) {
                showSuggestions(matches);
            } else {
                suggestionsEl.classList.add('hidden');
            }
        } else {
            suggestionsEl.classList.add('hidden');
        }
    });

    function showSuggestions(items) {
        suggestionsEl.innerHTML = '';
        for (const item of items.slice(0, 8)) {
            const el = document.createElement('div');
            el.className = 'suggestion-item';
            el.innerHTML = `<span class="sug-name">${esc(item.name)}</span><span class="sug-desc">${esc(item.description || '')}</span>`;
            el.addEventListener('click', () => {
                inputEl.value = item.name + ' ';
                inputEl.focus();
                suggestionsEl.classList.add('hidden');
            });
            suggestionsEl.appendChild(el);
        }
        suggestionsEl.classList.remove('hidden');
    }

    // ---- Utility ----
    function esc(str) {
        if (!str) return '';
        const d = document.createElement('div');
        d.textContent = String(str);
        return d.innerHTML;
    }

    function hexToRgba(hex, alpha) {
        if (!hex) return `rgba(108, 92, 231, ${alpha})`;
        hex = hex.replace('#', '');
        if (hex.length === 3) hex = hex[0]+hex[0]+hex[1]+hex[1]+hex[2]+hex[2];
        const r = parseInt(hex.substring(0, 2), 16);
        const g = parseInt(hex.substring(2, 4), 16);
        const b = parseInt(hex.substring(4, 6), 16);
        return `rgba(${r}, ${g}, ${b}, ${alpha})`;
    }

    // ---- Message Handler ----
    window.addEventListener('message', (event) => {
        const { module, action, data } = event.data;
        if (module !== 'chat') return;

        switch (action) {
            case 'open':
                openInput(data);
                break;
            case 'close':
                closeInput();
                break;
            case 'message':
                addMessage(data);
                break;
            case 'system':
                addSystemMessage(data);
                break;
            case 'switchChannel':
                if (data) setChannelDisplay(data.channelLabel, data.channelColor);
                break;
            case 'clear':
                messagesEl.innerHTML = '';
                break;
            case 'addSuggestion':
                if (data && data.name) suggestions[data.name] = data;
                break;
            case 'toggleVisibility':
                const root = document.getElementById('chat-root');
                if (root) {
                    root.classList.toggle('chat-hidden', !data.visible);
                }
                break;
        }
    });
})();
