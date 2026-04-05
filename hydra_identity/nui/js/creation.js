/**
 * Hydra Identity - Character Creation Screen
 *
 * Handles the character details form: name, sex, DOB, nationality.
 * Sex toggle triggers ped model swap via NUI callback.
 */

const HydraCreation = (() => {
    'use strict';

    let currentSex = 'male';

    function init(config) {
        currentSex = 'male';
        populateNationalities(config.nationalities || []);
        resetForm(config.creation || {});
        bindEvents();
    }

    function populateNationalities(nationalities) {
        const select = document.getElementById('input-nationality');
        select.innerHTML = '';
        for (const nat of nationalities) {
            const opt = document.createElement('option');
            opt.value = nat;
            opt.textContent = nat;
            select.appendChild(opt);
        }
    }

    function resetForm(creation) {
        document.getElementById('input-firstname').value = '';
        document.getElementById('input-lastname').value = '';
        document.getElementById('input-dob').value = creation.default_dob || '1990-01-01';
        document.getElementById('input-nationality').value = 'American';

        // Reset sex toggle
        currentSex = 'male';
        document.querySelectorAll('.sex-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.sex === 'male');
        });
    }

    function bindEvents() {
        // Sex toggle
        document.querySelectorAll('.sex-btn').forEach(btn => {
            btn.onclick = () => {
                const sex = btn.dataset.sex;
                if (sex === currentSex) return;
                currentSex = sex;

                document.querySelectorAll('.sex-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');

                HydraIdentity.callback('identity:changeSex', { sex });
            };
        });

        // Back button
        document.getElementById('btn-creation-back').onclick = () => {
            HydraIdentity.callback('identity:backToSelection');
        };

        // Form submit
        document.getElementById('creation-form').onsubmit = (e) => {
            e.preventDefault();

            const firstname = document.getElementById('input-firstname').value.trim();
            const lastname = document.getElementById('input-lastname').value.trim();
            const dob = document.getElementById('input-dob').value;
            const nationality = document.getElementById('input-nationality').value;

            // Validate
            const config = HydraIdentity.getConfig();
            const minLen = (config.creation && config.creation.min_name_length) || 2;

            if (firstname.length < minLen) {
                HydraIdentity.showError(`First name must be at least ${minLen} characters.`);
                return;
            }
            if (lastname.length < minLen) {
                HydraIdentity.showError(`Last name must be at least ${minLen} characters.`);
                return;
            }

            // Validate only letters and hyphens
            const namePattern = /^[a-zA-Z\-]+$/;
            if (!namePattern.test(firstname)) {
                HydraIdentity.showError('First name can only contain letters and hyphens.');
                return;
            }
            if (!namePattern.test(lastname)) {
                HydraIdentity.showError('Last name can only contain letters and hyphens.');
                return;
            }

            // Validate age
            if (config.creation) {
                const birthDate = new Date(dob);
                const today = new Date();
                let age = today.getFullYear() - birthDate.getFullYear();
                const m = today.getMonth() - birthDate.getMonth();
                if (m < 0 || (m === 0 && today.getDate() < birthDate.getDate())) age--;

                if (age < (config.creation.min_age || 18)) {
                    HydraIdentity.showError(`Character must be at least ${config.creation.min_age || 18} years old.`);
                    return;
                }
                if (age > (config.creation.max_age || 85)) {
                    HydraIdentity.showError(`Character cannot be older than ${config.creation.max_age || 85} years.`);
                    return;
                }
            }

            HydraIdentity.callback('identity:submitCreation', {
                firstname,
                lastname,
                sex: currentSex,
                dob,
                nationality,
            });
        };
    }

    return { init };
})();
