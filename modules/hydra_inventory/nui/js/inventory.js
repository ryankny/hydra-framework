/* ============================================
   Hydra Inventory - NUI Controller
   ============================================
   Handles all inventory UI logic: rendering,
   drag-and-drop, context menus, NUI messages.
   ============================================ */

(() => {
    'use strict';

    // ---- Constants ----
    const HOTBAR_SLOTS = 5;
    const IMAGE_PATH = 'nui://hydra_inventory/nui/img/';
    const MISC_CATEGORIES = ['general', 'electronic', 'document', 'key', 'drug', 'misc'];

    // ---- State ----
    const state = {
        open: false,
        playerInventory: null,
        secondaryInventory: null,
        money: { cash: 0, bank: 0, crypto: 0 },
        selectedSlot: null,       // { inventory: 'player'|'secondary', slot: number }
        activeCategory: 'all',
        searchQuery: '',
        secondarySearchQuery: '',
        dragData: null,           // { inventory, slot, item, el }
    };

    // ---- DOM Refs ----
    const dom = {
        root: document.getElementById('inventory-root'),
        backdrop: document.getElementById('inventory-backdrop'),
        container: document.getElementById('inventory-container'),

        playerPanel: document.getElementById('player-panel'),
        playerGrid: document.getElementById('player-grid'),
        playerWeightFill: document.getElementById('player-weight-fill'),
        playerWeightText: document.getElementById('player-weight-text'),
        playerSearch: document.getElementById('player-search'),
        playerCategories: document.getElementById('player-categories'),

        secondaryPanel: document.getElementById('secondary-panel'),
        secondaryGrid: document.getElementById('secondary-grid'),
        secondaryWeightFill: document.getElementById('secondary-weight-fill'),
        secondaryWeightText: document.getElementById('secondary-weight-text'),
        secondarySearch: document.getElementById('secondary-search'),
        secondaryLabel: document.getElementById('secondary-label'),
        secondaryIcon: document.getElementById('secondary-icon'),

        moneyCash: document.getElementById('money-cash'),
        moneyBank: document.getElementById('money-bank'),
        moneyCrypto: document.getElementById('money-crypto'),

        itemInfo: document.getElementById('item-info'),
        infoImg: document.getElementById('info-img'),
        infoName: document.getElementById('info-name'),
        infoDesc: document.getElementById('info-desc'),
        infoWeight: document.getElementById('info-weight'),
        infoCategory: document.getElementById('info-category'),
        infoCount: document.getElementById('info-count'),
        btnUse: document.getElementById('btn-use'),
        btnGive: document.getElementById('btn-give'),
        btnDrop: document.getElementById('btn-drop'),

        contextMenu: document.getElementById('inv-context-menu'),

        splitDialog: document.getElementById('split-dialog'),
        splitInput: document.getElementById('split-input'),
        splitConfirm: document.getElementById('split-confirm'),
        splitCancel: document.getElementById('split-cancel'),
    };

    // ---- Sound Hooks ----
    const sounds = {
        click: null,
        drop: null,
        error: null,
    };

    function playSound(name) {
        if (sounds[name]) {
            const audio = sounds[name].cloneNode();
            audio.volume = 0.3;
            audio.play().catch(() => {});
        }
    }

    // ---- Utilities ----
    function formatWeight(grams) {
        if (grams >= 1000) return (grams / 1000).toFixed(1) + 'kg';
        return grams + 'g';
    }

    function formatMoney(amount) {
        return '$' + Number(amount || 0).toLocaleString('en-US');
    }

    function nuiCallback(event, data = {}) {
        return fetch(`https://hydra_inventory/${event}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        }).catch(() => {});
    }

    function capitalize(str) {
        if (!str) return '';
        return str.charAt(0).toUpperCase() + str.slice(1);
    }

    function matchesCategory(item, category) {
        if (category === 'all') return true;
        if (category === 'misc') return MISC_CATEGORIES.includes(item.category);
        return item.category === category;
    }

    function matchesSearch(item, query) {
        if (!query) return true;
        const q = query.toLowerCase();
        return (item.label && item.label.toLowerCase().includes(q)) ||
               (item.name && item.name.toLowerCase().includes(q));
    }

    // ---- Weight Bar ----
    function updateWeightBar(fillEl, textEl, weight, maxWeight) {
        const pct = Math.min((weight / maxWeight) * 100, 100);
        fillEl.style.width = pct + '%';
        textEl.textContent = formatWeight(weight) + ' / ' + formatWeight(maxWeight);

        fillEl.classList.remove('warning', 'danger', 'critical');
        if (pct >= 95) fillEl.classList.add('critical');
        else if (pct >= 80) fillEl.classList.add('danger');
        else if (pct >= 60) fillEl.classList.add('warning');
    }

    // ---- Money ----
    function renderMoney() {
        dom.moneyCash.textContent = formatMoney(state.money.cash);
        dom.moneyBank.textContent = formatMoney(state.money.bank);
        dom.moneyCrypto.textContent = Number(state.money.crypto || 0).toLocaleString('en-US');
    }

    // ---- Slot Rendering ----
    function createSlotElement(invType, slotIndex, item, maxSlots) {
        const el = document.createElement('div');
        el.className = 'inv-slot';
        el.dataset.inventory = invType;
        el.dataset.slot = slotIndex;

        // Hotbar
        if (invType === 'player' && slotIndex < HOTBAR_SLOTS) {
            el.classList.add('hotbar');
            el.dataset.hotbar = slotIndex + 1;
        }

        if (!item || !item.name) {
            el.classList.add('empty');
            return el;
        }

        // Image
        const imgWrap = document.createElement('div');
        imgWrap.className = 'inv-slot-img';
        const img = document.createElement('img');
        img.src = IMAGE_PATH + (item.image || item.name + '.png');
        img.alt = item.label || item.name;
        img.draggable = false;
        img.onerror = function () { this.style.display = 'none'; };
        imgWrap.appendChild(img);
        el.appendChild(imgWrap);

        // Label
        const label = document.createElement('div');
        label.className = 'inv-slot-label';
        label.textContent = item.label || item.name;
        el.appendChild(label);

        // Count badge
        if (item.count > 1) {
            const count = document.createElement('div');
            count.className = 'inv-slot-count';
            count.textContent = item.count;
            el.appendChild(count);
        }

        // Weight
        const wt = document.createElement('div');
        wt.className = 'inv-slot-weight';
        wt.textContent = formatWeight((item.weight || 0) * (item.count || 1));
        el.appendChild(wt);

        // Draggable
        el.draggable = true;

        return el;
    }

    function renderGrid(gridEl, invType, inventory, searchQuery) {
        gridEl.innerHTML = '';
        if (!inventory) return;

        const slots = inventory.items || {};
        const maxSlots = inventory.maxSlots || 40;

        for (let i = 0; i < maxSlots; i++) {
            const item = slots[i] || null;

            const el = createSlotElement(invType, i, item, maxSlots);

            // Filter visibility
            if (item && item.name) {
                const catMatch = invType === 'player'
                    ? matchesCategory(item, state.activeCategory)
                    : true;
                const searchMatch = matchesSearch(item, searchQuery);
                if (!catMatch || !searchMatch) {
                    el.style.display = 'none';
                }
            }

            // Selection highlight
            if (state.selectedSlot &&
                state.selectedSlot.inventory === invType &&
                state.selectedSlot.slot === i) {
                el.classList.add('selected');
            }

            gridEl.appendChild(el);
        }
    }

    function renderPlayerGrid() {
        renderGrid(dom.playerGrid, 'player', state.playerInventory, state.searchQuery);
        if (state.playerInventory) {
            updateWeightBar(
                dom.playerWeightFill, dom.playerWeightText,
                state.playerInventory.weight, state.playerInventory.maxWeight
            );
        }
    }

    function renderSecondaryGrid() {
        renderGrid(dom.secondaryGrid, 'secondary', state.secondaryInventory, state.secondarySearchQuery);
        if (state.secondaryInventory) {
            updateWeightBar(
                dom.secondaryWeightFill, dom.secondaryWeightText,
                state.secondaryInventory.weight, state.secondaryInventory.maxWeight
            );
        }
    }

    function renderAll() {
        renderMoney();
        renderPlayerGrid();
        renderSecondaryGrid();
    }

    // ---- Item Info Panel ----
    function showItemInfo(invType, slotIndex) {
        const inv = invType === 'player' ? state.playerInventory : state.secondaryInventory;
        if (!inv) return;
        const item = (inv.items || {})[slotIndex];
        if (!item || !item.name) {
            hideItemInfo();
            return;
        }

        state.selectedSlot = { inventory: invType, slot: slotIndex };

        dom.infoName.textContent = item.label || item.name;
        dom.infoDesc.textContent = item.description || 'No description available.';
        dom.infoWeight.textContent = formatWeight((item.weight || 0) * (item.count || 1));
        dom.infoCategory.textContent = capitalize(item.category || 'general');
        dom.infoCount.textContent = item.count || 1;

        // Image
        dom.infoImg.innerHTML = '';
        const img = document.createElement('img');
        img.src = IMAGE_PATH + (item.image || item.name + '.png');
        img.alt = item.label || item.name;
        img.onerror = function () { this.style.display = 'none'; };
        dom.infoImg.appendChild(img);

        // Usability
        dom.btnUse.style.display = item.useable ? '' : 'none';

        dom.itemInfo.classList.remove('hidden');

        // Re-render to update selection highlight
        renderPlayerGrid();
        renderSecondaryGrid();
    }

    function hideItemInfo() {
        state.selectedSlot = null;
        dom.itemInfo.classList.add('hidden');
    }

    // ---- Context Menu ----
    function showContextMenu(x, y, invType, slotIndex) {
        const inv = invType === 'player' ? state.playerInventory : state.secondaryInventory;
        if (!inv) return;
        const item = (inv.items || {})[slotIndex];
        if (!item || !item.name) return;

        dom.contextMenu.dataset.inventory = invType;
        dom.contextMenu.dataset.slot = slotIndex;

        // Show/hide split based on count
        const splitBtn = dom.contextMenu.querySelector('[data-action="split"]');
        if (splitBtn) {
            splitBtn.style.display = (item.count > 1) ? '' : 'none';
        }

        // Show/hide use
        const useBtn = dom.contextMenu.querySelector('[data-action="use"]');
        if (useBtn) {
            useBtn.style.display = item.useable ? '' : 'none';
        }

        // Position
        const menuW = 160;
        const menuH = 160;
        let posX = x;
        let posY = y;
        if (posX + menuW > window.innerWidth) posX = window.innerWidth - menuW - 8;
        if (posY + menuH > window.innerHeight) posY = window.innerHeight - menuH - 8;

        dom.contextMenu.style.left = posX + 'px';
        dom.contextMenu.style.top = posY + 'px';
        dom.contextMenu.classList.remove('hidden');

        playSound('click');
    }

    function hideContextMenu() {
        dom.contextMenu.classList.add('hidden');
    }

    // ---- Split Dialog ----
    let splitCallback = null;

    function showSplitDialog(maxCount, callback) {
        splitCallback = callback;
        dom.splitInput.max = maxCount - 1;
        dom.splitInput.min = 1;
        dom.splitInput.value = Math.floor(maxCount / 2) || 1;
        dom.splitDialog.classList.remove('hidden');
        dom.splitInput.focus();
        dom.splitInput.select();
    }

    function hideSplitDialog() {
        dom.splitDialog.classList.add('hidden');
        splitCallback = null;
    }

    dom.splitConfirm.addEventListener('click', () => {
        const val = parseInt(dom.splitInput.value, 10);
        if (splitCallback && val > 0) {
            splitCallback(val);
        }
        hideSplitDialog();
    });

    dom.splitCancel.addEventListener('click', hideSplitDialog);

    dom.splitInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') dom.splitConfirm.click();
        if (e.key === 'Escape') hideSplitDialog();
    });

    // ---- Drag and Drop ----
    let dragGhost = null;

    function createDragGhost(item) {
        const ghost = document.createElement('div');
        ghost.className = 'inv-drag-ghost';
        const img = document.createElement('img');
        img.src = IMAGE_PATH + (item.image || item.name + '.png');
        img.onerror = function () { this.style.display = 'none'; };
        ghost.appendChild(img);
        document.body.appendChild(ghost);
        return ghost;
    }

    function removeDragGhost() {
        if (dragGhost) {
            dragGhost.remove();
            dragGhost = null;
        }
    }

    function getSlotFromEvent(e) {
        const slotEl = e.target.closest('.inv-slot');
        if (!slotEl) return null;
        return {
            inventory: slotEl.dataset.inventory,
            slot: parseInt(slotEl.dataset.slot, 10),
            el: slotEl,
        };
    }

    function getItemFromSlot(invType, slotIndex) {
        const inv = invType === 'player' ? state.playerInventory : state.secondaryInventory;
        if (!inv) return null;
        return (inv.items || {})[slotIndex] || null;
    }

    function canAcceptDrop(toInvType, toSlot, dragItem) {
        const targetInv = toInvType === 'player' ? state.playerInventory : state.secondaryInventory;
        if (!targetInv) return false;

        // If dropping in same slot, allow
        if (state.dragData &&
            state.dragData.inventory === toInvType &&
            state.dragData.slot === toSlot) return true;

        // Check weight
        const targetItem = getItemFromSlot(toInvType, toSlot);
        const itemWeight = (dragItem.weight || 0) * (dragItem.count || 1);

        // If swapping, subtract the target item weight
        let netWeight = itemWeight;
        if (targetItem && targetItem.name) {
            // Stacking same item
            if (targetItem.name === dragItem.name) {
                netWeight = 0; // weight already accounted for on the target side
            } else {
                netWeight = itemWeight - (targetItem.weight || 0) * (targetItem.count || 1);
            }
        }

        // Only check if moving to a different inventory
        if (state.dragData && state.dragData.inventory !== toInvType) {
            if (targetInv.weight + netWeight > targetInv.maxWeight) return false;
        }

        return true;
    }

    // Drag events on grids (using event delegation)
    function setupDragListeners(gridEl) {
        gridEl.addEventListener('dragstart', (e) => {
            const slotInfo = getSlotFromEvent(e);
            if (!slotInfo) return;

            const item = getItemFromSlot(slotInfo.inventory, slotInfo.slot);
            if (!item || !item.name) {
                e.preventDefault();
                return;
            }

            state.dragData = {
                inventory: slotInfo.inventory,
                slot: slotInfo.slot,
                item: item,
                el: slotInfo.el,
            };

            slotInfo.el.classList.add('dragging');

            // Custom ghost
            dragGhost = createDragGhost(item);
            // Hide default ghost
            const transparent = document.createElement('canvas');
            transparent.width = 1;
            transparent.height = 1;
            e.dataTransfer.setDragImage(transparent, 0, 0);
            e.dataTransfer.effectAllowed = 'move';

            playSound('click');
        });

        gridEl.addEventListener('dragover', (e) => {
            e.preventDefault();
            if (!state.dragData) return;

            const slotInfo = getSlotFromEvent(e);
            if (!slotInfo) return;

            // Clear all drag-over
            gridEl.querySelectorAll('.drag-over, .drag-over-invalid').forEach(el => {
                el.classList.remove('drag-over', 'drag-over-invalid');
            });

            if (canAcceptDrop(slotInfo.inventory, slotInfo.slot, state.dragData.item)) {
                slotInfo.el.classList.add('drag-over');
            } else {
                slotInfo.el.classList.add('drag-over-invalid');
            }
        });

        gridEl.addEventListener('dragleave', (e) => {
            const slotInfo = getSlotFromEvent(e);
            if (slotInfo) {
                slotInfo.el.classList.remove('drag-over', 'drag-over-invalid');
            }
        });

        gridEl.addEventListener('drop', (e) => {
            e.preventDefault();
            if (!state.dragData) return;

            const slotInfo = getSlotFromEvent(e);
            if (!slotInfo) return;

            slotInfo.el.classList.remove('drag-over', 'drag-over-invalid');

            if (!canAcceptDrop(slotInfo.inventory, slotInfo.slot, state.dragData.item)) {
                playSound('error');
                cleanupDrag();
                return;
            }

            // Don't move to same slot
            if (state.dragData.inventory === slotInfo.inventory &&
                state.dragData.slot === slotInfo.slot) {
                cleanupDrag();
                return;
            }

            nuiCallback('moveItem', {
                fromInventory: state.dragData.inventory,
                fromSlot: state.dragData.slot,
                toInventory: slotInfo.inventory,
                toSlot: slotInfo.slot,
                count: state.dragData.item.count || 1,
            });

            // Optimistic local swap
            performLocalMove(
                state.dragData.inventory, state.dragData.slot,
                slotInfo.inventory, slotInfo.slot
            );

            playSound('drop');
            cleanupDrag();
        });

        gridEl.addEventListener('dragend', () => {
            cleanupDrag();
        });
    }

    function cleanupDrag() {
        if (state.dragData && state.dragData.el) {
            state.dragData.el.classList.remove('dragging');
        }
        // Clear all drag-over highlights
        document.querySelectorAll('.drag-over, .drag-over-invalid').forEach(el => {
            el.classList.remove('drag-over', 'drag-over-invalid');
        });
        state.dragData = null;
        removeDragGhost();
    }

    // Move ghost with cursor
    document.addEventListener('dragover', (e) => {
        if (dragGhost) {
            dragGhost.style.left = (e.clientX - 28) + 'px';
            dragGhost.style.top = (e.clientY - 28) + 'px';
        }
    });

    function performLocalMove(fromInv, fromSlot, toInv, toSlot) {
        const srcItems = (fromInv === 'player' ? state.playerInventory : state.secondaryInventory).items;
        const dstItems = (toInv === 'player' ? state.playerInventory : state.secondaryInventory).items;

        const srcItem = srcItems[fromSlot] || null;
        const dstItem = dstItems[toSlot] || null;

        // Swap
        dstItems[toSlot] = srcItem;
        srcItems[fromSlot] = dstItem;

        // Recalculate weights
        recalcWeight('player');
        if (state.secondaryInventory) recalcWeight('secondary');

        renderAll();
    }

    function recalcWeight(invType) {
        const inv = invType === 'player' ? state.playerInventory : state.secondaryInventory;
        if (!inv) return;
        let total = 0;
        const items = inv.items || {};
        for (const key in items) {
            const item = items[key];
            if (item && item.name) {
                total += (item.weight || 0) * (item.count || 1);
            }
        }
        inv.weight = total;
    }

    // ---- Click Handlers (delegation) ----
    function setupClickListeners(gridEl) {
        // Single click = select
        gridEl.addEventListener('click', (e) => {
            hideContextMenu();
            const slotInfo = getSlotFromEvent(e);
            if (!slotInfo) return;

            const item = getItemFromSlot(slotInfo.inventory, slotInfo.slot);
            if (!item || !item.name) {
                hideItemInfo();
                return;
            }

            showItemInfo(slotInfo.inventory, slotInfo.slot);
            playSound('click');
        });

        // Double click = use
        gridEl.addEventListener('dblclick', (e) => {
            const slotInfo = getSlotFromEvent(e);
            if (!slotInfo) return;

            const item = getItemFromSlot(slotInfo.inventory, slotInfo.slot);
            if (!item || !item.name || !item.useable) return;

            nuiCallback('useItem', { slot: slotInfo.slot });
            playSound('click');
        });

        // Right click = context menu
        gridEl.addEventListener('contextmenu', (e) => {
            e.preventDefault();
            const slotInfo = getSlotFromEvent(e);
            if (!slotInfo) return;

            const item = getItemFromSlot(slotInfo.inventory, slotInfo.slot);
            if (!item || !item.name) return;

            showContextMenu(e.clientX, e.clientY, slotInfo.inventory, slotInfo.slot);
        });
    }

    // ---- Context Menu Actions ----
    dom.contextMenu.addEventListener('click', (e) => {
        const btn = e.target.closest('.inv-ctx-item');
        if (!btn) return;

        const action = btn.dataset.action;
        const invType = dom.contextMenu.dataset.inventory;
        const slotIndex = parseInt(dom.contextMenu.dataset.slot, 10);
        const item = getItemFromSlot(invType, slotIndex);
        if (!item) return;

        hideContextMenu();

        switch (action) {
            case 'use':
                if (item.useable) {
                    nuiCallback('useItem', { slot: slotIndex });
                }
                break;
            case 'give':
                nuiCallback('giveItem', { slot: slotIndex, count: item.count || 1 });
                break;
            case 'drop':
                nuiCallback('dropItem', { slot: slotIndex, count: item.count || 1 });
                break;
            case 'split':
                if (item.count > 1) {
                    showSplitDialog(item.count, (amount) => {
                        nuiCallback('splitItem', { slot: slotIndex, count: amount });
                    });
                }
                break;
        }

        playSound('click');
    });

    // ---- Info Panel Action Buttons ----
    dom.btnUse.addEventListener('click', () => {
        if (!state.selectedSlot) return;
        nuiCallback('useItem', { slot: state.selectedSlot.slot });
        playSound('click');
    });

    dom.btnGive.addEventListener('click', () => {
        if (!state.selectedSlot) return;
        const item = getItemFromSlot(state.selectedSlot.inventory, state.selectedSlot.slot);
        if (!item) return;
        nuiCallback('giveItem', { slot: state.selectedSlot.slot, count: item.count || 1 });
        playSound('click');
    });

    dom.btnDrop.addEventListener('click', () => {
        if (!state.selectedSlot) return;
        const item = getItemFromSlot(state.selectedSlot.inventory, state.selectedSlot.slot);
        if (!item) return;
        nuiCallback('dropItem', { slot: state.selectedSlot.slot, count: item.count || 1 });
        playSound('click');
    });

    // ---- Category Filters ----
    dom.playerCategories.addEventListener('click', (e) => {
        const btn = e.target.closest('.inv-cat-btn');
        if (!btn) return;

        dom.playerCategories.querySelectorAll('.inv-cat-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        state.activeCategory = btn.dataset.cat;
        renderPlayerGrid();
        playSound('click');
    });

    // ---- Search Bars ----
    dom.playerSearch.addEventListener('input', (e) => {
        state.searchQuery = e.target.value;
        renderPlayerGrid();
    });

    dom.secondarySearch.addEventListener('input', (e) => {
        state.secondarySearchQuery = e.target.value;
        renderSecondaryGrid();
    });

    // ---- Keyboard ----
    document.addEventListener('keydown', (e) => {
        if (!state.open) return;

        // Don't intercept if typing in an input
        if (document.activeElement && (document.activeElement.tagName === 'INPUT')) {
            if (e.key === 'Escape') {
                document.activeElement.blur();
                e.preventDefault();
            }
            return;
        }

        if (e.key === 'Escape') {
            e.preventDefault();
            closeInventory();
            return;
        }

        // Hotbar keys 1-5
        const num = parseInt(e.key, 10);
        if (num >= 1 && num <= HOTBAR_SLOTS) {
            const slotIndex = num - 1;
            const item = getItemFromSlot('player', slotIndex);
            if (item && item.name && item.useable) {
                nuiCallback('useItem', { slot: slotIndex });
                playSound('click');
            }
        }
    });

    // Close on backdrop click
    dom.backdrop.addEventListener('click', () => {
        hideContextMenu();
        hideItemInfo();
    });

    // Close context menu on click outside
    document.addEventListener('click', (e) => {
        if (!dom.contextMenu.classList.contains('hidden') &&
            !dom.contextMenu.contains(e.target)) {
            hideContextMenu();
        }
    });

    // ---- Open / Close ----
    function openInventory(data) {
        state.open = true;

        // Player inventory
        state.playerInventory = {
            items: indexItems(data.playerInventory.items),
            maxSlots: data.playerInventory.maxSlots || 40,
            maxWeight: data.playerInventory.maxWeight || 120000,
            weight: data.playerInventory.weight || 0,
        };

        // Secondary inventory
        if (data.secondaryInventory) {
            state.secondaryInventory = {
                id: data.secondaryInventory.id,
                type: data.secondaryInventory.type,
                label: data.secondaryInventory.label,
                items: indexItems(data.secondaryInventory.items),
                maxSlots: data.secondaryInventory.maxSlots || 30,
                maxWeight: data.secondaryInventory.maxWeight || 50000,
                weight: data.secondaryInventory.weight || 0,
            };

            dom.secondaryLabel.textContent = data.secondaryInventory.label || 'Storage';
            updateSecondaryIcon(data.secondaryInventory.type);
            dom.secondaryPanel.classList.remove('hidden');
        } else {
            state.secondaryInventory = null;
            dom.secondaryPanel.classList.add('hidden');
        }

        // Money
        if (data.money) {
            state.money = {
                cash: data.money.cash || 0,
                bank: data.money.bank || 0,
                crypto: data.money.crypto || 0,
            };
        }

        // Reset filters
        state.activeCategory = 'all';
        state.searchQuery = '';
        state.secondarySearchQuery = '';
        dom.playerSearch.value = '';
        dom.secondarySearch.value = '';
        dom.playerCategories.querySelectorAll('.inv-cat-btn').forEach(b => {
            b.classList.toggle('active', b.dataset.cat === 'all');
        });

        hideItemInfo();
        hideContextMenu();
        hideSplitDialog();

        renderAll();

        // Show with animation
        dom.root.classList.remove('hidden');
        // Force reflow for animation
        void dom.root.offsetHeight;
        dom.root.classList.add('visible');
    }

    function closeInventory() {
        if (!state.open) return;
        state.open = false;

        hideItemInfo();
        hideContextMenu();
        hideSplitDialog();
        cleanupDrag();

        dom.root.classList.remove('visible');

        setTimeout(() => {
            dom.root.classList.add('hidden');
        }, 300);

        nuiCallback('closeInventory', {});
    }

    function updateSecondaryIcon(type) {
        const iconMap = {
            trunk: 'fa-car',
            glovebox: 'fa-box-archive',
            stash: 'fa-vault',
            drop: 'fa-parachute-box',
            player: 'fa-user',
            shop: 'fa-store',
            dumpster: 'fa-dumpster',
        };
        dom.secondaryIcon.className = 'fa-solid ' + (iconMap[type] || 'fa-warehouse');
    }

    // Index items array into slot-keyed object
    function indexItems(items) {
        if (!items) return {};
        if (Array.isArray(items)) {
            const indexed = {};
            items.forEach((item, i) => {
                if (item) indexed[i] = item;
            });
            return indexed;
        }
        // Already an object
        return items;
    }

    // ---- NUI Message Handler ----
    window.addEventListener('message', (event) => {
        const data = event.data;
        if (!data || !data.type) return;

        switch (data.type) {
            case 'openInventory':
                openInventory(data);
                break;

            case 'closeInventory':
                closeInventory();
                break;

            case 'updateSlot': {
                const inv = data.inventory === 'player'
                    ? state.playerInventory
                    : state.secondaryInventory;
                if (!inv) break;
                if (data.item && data.item.name) {
                    inv.items[data.slot] = data.item;
                } else {
                    delete inv.items[data.slot];
                }
                recalcWeight(data.inventory);
                if (data.inventory === 'player') renderPlayerGrid();
                else renderSecondaryGrid();

                // Refresh info panel if this slot is selected
                if (state.selectedSlot &&
                    state.selectedSlot.inventory === data.inventory &&
                    state.selectedSlot.slot === data.slot) {
                    showItemInfo(data.inventory, data.slot);
                }
                break;
            }

            case 'updateWeight': {
                const inv = data.inventory === 'player'
                    ? state.playerInventory
                    : state.secondaryInventory;
                if (!inv) break;
                inv.weight = data.weight;
                inv.maxWeight = data.maxWeight || inv.maxWeight;
                if (data.inventory === 'player') {
                    updateWeightBar(dom.playerWeightFill, dom.playerWeightText, inv.weight, inv.maxWeight);
                } else {
                    updateWeightBar(dom.secondaryWeightFill, dom.secondaryWeightText, inv.weight, inv.maxWeight);
                }
                break;
            }

            case 'updateMoney':
                state.money.cash = data.cash ?? state.money.cash;
                state.money.bank = data.bank ?? state.money.bank;
                state.money.crypto = data.crypto ?? state.money.crypto;
                renderMoney();
                break;
        }
    });

    // ---- Initialize ----
    setupDragListeners(dom.playerGrid);
    setupDragListeners(dom.secondaryGrid);
    setupClickListeners(dom.playerGrid);
    setupClickListeners(dom.secondaryGrid);

})();
