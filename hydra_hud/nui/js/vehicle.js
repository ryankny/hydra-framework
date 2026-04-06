/**
 * Hydra HUD - Vehicle HUD Renderer
 *
 * Renders vehicle speedometer, RPM, gear, fuel, engine health,
 * and vehicle-type-specific displays (aircraft altimeter, boat anchor).
 */

(() => {
    'use strict';

    const els = {};
    let currentType = 'car';
    let lastSpeed = -1;

    function cacheDom() {
        els.vehicle = document.getElementById('hud-vehicle');
        els.speed = document.getElementById('veh-speed');
        els.speedUnit = document.getElementById('veh-speed-unit');
        els.rpmFill = document.getElementById('veh-rpm-fill');
        els.rpmContainer = document.getElementById('veh-rpm-container');
        els.gearValue = document.getElementById('veh-gear');
        els.gearContainer = document.getElementById('veh-gear-container');
        els.fuelFill = document.getElementById('veh-fuel-fill');
        els.fuelValue = document.getElementById('veh-fuel-value');
        els.fuelContainer = document.getElementById('veh-fuel-container');
        els.engineFill = document.getElementById('veh-engine-fill');
        els.engineValue = document.getElementById('veh-engine-value');
        els.engineContainer = document.getElementById('veh-engine-container');
        els.seatbelt = document.getElementById('ind-seatbelt');
        els.lock = document.getElementById('ind-lock');
        els.lights = document.getElementById('ind-lights');
        els.engineInd = document.getElementById('ind-engine');
        els.aircraft = document.getElementById('veh-aircraft');
        els.altitude = document.getElementById('veh-altitude');
        els.vspeed = document.getElementById('veh-vspeed');
        els.heading = document.getElementById('veh-heading');
        els.boat = document.getElementById('veh-boat');
        els.anchor = document.getElementById('ind-anchor');
    }

    /**
     * Configure HUD for vehicle type
     */
    function configureForType(type) {
        currentType = type;
        const isAircraft = type === 'plane' || type === 'helicopter';
        const isBoat = type === 'boat';
        const isBike = type === 'bike';

        // Show/hide type-specific panels
        if (els.aircraft) els.aircraft.style.display = isAircraft ? 'flex' : 'none';
        if (els.boat) els.boat.style.display = isBoat ? 'flex' : 'none';

        // Hide gear for aircraft/boats
        if (els.gearContainer) {
            els.gearContainer.style.display = (isAircraft || isBoat) ? 'none' : 'flex';
        }

        // Hide RPM for boats
        if (els.rpmContainer) {
            els.rpmContainer.style.display = isBoat ? 'none' : 'flex';
        }

        // Hide seatbelt for bikes/boats/aircraft
        if (els.seatbelt) {
            els.seatbelt.style.display = (isBike || isBoat || isAircraft) ? 'none' : 'flex';
        }
    }

    /**
     * Get speed color class
     */
    function getSpeedClass(speed) {
        if (speed > 150) return 'speed-danger';
        if (speed > 100) return 'speed-fast';
        return 'speed-normal';
    }

    /**
     * Update speed with smooth animation
     */
    function updateSpeed(speed) {
        if (!els.speed || speed === lastSpeed) return;

        // Animate number
        const from = lastSpeed >= 0 ? lastSpeed : speed;
        const duration = 120;
        const start = performance.now();

        function tick(now) {
            const elapsed = now - start;
            const t = Math.min(elapsed / duration, 1);
            const val = Math.round(from + (speed - from) * t);
            els.speed.textContent = val;
            if (t < 1) requestAnimationFrame(tick);
        }
        requestAnimationFrame(tick);

        // Color
        els.speed.className = 'speed-value ' + getSpeedClass(speed);
        lastSpeed = speed;
    }

    // ---- NUI Message Handler ----
    window.addEventListener('message', (event) => {
        const { module, action, data } = event.data;
        if (module !== 'hud') return;

        switch (action) {
            case 'vehicleEnter':
                if (!els.vehicle) cacheDom();
                els.vehicle.style.display = 'flex';
                els.vehicle.classList.remove('exiting');
                els.vehicle.classList.add('entering');
                configureForType(data.type || 'car');
                lastSpeed = -1;
                break;

            case 'vehicleExit':
                if (!els.vehicle) return;
                els.vehicle.classList.remove('entering');
                els.vehicle.classList.add('exiting');
                setTimeout(() => {
                    if (els.vehicle) els.vehicle.style.display = 'none';
                    els.vehicle.classList.remove('exiting');
                }, 300);
                lastSpeed = -1;
                break;

            case 'vehicleUpdate':
                if (!els.vehicle || els.vehicle.style.display === 'none') return;

                // Speed
                updateSpeed(data.speed || 0);
                if (els.speedUnit) els.speedUnit.textContent = data.speedUnit || 'MPH';

                // RPM
                if (els.rpmFill && data.rpm !== undefined) {
                    els.rpmFill.style.width = data.rpm + '%';
                    if (data.rpm > 80) {
                        els.rpmFill.classList.add('high-rpm');
                    } else {
                        els.rpmFill.classList.remove('high-rpm');
                    }
                }

                // Gear
                if (els.gearValue && data.gear !== undefined && data.gear !== null) {
                    const gearDisplay = data.gear === 0 ? 'R' : data.gear.toString();
                    els.gearValue.textContent = gearDisplay;
                    els.gearValue.className = 'gear-value' + (data.gear === 0 ? ' gear-reverse' : '');
                }

                // Fuel
                if (els.fuelFill && data.fuel !== undefined) {
                    els.fuelFill.style.width = data.fuel + '%';
                    els.fuelFill.className = 'veh-stat-fill fuel-fill' + (data.fuel < 20 ? ' low' : '');
                    if (els.fuelValue) els.fuelValue.textContent = data.fuel;
                }

                // Engine health
                if (els.engineFill && data.engineHealth !== undefined) {
                    els.engineFill.style.width = data.engineHealth + '%';
                    els.engineFill.className = 'veh-stat-fill engine-fill' + (data.engineHealth < 30 ? ' damaged' : '');
                    if (els.engineValue) els.engineValue.textContent = data.engineHealth;
                }

                // Indicators
                if (els.seatbelt && data.seatbelt !== undefined) {
                    els.seatbelt.className = 'indicator' + (data.seatbelt ? ' active' : ' inactive');
                }
                if (els.lock) {
                    els.lock.className = 'indicator' + (data.locked ? ' active' : '');
                }
                if (els.lights) {
                    els.lights.className = 'indicator' + (data.lightsOn ? ' active' : '');
                }
                if (els.engineInd) {
                    els.engineInd.className = 'indicator' +
                        (data.engineOn ? (data.engineHealth < 30 ? ' active damaged' : ' active') : '');
                }

                // Aircraft
                if (currentType === 'plane' || currentType === 'helicopter') {
                    if (els.altitude) els.altitude.textContent = data.altitude || 0;
                    if (els.vspeed) els.vspeed.textContent = data.verticalSpeed || 0;
                    if (els.heading) els.heading.textContent = data.heading || 0;
                }

                // Boat
                if (currentType === 'boat' && els.anchor) {
                    els.anchor.className = 'indicator' + (data.anchor ? ' active' : '');
                }
                break;

            case 'setVisible':
                if (els.vehicle && data.visible === false) {
                    els.vehicle.style.display = 'none';
                }
                break;
        }
    });

    window.addEventListener('DOMContentLoaded', cacheDom);
})();
