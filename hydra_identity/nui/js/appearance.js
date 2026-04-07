/**
 * Hydra Identity - Appearance Customization Screen
 *
 * Face shape sliders, hair selector, overlays (beard, eyebrows, etc.),
 * and clothing component selectors with live preview.
 */

const HydraAppearance = (() => {
    'use strict';

    // Current appearance/clothing state
    let appearance = {
        face: { shape_first: 0, shape_second: 0, shape_mix: 0.5, skin_first: 0, skin_second: 0, skin_mix: 0.5 },
        features: {},
        hair: { style: 0, color: 0, highlight: 0 },
        eyes: { color: 0 },
        overlays: [],
        beard: { style: -1, color: 0, opacity: 1.0 },
        eyebrows: { style: 0, color: 0, opacity: 1.0 },
    };

    let clothing = {
        components: [],
        props: [],
    };

    let sex = 'male';

    // Limits (GTA defaults, approximate)
    const LIMITS = {
        parents: 46,
        hair_styles_m: 74, hair_styles_f: 78,
        hair_colors: 64,
        beard_styles: 30,
        eyebrow_styles: 34,
        eye_colors: 32,
        feature_count: 20,
        overlay_colors: 64,
    };

    // Component names for clothing tab
    const COMPONENT_NAMES = [
        'Head', 'Mask', 'Hair', 'Torso', 'Legs',
        'Bags', 'Shoes', 'Accessories', 'Undershirt',
        'Armor', 'Decals', 'Tops',
    ];

    const PROP_NAMES = [
        'Hats', 'Glasses', 'Ears', 'Watch', 'Bracelet',
    ];

    const FEATURE_NAMES = [
        'Nose Width', 'Nose Peak Height', 'Nose Peak Length', 'Nose Bone Height',
        'Nose Peak Lowering', 'Nose Bone Twist', 'Eyebrow Height', 'Eyebrow Depth',
        'Cheekbone Height', 'Cheekbone Width', 'Cheek Width', 'Eye Opening',
        'Lip Thickness', 'Jaw Bone Width', 'Jaw Bone Length', 'Chin Bone Height',
        'Chin Bone Length', 'Chin Bone Width', 'Chin Dimple', 'Neck Thickness',
    ];

    // Hair color palette (approximated GTA5 values)
    const HAIR_COLORS = [
        '#1C1C1C','#282218','#3C2A1E','#4A3526','#5C422E','#6B4F37',
        '#7C5E42','#8D6E4E','#9E7E5B','#AF8E68','#C09E76','#D1AE84',
        '#E2BE92','#F0CEA0','#A05028','#B85E30','#C96E38','#DA7E42',
        '#EB8E4C','#FF9E56','#E8D8A0','#F0E0B0','#F8E8C0','#FFF0D0',
        '#D0C0A0','#666666','#808080','#999999','#B3B3B3','#CCCCCC',
        '#3A1A08','#2A0A00',
    ];

    function init(data) {
        sex = (data && data.sex) || 'male';
        resetState();
        renderActiveTab();
        bindEvents();
    }

    function resetState() {
        appearance = {
            face: { shape_first: 0, shape_second: 0, shape_mix: 0.5, skin_first: 0, skin_second: 0, skin_mix: 0.5 },
            features: {},
            hair: { style: 0, color: 0, highlight: 0 },
            eyes: { color: 0 },
            beard: { style: -1, color: 0, opacity: 1.0 },
            eyebrows: { style: 0, color: 0, opacity: 1.0 },
        };
        clothing = { components: [], props: [] };

        for (let i = 0; i < 20; i++) appearance.features[i] = 0.0;
    }

    // ---- Tab Rendering ----
    function renderActiveTab() {
        const activeBtn = document.querySelector('.tab-btn.active');
        const tab = activeBtn ? activeBtn.dataset.tab : 'face';
        const content = document.getElementById('appearance-content');
        content.innerHTML = '';

        switch (tab) {
            case 'face': renderFaceTab(content); break;
            case 'hair': renderHairTab(content); break;
            case 'overlays': renderOverlaysTab(content); break;
            case 'clothing': renderClothingTab(content); break;
        }
    }

    // ---- Face Tab ----
    function renderFaceTab(container) {
        const section = createSection('Heritage');

        section.appendChild(createSelector('Mother', appearance.face.shape_first, 0, LIMITS.parents - 1, (v) => {
            appearance.face.shape_first = v;
            sendUpdate();
        }));

        section.appendChild(createSelector('Father', appearance.face.shape_second, 0, LIMITS.parents - 1, (v) => {
            appearance.face.shape_second = v;
            sendUpdate();
        }));

        section.appendChild(createSlider('Resemblance', appearance.face.shape_mix, 0, 1, 0.05, (v) => {
            appearance.face.shape_mix = v;
            sendUpdate();
        }, v => v <= 0.5 ? 'Mother' : 'Father'));

        section.appendChild(createSlider('Skin Tone', appearance.face.skin_mix, 0, 1, 0.05, (v) => {
            appearance.face.skin_mix = v;
            sendUpdate();
        }, v => v <= 0.5 ? 'Mother' : 'Father'));

        container.appendChild(section);

        // Face features
        const featureSection = createSection('Face Features');
        for (let i = 0; i < LIMITS.feature_count; i++) {
            const idx = i;
            featureSection.appendChild(createSlider(FEATURE_NAMES[i] || `Feature ${i}`, appearance.features[i] || 0, -1, 1, 0.05, (v) => {
                appearance.features[idx] = v;
                sendUpdate();
            }));
        }
        container.appendChild(featureSection);

        // Eye color
        const eyeSection = createSection('Eyes');
        eyeSection.appendChild(createSelector('Eye Color', appearance.eyes.color, 0, LIMITS.eye_colors - 1, (v) => {
            appearance.eyes.color = v;
            sendUpdate();
        }));
        container.appendChild(eyeSection);
    }

    // ---- Hair Tab ----
    function renderHairTab(container) {
        const maxStyles = sex === 'female' ? LIMITS.hair_styles_f : LIMITS.hair_styles_m;

        const section = createSection('Hair Style');
        section.appendChild(createSelector('Style', appearance.hair.style, 0, maxStyles - 1, (v) => {
            appearance.hair.style = v;
            sendUpdate();
        }));

        section.appendChild(createColorPicker('Color', appearance.hair.color, HAIR_COLORS, LIMITS.hair_colors, (v) => {
            appearance.hair.color = v;
            sendUpdate();
        }));

        section.appendChild(createColorPicker('Highlights', appearance.hair.highlight, HAIR_COLORS, LIMITS.hair_colors, (v) => {
            appearance.hair.highlight = v;
            sendUpdate();
        }));

        container.appendChild(section);
    }

    // ---- Overlays Tab (Beard, Eyebrows) ----
    function renderOverlaysTab(container) {
        // Beard
        const beardSection = createSection('Facial Hair');
        beardSection.appendChild(createSelector('Style', appearance.beard.style, -1, LIMITS.beard_styles - 1, (v) => {
            appearance.beard.style = v;
            sendUpdate();
        }));

        beardSection.appendChild(createSlider('Opacity', appearance.beard.opacity, 0, 1, 0.05, (v) => {
            appearance.beard.opacity = v;
            sendUpdate();
        }));

        beardSection.appendChild(createColorPicker('Color', appearance.beard.color, HAIR_COLORS, LIMITS.overlay_colors, (v) => {
            appearance.beard.color = v;
            sendUpdate();
        }));
        container.appendChild(beardSection);

        // Eyebrows
        const browSection = createSection('Eyebrows');
        browSection.appendChild(createSelector('Style', appearance.eyebrows.style, 0, LIMITS.eyebrow_styles - 1, (v) => {
            appearance.eyebrows.style = v;
            sendUpdate();
        }));

        browSection.appendChild(createSlider('Opacity', appearance.eyebrows.opacity, 0, 1, 0.05, (v) => {
            appearance.eyebrows.opacity = v;
            sendUpdate();
        }));

        browSection.appendChild(createColorPicker('Color', appearance.eyebrows.color, HAIR_COLORS, LIMITS.overlay_colors, (v) => {
            appearance.eyebrows.color = v;
            sendUpdate();
        }));
        container.appendChild(browSection);
    }

    // ---- Clothing Tab ----
    function renderClothingTab(container) {
        const compSection = createSection('Clothing');
        for (let i = 0; i < COMPONENT_NAMES.length; i++) {
            if (i === 0 || i === 2) continue; // Skip head and hair (managed by appearance)
            const idx = i;
            const current = getComponent(i);
            compSection.appendChild(createSelector(COMPONENT_NAMES[i], current.drawable, 0, 255, (v) => {
                setComponent(idx, v, 0);
                sendClothingUpdate();
            }));
        }
        container.appendChild(compSection);

        const propSection = createSection('Accessories');
        for (let i = 0; i < PROP_NAMES.length; i++) {
            const idx = i;
            const current = getProp(i);
            propSection.appendChild(createSelector(PROP_NAMES[i], current.drawable, -1, 255, (v) => {
                setProp(idx, v, 0);
                sendClothingUpdate();
            }));
        }
        container.appendChild(propSection);
    }

    // ---- Component/Prop Helpers ----
    function getComponent(id) {
        for (const c of clothing.components) {
            if (c.id === id) return c;
        }
        return { id, drawable: 0, texture: 0 };
    }

    function setComponent(id, drawable, texture) {
        for (let i = 0; i < clothing.components.length; i++) {
            if (clothing.components[i].id === id) {
                clothing.components[i].drawable = drawable;
                clothing.components[i].texture = texture;
                return;
            }
        }
        clothing.components.push({ id, drawable, texture, palette: 2 });
    }

    function getProp(id) {
        for (const p of clothing.props) {
            if (p.id === id) return p;
        }
        return { id, drawable: -1, texture: 0 };
    }

    function setProp(id, drawable, texture) {
        for (let i = 0; i < clothing.props.length; i++) {
            if (clothing.props[i].id === id) {
                clothing.props[i].drawable = drawable;
                clothing.props[i].texture = texture;
                return;
            }
        }
        clothing.props.push({ id, drawable, texture });
    }

    // ---- Send Updates to Lua ----
    function sendUpdate() {
        HydraIdentity.callback('identity:updateAppearance', { appearance });
    }

    function sendClothingUpdate() {
        HydraIdentity.callback('identity:updateAppearance', { clothing });
    }

    // ---- UI Component Builders ----
    function createSection(title) {
        const section = document.createElement('div');
        section.className = 'appearance-section active';
        const h4 = document.createElement('h4');
        h4.textContent = title;
        section.appendChild(h4);
        return section;
    }

    function createSlider(label, value, min, max, step, onChange, formatter) {
        const wrapper = document.createElement('div');
        wrapper.className = 'slider-control';

        const labelRow = document.createElement('div');
        labelRow.className = 'slider-label';

        const nameSpan = document.createElement('span');
        nameSpan.textContent = label;

        const valueSpan = document.createElement('span');
        valueSpan.className = 'slider-value';
        valueSpan.textContent = formatter ? formatter(value) : parseFloat(value).toFixed(2);

        labelRow.appendChild(nameSpan);
        labelRow.appendChild(valueSpan);

        const input = document.createElement('input');
        input.type = 'range';
        input.min = min;
        input.max = max;
        input.step = step;
        input.value = value;

        input.addEventListener('input', () => {
            const v = parseFloat(input.value);
            valueSpan.textContent = formatter ? formatter(v) : v.toFixed(2);
            onChange(v);
        });

        wrapper.appendChild(labelRow);
        wrapper.appendChild(input);
        return wrapper;
    }

    function createSelector(label, value, min, max, onChange) {
        const wrapper = document.createElement('div');
        wrapper.className = 'selector-control';

        const labelSpan = document.createElement('span');
        labelSpan.className = 'selector-label';
        labelSpan.textContent = label;

        const nav = document.createElement('div');
        nav.className = 'selector-nav';

        const btnPrev = document.createElement('button');
        btnPrev.type = 'button';
        btnPrev.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg>';

        const current = document.createElement('span');
        current.className = 'selector-current';
        current.textContent = value;

        const btnNext = document.createElement('button');
        btnNext.type = 'button';
        btnNext.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 18l6-6-6-6"/></svg>';

        let val = value;

        btnPrev.addEventListener('click', () => {
            val = val - 1 < min ? max : val - 1;
            current.textContent = val;
            onChange(val);
        });

        btnNext.addEventListener('click', () => {
            val = val + 1 > max ? min : val + 1;
            current.textContent = val;
            onChange(val);
        });

        nav.appendChild(btnPrev);
        nav.appendChild(current);
        nav.appendChild(btnNext);

        wrapper.appendChild(labelSpan);
        wrapper.appendChild(nav);
        return wrapper;
    }

    function createColorPicker(label, activeIndex, palette, maxColors, onChange) {
        const wrapper = document.createElement('div');

        const labelEl = document.createElement('div');
        labelEl.className = 'slider-label';
        const nameSpan = document.createElement('span');
        nameSpan.textContent = label;
        labelEl.appendChild(nameSpan);
        wrapper.appendChild(labelEl);

        const grid = document.createElement('div');
        grid.className = 'color-grid';

        const count = Math.min(palette.length, maxColors);
        for (let i = 0; i < count; i++) {
            const swatch = document.createElement('div');
            swatch.className = 'color-swatch' + (i === activeIndex ? ' active' : '');
            swatch.style.backgroundColor = palette[i] || '#333';
            swatch.dataset.index = i;

            swatch.addEventListener('click', () => {
                grid.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('active'));
                swatch.classList.add('active');
                onChange(i);
            });

            grid.appendChild(swatch);
        }

        wrapper.appendChild(grid);
        return wrapper;
    }

    // ---- Bind Events ----
    function bindEvents() {
        // Tab buttons
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.onclick = () => {
                document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                renderActiveTab();
            };
        });

        // Back button
        document.getElementById('btn-appearance-back').onclick = () => {
            HydraIdentity.callback('identity:backToSelection');
        };

        // Rotate ped
        document.getElementById('btn-rotate-left').onclick = () => {
            HydraIdentity.callback('identity:rotatePed', { direction: -15 });
        };

        document.getElementById('btn-rotate-right').onclick = () => {
            HydraIdentity.callback('identity:rotatePed', { direction: 15 });
        };

        // Camera controls
        const camUp = document.getElementById('btn-cam-up');
        const camDown = document.getElementById('btn-cam-down');
        const zoomIn = document.getElementById('btn-zoom-in');
        const zoomOut = document.getElementById('btn-zoom-out');
        if (camUp) camUp.onclick = () => HydraIdentity.callback('identity:cameraUp');
        if (camDown) camDown.onclick = () => HydraIdentity.callback('identity:cameraDown');
        if (zoomIn) zoomIn.onclick = () => HydraIdentity.callback('identity:zoomIn');
        if (zoomOut) zoomOut.onclick = () => HydraIdentity.callback('identity:zoomOut');

        // Finish creation
        document.getElementById('btn-finish').onclick = () => {
            HydraIdentity.callback('identity:finishCreation', {
                appearance,
                clothing,
            });
        };
    }

    return { init };
})();
