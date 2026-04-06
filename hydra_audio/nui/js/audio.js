/**
 * Hydra Audio - NUI Audio Engine
 *
 * Handles HTML5 Audio playback for custom sound files (.ogg, .mp3, etc.).
 * Communicates with the Lua client via NUI messages and callbacks.
 */
const AudioManager = {
    /** @type {Object.<string, {audio: HTMLAudioElement, category: string, baseVolume: number, loop: boolean, fadeTimer: number|null}>} */
    sounds: {},
    masterVolume: 1.0,
    categoryVolumes: {},

    init() {
        window.addEventListener('message', (e) => {
            const data = e.data;
            if (!data || !data.action) return;

            switch (data.action) {
                case 'play':              this.play(data); break;
                case 'stop':              this.stop(data); break;
                case 'stopAll':           this.stopAll(data); break;
                case 'setVolume':         this.setVolume(data); break;
                case 'setMasterVolume':   this.setMasterVolume(data); break;
                case 'setCategoryVolume': this.setCategoryVolume(data); break;
                case 'fade':              this.fade(data); break;
                case 'pause':             this.pause(data); break;
                case 'resume':            this.resume(data); break;
            }
        });
    },

    /**
     * Calculate effective volume for a sound.
     * @param {number} base    - The sound's own volume (0-1).
     * @param {string} category - Category key.
     * @returns {number} Clamped 0-1.
     */
    computeVolume(base, category) {
        const catVol = this.categoryVolumes[category] || 1.0;
        return Math.min(1, Math.max(0, base * catVol * this.masterVolume));
    },

    /**
     * Play a custom sound through HTML5 Audio.
     * @param {Object} data - { id, url, volume, loop, category, fadeIn }
     */
    play(data) {
        // Stop existing sound with same id to avoid overlap
        if (this.sounds[data.id]) {
            this.destroySound(data.id);
        }

        const audio = new Audio(data.url);
        const baseVol = typeof data.volume === 'number' ? data.volume : 1.0;
        const category = data.category || 'sfx';
        const targetVol = this.computeVolume(baseVol, category);

        audio.volume = data.fadeIn ? 0 : targetVol;
        audio.loop = !!data.loop;

        // Prevent potential memory leaks — release on error
        audio.onerror = () => {
            this.destroySound(data.id);
            this.notifyEnded(data.id);
        };

        this.sounds[data.id] = {
            audio: audio,
            category: category,
            baseVolume: baseVol,
            loop: !!data.loop,
            fadeTimer: null,
        };

        audio.play().catch(() => {
            // Autoplay policy blocked — clean up silently
            this.destroySound(data.id);
            this.notifyEnded(data.id);
        });

        if (data.fadeIn) {
            this.fadeInternal(data.id, 0, targetVol, data.fadeIn);
        }

        if (!data.loop) {
            audio.addEventListener('ended', () => {
                this.destroySound(data.id);
                this.notifyEnded(data.id);
            }, { once: true });
        }
    },

    /**
     * Stop a sound, optionally with fade-out.
     * @param {Object} data - { id, fadeOut }
     */
    stop(data) {
        const entry = this.sounds[data.id];
        if (!entry) return;

        if (data.fadeOut && data.fadeOut > 0) {
            this.fadeInternal(data.id, entry.audio.volume, 0, data.fadeOut, () => {
                this.destroySound(data.id);
            });
        } else {
            this.destroySound(data.id);
        }
    },

    /**
     * Stop all sounds, optionally filtered by category.
     * @param {Object} data - { category, fadeOut }
     */
    stopAll(data) {
        const ids = Object.keys(this.sounds);
        for (const id of ids) {
            if (!data.category || this.sounds[id].category === data.category) {
                this.stop({ id: id, fadeOut: data.fadeOut });
            }
        }
    },

    /**
     * Set volume on a specific sound.
     * @param {Object} data - { id, volume }
     */
    setVolume(data) {
        const entry = this.sounds[data.id];
        if (!entry) return;
        entry.baseVolume = data.volume;
        entry.audio.volume = this.computeVolume(data.volume, entry.category);
    },

    /**
     * Update the master volume and recalculate all playing sounds.
     * @param {Object} data - { volume }
     */
    setMasterVolume(data) {
        this.masterVolume = data.volume;
        this.updateAllVolumes();
    },

    /**
     * Update a category's volume and recalculate affected sounds.
     * @param {Object} data - { category, volume }
     */
    setCategoryVolume(data) {
        this.categoryVolumes[data.category] = data.volume;
        this.updateAllVolumes();
    },

    /** Recalculate volumes for every active sound. */
    updateAllVolumes() {
        for (const id in this.sounds) {
            const s = this.sounds[id];
            // Skip sounds that are mid-fade — the fade will handle volume
            if (s.fadeTimer) continue;
            s.audio.volume = this.computeVolume(s.baseVolume, s.category);
        }
    },

    /**
     * Pause a sound.
     * @param {Object} data - { id }
     */
    pause(data) {
        const entry = this.sounds[data.id];
        if (entry) entry.audio.pause();
    },

    /**
     * Resume a paused sound.
     * @param {Object} data - { id }
     */
    resume(data) {
        const entry = this.sounds[data.id];
        if (entry) entry.audio.play().catch(() => {});
    },

    /**
     * External fade request.
     * @param {Object} data - { id, from, to, duration }
     */
    fade(data) {
        this.fadeInternal(data.id, data.from, data.to, data.duration);
    },

    /**
     * Internal fade implementation using requestAnimationFrame for smoothness.
     * @param {string}   id
     * @param {number}   from       - Starting volume.
     * @param {number}   to         - Target volume.
     * @param {number}   duration   - Duration in ms.
     * @param {Function} [onComplete] - Callback when fade finishes.
     */
    fadeInternal(id, from, to, duration, onComplete) {
        const entry = this.sounds[id];
        if (!entry) {
            if (onComplete) onComplete();
            return;
        }

        // Cancel any existing fade on this sound
        if (entry.fadeTimer) {
            cancelAnimationFrame(entry.fadeTimer);
            entry.fadeTimer = null;
        }

        const startTime = performance.now();
        const clamp = (v) => Math.min(1, Math.max(0, v));

        const tick = (now) => {
            // Sound may have been destroyed mid-fade
            if (!this.sounds[id]) {
                if (onComplete) onComplete();
                return;
            }

            const elapsed = now - startTime;
            const progress = Math.min(1, elapsed / duration);
            entry.audio.volume = clamp(from + (to - from) * progress);

            if (progress < 1) {
                entry.fadeTimer = requestAnimationFrame(tick);
            } else {
                entry.fadeTimer = null;
                if (onComplete) onComplete();
            }
        };

        entry.fadeTimer = requestAnimationFrame(tick);
    },

    /**
     * Clean up and release an audio element.
     * @param {string} id
     */
    destroySound(id) {
        const entry = this.sounds[id];
        if (!entry) return;

        if (entry.fadeTimer) {
            cancelAnimationFrame(entry.fadeTimer);
        }

        try {
            entry.audio.pause();
            entry.audio.removeAttribute('src');
            entry.audio.load(); // Release resources
        } catch (_) {
            // Ignore errors during cleanup
        }

        delete this.sounds[id];
    },

    /**
     * Notify the Lua client that a sound has finished.
     * @param {string} id
     */
    notifyEnded(id) {
        fetch(`https://${GetParentResourceName()}/audioEnded`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: id }),
        }).catch(() => {});
    },
};

AudioManager.init();
