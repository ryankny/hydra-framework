/**
 * Hydra Identity - Character Selection Screen
 *
 * Renders character cards, handles selection, spawn picker, and deletion.
 */

const HydraSelection = (() => {
    'use strict';

    let characters = [];
    let maxCharacters = 5;
    let spawnLocations = [];
    let canDelete = true;
    let selectedCharId = null;
    let selectedSpawn = null;

    // ---- Initialize ----
    function init(data) {
        characters = data.characters || [];
        maxCharacters = data.maxCharacters || 5;
        spawnLocations = data.spawnLocations || [];
        canDelete = data.canDelete !== false;
        selectedCharId = null;
        selectedSpawn = null;

        renderCharacters();
        renderSpawnLocations();
        bindEvents();
        hideSpawnPicker();
    }

    // ---- Render Character Cards ----
    function renderCharacters() {
        const grid = document.getElementById('character-grid');
        grid.innerHTML = '';

        for (const char of characters) {
            const card = document.createElement('div');
            card.className = 'char-card';
            card.dataset.id = char.id;

            const job = char.job && char.job.label ? char.job.label : 'Unemployed';
            const cash = char.accounts && char.accounts.cash != null ? char.accounts.cash : 0;
            const bank = char.accounts && char.accounts.bank != null ? char.accounts.bank : 0;

            card.innerHTML = `
                <div class="char-slot">${char.slot}</div>
                <div class="char-name">${escapeHtml(char.firstname)} ${escapeHtml(char.lastname)}</div>
                <div class="char-info">${capitalize(char.sex || 'male')} &middot; ${escapeHtml(char.nationality || 'American')}</div>
                <div class="char-info">DOB: ${escapeHtml(char.dob || 'N/A')}</div>
                <div class="char-job">${escapeHtml(job)}</div>
                <div class="char-money">
                    <div>Cash: <span>${HydraIdentity.formatMoney(cash)}</span></div>
                    <div>Bank: <span>${HydraIdentity.formatMoney(bank)}</span></div>
                </div>
                ${canDelete ? `<button class="char-delete" data-id="${char.id}" data-name="${escapeHtml(char.firstname)} ${escapeHtml(char.lastname)}" title="Delete">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                </button>` : ''}
            `;

            card.addEventListener('click', (e) => {
                if (e.target.closest('.char-delete')) return;
                selectCharacter(char.id);
            });

            grid.appendChild(card);
        }

        // Add "create new" card if slots available
        if (characters.length < maxCharacters) {
            const newCard = document.createElement('div');
            newCard.className = 'char-card-new';
            newCard.innerHTML = `
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
                <span>Create New Character</span>
            `;
            newCard.addEventListener('click', () => {
                HydraIdentity.callback('identity:startCreation');
            });
            grid.appendChild(newCard);
        }

        // Bind delete buttons
        grid.querySelectorAll('.char-delete').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                showDeleteModal(btn.dataset.id, btn.dataset.name);
            });
        });
    }

    // ---- Select Character ----
    function selectCharacter(charId) {
        selectedCharId = charId;

        // Highlight selected card
        document.querySelectorAll('.char-card').forEach(c => c.classList.remove('selected'));
        const card = document.querySelector(`.char-card[data-id="${charId}"]`);
        if (card) card.classList.add('selected');

        // Show spawn picker
        showSpawnPicker();
    }

    // ---- Spawn Picker ----
    function showSpawnPicker() {
        document.getElementById('spawn-picker').classList.remove('hidden');
        selectedSpawn = null;
        document.getElementById('btn-spawn-confirm').disabled = true;
        document.querySelectorAll('.spawn-card').forEach(c => c.classList.remove('selected'));
    }

    function hideSpawnPicker() {
        document.getElementById('spawn-picker').classList.add('hidden');
    }

    function renderSpawnLocations() {
        const container = document.getElementById('spawn-locations');
        container.innerHTML = '';

        for (let i = 0; i < spawnLocations.length; i++) {
            const loc = spawnLocations[i];
            const card = document.createElement('div');
            card.className = 'spawn-card';
            card.dataset.index = i;
            card.innerHTML = `
                <div class="spawn-name">${escapeHtml(loc.name)}</div>
                <div class="spawn-desc">${escapeHtml(loc.description || '')}</div>
            `;
            card.addEventListener('click', () => selectSpawn(i, card));
            container.appendChild(card);
        }
    }

    function selectSpawn(index, card) {
        selectedSpawn = spawnLocations[index];
        document.querySelectorAll('.spawn-card').forEach(c => c.classList.remove('selected'));
        card.classList.add('selected');
        document.getElementById('btn-spawn-confirm').disabled = false;
    }

    // ---- Delete Modal ----
    let pendingDeleteId = null;

    function showDeleteModal(charId, charName) {
        pendingDeleteId = charId;
        document.getElementById('delete-char-name').textContent = charName;
        document.getElementById('modal-delete').classList.remove('hidden');
    }

    function hideDeleteModal() {
        document.getElementById('modal-delete').classList.add('hidden');
        pendingDeleteId = null;
    }

    // ---- Update Characters ----
    function updateCharacters(newChars) {
        characters = newChars;
        renderCharacters();
        hideSpawnPicker();
        hideDeleteModal();
    }

    // ---- Bind Events ----
    function bindEvents() {
        document.getElementById('btn-spawn-back').onclick = () => {
            hideSpawnPicker();
            selectedCharId = null;
            document.querySelectorAll('.char-card').forEach(c => c.classList.remove('selected'));
        };

        document.getElementById('btn-spawn-confirm').onclick = () => {
            if (!selectedCharId) return;

            let spawnData = null;
            if (selectedSpawn && !selectedSpawn.is_last_location && selectedSpawn.coords) {
                spawnData = {
                    x: selectedSpawn.coords.x,
                    y: selectedSpawn.coords.y,
                    z: selectedSpawn.coords.z,
                    heading: selectedSpawn.heading || 0,
                };
            }

            HydraIdentity.callback('identity:selectCharacter', {
                characterId: parseInt(selectedCharId),
                spawnLocation: spawnData,
            });
        };

        document.getElementById('btn-delete-cancel').onclick = hideDeleteModal;
        document.getElementById('btn-delete-confirm').onclick = () => {
            if (pendingDeleteId) {
                HydraIdentity.callback('identity:deleteCharacter', {
                    characterId: parseInt(pendingDeleteId),
                });
            }
        };

        // Close modal on backdrop click
        document.querySelector('#modal-delete .modal-backdrop').onclick = hideDeleteModal;
    }

    // ---- Helpers ----
    function escapeHtml(str) {
        if (!str) return '';
        const div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    }

    function capitalize(s) {
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    return { init, updateCharacters };
})();
