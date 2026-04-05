/**
 * Hydra Loading Screen - Main Renderer
 *
 * Reads LOADING_CONFIG and builds the loading screen dynamically.
 * All visual elements are driven by the config - users never need
 * to edit this file.
 */

(() => {
    'use strict';

    const cfg = window.LOADING_CONFIG || {};
    const server = cfg.server || {};
    const bg = cfg.background || {};
    const tips = cfg.tips || {};
    const socials = cfg.socials || {};
    const credits = cfg.credits || {};
    const rules = cfg.rules || {};
    const audio = cfg.audio || {};
    const layout = cfg.layout || {};
    const changelog = cfg.changelog || {};

    let tipInterval = null;
    let slideshowInterval = null;

    // ---- Initialisation ----

    document.addEventListener('DOMContentLoaded', () => {
        setupBackground();
        setupServerInfo();
        setupProgress();
        setupTips();
        setupSocials();
        setupRules();
        setupCredits();
        setupChangelog();
        setupAudio();
        setupParticles();
        setupLayout();
        setupCustomHTML();
        listenForShutdown();
    });

    // ---- Background ----

    function setupBackground() {
        const bgContent = document.getElementById('bg-content');
        const overlay = document.getElementById('bg-overlay');

        switch (bg.type) {
            case 'image':
                if (bg.image) {
                    bgContent.style.backgroundImage = `url('${bg.image}')`;
                    if (bg.blur) bgContent.style.filter = `blur(${bg.blur}px)`;
                }
                break;

            case 'video':
                if (bg.video) {
                    const video = document.createElement('video');
                    video.src = bg.video;
                    video.autoplay = true;
                    video.loop = true;
                    video.muted = bg.videoMuted !== false;
                    video.playsInline = true;
                    if (bg.blur) video.style.filter = `blur(${bg.blur}px)`;
                    bgContent.appendChild(video);
                }
                break;

            case 'slideshow':
                if (bg.slideshow && bg.slideshow.length > 0) {
                    setupSlideshow(bgContent, bg.slideshow);
                }
                break;

            case 'gradient':
            default:
                bgContent.style.background = bg.gradient ||
                    'linear-gradient(135deg, #0F0F14 0%, #1a1a2e 30%, #16213e 60%, #0F0F14 100%)';
                break;
        }

        overlay.style.opacity = bg.overlayOpacity !== undefined ? bg.overlayOpacity : 0.5;
    }

    function setupSlideshow(container, images) {
        let current = 0;
        container.style.backgroundImage = `url('${images[0]}')`;
        container.style.transition = 'opacity 1.2s ease';
        if (bg.blur) container.style.filter = `blur(${bg.blur}px)`;

        slideshowInterval = setInterval(() => {
            current = (current + 1) % images.length;

            if (bg.slideshowTransition === 'fade') {
                container.style.opacity = '0';
                setTimeout(() => {
                    container.style.backgroundImage = `url('${images[current]}')`;
                    container.style.opacity = '1';
                }, 600);
            } else {
                container.style.backgroundImage = `url('${images[current]}')`;
            }
        }, (bg.slideshowInterval || 8) * 1000);
    }

    // ---- Server Info ----

    function setupServerInfo() {
        const nameEl = document.getElementById('server-name');
        const taglineEl = document.getElementById('server-tagline');
        const descEl = document.getElementById('server-description');
        const logoImg = document.getElementById('logo-img');

        nameEl.textContent = server.name || 'My Server';
        taglineEl.textContent = server.tagline || '';
        descEl.textContent = server.description || '';

        if (server.logo) {
            logoImg.src = server.logo;
        }
        if (server.logoSize) {
            logoImg.style.width = server.logoSize + 'px';
        }

        if (!server.tagline) taglineEl.style.display = 'none';
        if (!server.description) descEl.style.display = 'none';
    }

    // ---- Progress ----

    function setupProgress() {
        const bar = document.getElementById('progress-bar');
        const style = (cfg.theme && cfg.theme.progressStyle) || 'glow';
        if (style === 'glow') bar.classList.add('glow');

        if (!layout.showSpinner) {
            const spinner = document.getElementById('spinner');
            if (spinner) spinner.style.display = 'none';
        } else {
            const spinner = document.getElementById('spinner');
            if (layout.spinnerStyle === 'dots') spinner.classList.add('dots');
            else if (layout.spinnerStyle === 'pulse') spinner.classList.add('pulse');
        }

        // Listen for FiveM loading events
        window.addEventListener('message', (event) => {
            const data = event.data;

            if (data.eventName === 'loadProgress') {
                const count = data.loadingScreenData?.loadFraction;
                if (count !== undefined) {
                    const percent = Math.min(Math.round(count * 100), 100);
                    bar.style.width = percent + '%';
                    document.getElementById('progress-percent').textContent = percent + '%';

                    if (percent < 30) {
                        document.getElementById('progress-text').textContent = 'Loading game files...';
                    } else if (percent < 60) {
                        document.getElementById('progress-text').textContent = 'Loading resources...';
                    } else if (percent < 90) {
                        document.getElementById('progress-text').textContent = 'Preparing world...';
                    } else {
                        document.getElementById('progress-text').textContent = 'Almost ready...';
                    }
                }
            }

            if (data.eventName === 'startInitFunction') {
                const type = data.loadingScreenData?.type;
                if (type === 'MAP') {
                    document.getElementById('progress-text').textContent = 'Loading map...';
                } else if (type === 'INIT_SESSION') {
                    document.getElementById('progress-text').textContent = 'Joining session...';
                }
            }

            if (data.eventName === 'startDataFileEntries') {
                document.getElementById('progress-text').textContent = 'Loading data files...';
            }
        });

        // Simulate initial progress if no events arrive
        let simProgress = 0;
        const simInterval = setInterval(() => {
            const currentWidth = parseFloat(bar.style.width) || 0;
            if (currentWidth > 0) {
                // Real progress is coming in, stop simulation
                clearInterval(simInterval);
                return;
            }
            simProgress = Math.min(simProgress + Math.random() * 3, 30);
            bar.style.width = simProgress + '%';
            document.getElementById('progress-percent').textContent = Math.round(simProgress) + '%';
        }, 800);
    }

    // ---- Tips ----

    function setupTips() {
        if (!tips.enabled || !tips.messages || tips.messages.length === 0) return;

        const container = document.getElementById('tips-container');
        const textEl = document.getElementById('tip-text');
        container.style.display = 'flex';

        let current = 0;
        textEl.textContent = tips.messages[0];

        if (tips.messages.length > 1) {
            tipInterval = setInterval(() => {
                textEl.classList.add('fading');

                setTimeout(() => {
                    current = (current + 1) % tips.messages.length;
                    textEl.textContent = tips.messages[current];
                    textEl.classList.remove('fading');
                    textEl.classList.add('entering');

                    requestAnimationFrame(() => {
                        requestAnimationFrame(() => {
                            textEl.classList.remove('entering');
                        });
                    });
                }, 250);
            }, (tips.interval || 6) * 1000);
        }
    }

    // ---- Social Links ----

    function setupSocials() {
        const container = document.getElementById('socials');
        const links = [];

        const socialIcons = {
            discord: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M20.317 4.3698a19.7913 19.7913 0 00-4.8851-1.5152.0741.0741 0 00-.0785.0371c-.211.3753-.4447.8648-.6083 1.2495-1.8447-.2762-3.68-.2762-5.4868 0-.1636-.3933-.4058-.8742-.6177-1.2495a.077.077 0 00-.0785-.037 19.7363 19.7363 0 00-4.8852 1.515.0699.0699 0 00-.0321.0277C.5334 9.0458-.319 13.5799.0992 18.0578a.0824.0824 0 00.0312.0561c2.0528 1.5076 4.0413 2.4228 5.9929 3.0294a.0777.0777 0 00.0842-.0276c.4616-.6304.8731-1.2952 1.226-1.9942a.076.076 0 00-.0416-.1057c-.6528-.2476-1.2743-.5495-1.8722-.8923a.077.077 0 01-.0076-.1277c.1258-.0943.2517-.1923.3718-.2914a.0743.0743 0 01.0776-.0105c3.9278 1.7933 8.18 1.7933 12.0614 0a.0739.0739 0 01.0785.0095c.1202.099.246.1981.3728.2924a.077.077 0 01-.0066.1276 12.2986 12.2986 0 01-1.873.8914.0766.0766 0 00-.0407.1067c.3604.698.7719 1.3628 1.225 1.9932a.076.076 0 00.0842.0286c1.961-.6067 3.9495-1.5219 6.0023-3.0294a.077.077 0 00.0313-.0552c.5004-5.177-.8382-9.6739-3.5485-13.6604a.061.061 0 00-.0312-.0286z"/></svg>',
            website: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>',
            store: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/><path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"/></svg>',
            youtube: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/></svg>',
            tiktok: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.15 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z"/></svg>',
            twitter: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>',
            link: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>',
        };

        const builtInSocials = ['discord', 'website', 'store', 'youtube', 'tiktok', 'twitter'];

        builtInSocials.forEach(name => {
            if (socials[name]) {
                links.push({
                    label: name.charAt(0).toUpperCase() + name.slice(1),
                    url: socials[name],
                    icon: socialIcons[name],
                });
            }
        });

        if (socials.custom) {
            socials.custom.forEach(item => {
                links.push({
                    label: item.label,
                    url: item.url,
                    icon: socialIcons[item.icon] || socialIcons.link,
                });
            });
        }

        if (links.length === 0) return;

        container.style.display = 'flex';
        links.forEach(link => {
            const a = document.createElement('a');
            a.className = 'social-link';
            a.href = link.url;
            a.target = '_blank';
            a.innerHTML = link.icon + '<span>' + link.label + '</span>';
            container.appendChild(a);
        });
    }

    // ---- Rules ----

    function setupRules() {
        if (!rules.enabled || !rules.items || rules.items.length === 0) return;

        const toggle = document.getElementById('rules-toggle');
        const panel = document.getElementById('rules-panel');
        const list = document.getElementById('rules-list');
        const btn = document.getElementById('rules-btn');
        const closeBtn = document.getElementById('rules-close');

        toggle.style.display = 'block';

        rules.items.forEach(rule => {
            const li = document.createElement('li');
            li.textContent = rule;
            list.appendChild(li);
        });

        btn.addEventListener('click', () => {
            panel.style.display = 'block';
        });

        closeBtn.addEventListener('click', () => {
            panel.style.display = 'none';
        });
    }

    // ---- Credits ----

    function setupCredits() {
        if (!credits.enabled || !credits.staff || credits.staff.length === 0) return;

        const container = document.getElementById('credits');
        container.style.display = 'flex';

        credits.staff.forEach(member => {
            const item = document.createElement('div');
            item.className = 'credit-item';
            item.innerHTML = `<span class="credit-name">${member.name}</span><span class="credit-role">${member.role}</span>`;
            container.appendChild(item);
        });
    }

    // ---- Changelog ----

    function setupChangelog() {
        if (!changelog.enabled || !changelog.entries || changelog.entries.length === 0) return;

        const container = document.getElementById('changelog');
        const entries = document.getElementById('changelog-entries');
        container.style.display = 'block';

        changelog.entries.forEach(entry => {
            const div = document.createElement('div');
            div.className = 'changelog-entry';
            div.innerHTML = `
                <div class="changelog-date">${entry.date || ''}</div>
                <div class="changelog-entry-title">${entry.title || ''}</div>
                <div class="changelog-entry-text">${entry.text || ''}</div>
            `;
            entries.appendChild(div);
        });
    }

    // ---- Audio ----

    function setupAudio() {
        if (!audio.enabled || !audio.src) return;

        const audioEl = document.getElementById('bg-audio');
        const control = document.getElementById('audio-control');
        const btn = document.getElementById('audio-btn');
        const volume = document.getElementById('audio-volume');
        const iconOn = document.getElementById('audio-icon-on');
        const iconOff = document.getElementById('audio-icon-off');

        audioEl.src = audio.src;
        audioEl.volume = audio.volume || 0.3;
        audioEl.loop = audio.loop !== false;

        if (audio.showControl !== false) {
            control.style.display = 'flex';
        }

        volume.value = Math.round((audio.volume || 0.3) * 100);

        let muted = false;

        btn.addEventListener('click', () => {
            muted = !muted;
            audioEl.muted = muted;
            iconOn.style.display = muted ? 'none' : 'block';
            iconOff.style.display = muted ? 'block' : 'none';
        });

        volume.addEventListener('input', () => {
            audioEl.volume = volume.value / 100;
        });

        // Auto-play (may be blocked by browser)
        audioEl.play().catch(() => {
            // Autoplay blocked, user needs to interact
        });
    }

    // ---- Particles ----

    function setupParticles() {
        if (!layout.particles || layout.particleCount === 0) return;

        const canvas = document.getElementById('particles');
        const ctx = canvas.getContext('2d');
        const count = layout.particleCount || 30;
        const particles = [];

        function resize() {
            canvas.width = window.innerWidth;
            canvas.height = window.innerHeight;
        }
        resize();
        window.addEventListener('resize', resize);

        // Create particles
        for (let i = 0; i < count; i++) {
            particles.push({
                x: Math.random() * canvas.width,
                y: Math.random() * canvas.height,
                size: Math.random() * 2 + 0.5,
                speedX: (Math.random() - 0.5) * 0.3,
                speedY: (Math.random() - 0.5) * 0.3,
                opacity: Math.random() * 0.3 + 0.05,
            });
        }

        function animate() {
            ctx.clearRect(0, 0, canvas.width, canvas.height);

            particles.forEach(p => {
                p.x += p.speedX;
                p.y += p.speedY;

                // Wrap around
                if (p.x < 0) p.x = canvas.width;
                if (p.x > canvas.width) p.x = 0;
                if (p.y < 0) p.y = canvas.height;
                if (p.y > canvas.height) p.y = 0;

                ctx.beginPath();
                ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
                ctx.fillStyle = `rgba(108, 92, 231, ${p.opacity})`;
                ctx.fill();
            });

            // Draw faint connection lines between nearby particles
            for (let i = 0; i < particles.length; i++) {
                for (let j = i + 1; j < particles.length; j++) {
                    const dx = particles[i].x - particles[j].x;
                    const dy = particles[i].y - particles[j].y;
                    const dist = Math.sqrt(dx * dx + dy * dy);
                    if (dist < 150) {
                        ctx.beginPath();
                        ctx.moveTo(particles[i].x, particles[i].y);
                        ctx.lineTo(particles[j].x, particles[j].y);
                        ctx.strokeStyle = `rgba(108, 92, 231, ${0.05 * (1 - dist / 150)})`;
                        ctx.lineWidth = 0.5;
                        ctx.stroke();
                    }
                }
            }

            requestAnimationFrame(animate);
        }

        animate();
    }

    // ---- Layout ----

    function setupLayout() {
        const root = document.getElementById('loading-root');
        const pos = layout.position || 'center';

        if (pos === 'left') root.classList.add('pos-left');
        else if (pos === 'right') root.classList.add('pos-right');
        else if (pos === 'bottom') root.classList.add('pos-bottom');

        if (!layout.showHydraBadge) {
            const badge = document.getElementById('hydra-badge');
            if (badge) badge.style.display = 'none';
        }
    }

    // ---- Custom HTML ----

    function setupCustomHTML() {
        if (cfg.customHTML) {
            document.getElementById('custom-html').innerHTML = cfg.customHTML;
        }
    }

    // ---- Shutdown ----

    function listenForShutdown() {
        window.addEventListener('message', (event) => {
            if (event.data && event.data.action === 'shutdown') {
                const root = document.getElementById('loading-root');
                const bgLayer = document.getElementById('bg-layer');
                const particles = document.getElementById('particles');

                root.classList.add('shutdown');
                bgLayer.style.transition = 'opacity 1.2s ease';
                bgLayer.style.opacity = '0';
                particles.style.transition = 'opacity 1s ease';
                particles.style.opacity = '0';

                // Clean up intervals
                if (tipInterval) clearInterval(tipInterval);
                if (slideshowInterval) clearInterval(slideshowInterval);

                // Fade out audio
                const audioEl = document.getElementById('bg-audio');
                if (audioEl && !audioEl.paused) {
                    const fadeOut = setInterval(() => {
                        if (audioEl.volume > 0.05) {
                            audioEl.volume = Math.max(audioEl.volume - 0.05, 0);
                        } else {
                            audioEl.pause();
                            clearInterval(fadeOut);
                        }
                    }, 50);
                }
            }
        });
    }
})();
