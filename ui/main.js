// ───────────────────────────────────────────────────────────
//  UTILS
// ───────────────────────────────────────────────────────────
function resourceName() {
    return typeof GetParentResourceName !== 'undefined' ? GetParentResourceName() : 'bcc-train';
}
function post(endpoint, data) {
    fetch(`https://${resourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    }).catch(() => {});
}

// ───────────────────────────────────────────────────────────
//  DOM REFS — Station menu
// ───────────────────────────────────────────────────────────
const stationPanel  = document.getElementById('station-panel');
const menuTitle     = document.getElementById('menu-title');
const menuSubtext   = document.getElementById('menu-subtext');
const menuItems     = document.getElementById('menu-items');
const itemDesc      = document.getElementById('item-desc');
const menuBackBtn   = document.getElementById('menu-back-btn');

const junctionPanel = document.getElementById('junction-panel');
const junctionList  = document.getElementById('junction-list');
const jpClose       = document.getElementById('jp-close');
const jpReset       = document.getElementById('jp-reset');

// DOM REFS — Driving panel
const drivingPanel   = document.getElementById('driving-panel');
const engineLightEl  = document.getElementById('engine-light');
const engineBtn      = document.getElementById('engine-btn');
const resetBtn       = document.getElementById('reset-btn');
const deleteBtn      = document.getElementById('delete-btn');

const tachoNeedle    = document.getElementById('tacho-needle');
const tachoNum       = document.getElementById('tacho-num');
const pressNeedle    = document.getElementById('press-needle');
const pressNum       = document.getElementById('press-num');

const fuelFill       = document.getElementById('fuel-fill');
const fuelPct        = document.getElementById('fuel-pct');
const condFill       = document.getElementById('cond-fill');
const condPct        = document.getElementById('cond-pct');

const valveContainer = document.getElementById('valve-container');
const valveGroup     = document.getElementById('valve-group');
const targetPctEl    = document.getElementById('target-pct');
const currentPctEl   = document.getElementById('current-pct');

const camBadge           = document.getElementById('cam-badge');
const camTxt             = document.getElementById('cam-txt');
const boilerFill         = document.getElementById('boiler-fill');
const boilerPctEl        = document.getElementById('boiler-pct');
const tempFill           = document.getElementById('temp-fill');
const tempPctEl          = document.getElementById('temp-pct');
const oilBtn             = document.getElementById('oil-btn');
const conflictBadge      = document.getElementById('conflict-badge');
const brakePressNeedle   = document.getElementById('brake-press-needle');
const brakePressNum      = document.getElementById('brake-press-num');
const brakeKnob          = document.getElementById('brake-knob');
const brakeTrackWrap = document.getElementById('brake-track-wrap');
const brakeBgFill    = document.getElementById('brake-bg-fill');
const brakePctEl     = document.getElementById('brake-pct');

const dirVKnob       = document.getElementById('dir-v-knob');
const dirVTrack      = document.getElementById('dir-v-track');
const dirPosFwd      = document.getElementById('dir-pos-fwd');
const dirPosN        = document.getElementById('dir-pos-n');
const dirPosBwd      = document.getElementById('dir-pos-bwd');

// ───────────────────────────────────────────────────────────
//  STATE
// ───────────────────────────────────────────────────────────
const S = {
    // From Lua
    maxSpeed: 40, fuel: 0, maxFuel: 100, cond: 0, maxCond: 100,
    engine: false, fwd: false, bwd: false, speed: 0,
    cruiseControl: true, trackSwitch: false,
    // Valve / pressure
    valveAngle:     0,    // 0–270 deg, nastavuje targetPressure
    targetPressure: 0,    // 0–100 % — cíl ventilu (okamžitý)
    pistonPressure: 0,    // 0–100 % — aktuální tlak v pístech (zpožděný, max=boilerPressure)
    brakePressure:  0,    // 0–100 % — aktuální tlak v brzdách (zpožděný, max=boilerPressure)
    boilerPressure: 0,    // 0–100 % — dostupný tlak kotle (z Lua)
    // Teplota kotle
    boilerTemp:   0,      // 0–140 % — aktuální teplota (z Lua)
    boostActive:  false,  // aktivní olejový boost
    // Brzda
    brakePos: 100,        // 0–100 % — poloha páky (výchozí: zatažená)
    // Internal
    _lastSentSpeed:   -1,
    _lastSentPistons: -1,
    _lastSentBrakes:  -1
};

let junctionData = [];
let cameraMode   = false;

// ── Boiler gauge update ──────────────────────────────────────
function applyBoilerGauge(pct) {
    const p = Math.max(0, Math.min(100, pct));
    boilerFill.style.height = p + '%';
    boilerPctEl.textContent = Math.round(p) + '%';
    // Barva: zelená (nízký) → jantarová (střední) → červená (vysoký)
    if (p < 40) {
        boilerFill.style.background = 'linear-gradient(180deg,#44cc22,#1a5a0a)';
    } else if (p < 75) {
        boilerFill.style.background = 'linear-gradient(180deg,var(--amber),#7a3c00)';
    } else {
        boilerFill.style.background = 'linear-gradient(180deg,#ee3300,#6a0000)';
    }
}

// ── Temperature gauge update ─────────────────────────────────
function applyTempGauge(pct, boostActive) {
    const p = Math.max(0, Math.min(100, pct));
    tempFill.style.height = p + '%';
    tempPctEl.textContent = Math.round(S.boilerTemp) + '°';
    if (boostActive) {
        tempFill.style.background = 'linear-gradient(180deg,#ffcc00,#cc6600)';
        oilBtn.classList.add('active');
    } else if (p < 40) {
        tempFill.style.background = 'linear-gradient(180deg,#2299cc,#0a3a5a)';
        oilBtn.classList.remove('active');
    } else if (p < 75) {
        tempFill.style.background = 'linear-gradient(180deg,var(--amber),#7a3c00)';
        oilBtn.classList.remove('active');
    } else {
        tempFill.style.background = 'linear-gradient(180deg,#ee3300,#6a0000)';
        oilBtn.classList.remove('active');
    }
}

oilBtn.addEventListener('click', () => post('drivingAction', { action: 'boostBoiler' }));

// ───────────────────────────────────────────────────────────
//  CAMERA MODE TOGGLE
// ───────────────────────────────────────────────────────────
function setCameraMode(active) {
    cameraMode = active;
    if (active) {
        drivingPanel.classList.add('camera-mode');
        camBadge.classList.add('camera-active');
        camTxt.textContent = 'KAMERA';
    } else {
        drivingPanel.classList.remove('camera-mode');
        camBadge.classList.remove('camera-active');
        camTxt.textContent = 'PANEL';
    }
    post('drivingAction', { action: 'toggleCamera', value: active });
}

// Klik na badge = ruční přepnutí
camBadge.addEventListener('click', e => {
    e.stopPropagation();
    setCameraMode(!cameraMode);
});

// Mezerník v panel módu → přepne na kameru
document.addEventListener('keydown', e => {
    if (e.code === 'Space' && drivingPanel.classList.contains('visible') && !cameraMode) {
        e.preventDefault();
        setCameraMode(true);
    }
});

// ───────────────────────────────────────────────────────────
//  NEEDLE HELPER
//  Gauge geometry: center (67,66), arc endpoints at y=72,
//  arc range = left (speed 0) → right (speed max)
// ───────────────────────────────────────────────────────────
function setNeedle(needle, ratio) {
    const r   = Math.max(0, Math.min(1, ratio));
    const rad = Math.PI * (1 - r);
    needle.setAttribute('x2', (67 + Math.cos(rad) * 48).toFixed(1));
    needle.setAttribute('y2', (66 - Math.sin(rad) * 48).toFixed(1));
}

// ───────────────────────────────────────────────────────────
//  MESSAGE HANDLER
// ───────────────────────────────────────────────────────────
window.addEventListener('message', ({ data: d }) => {
    if (!d || !d.type) return;
    switch (d.type) {
        case 'showStationMenu':  openStationMenu(d); break;
        case 'closeStationMenu': closeStationMenu();  break;
        case 'toggleHUD':
            if (d.HUDvisible) {
                S.maxSpeed = d.maxSpeed || 40;
                S.fuel = d.fuel ?? 0;   S.maxFuel = d.maxFuel ?? 100;
                S.cond = d.condition ?? 0; S.maxCond = d.maxCondition ?? 100;
                applyGauges();
                drivingPanel.classList.add('visible');
                // Obnov uložený stav (ventil, brzda, směr)
                requestAnimationFrame(() => {
                    valveGroup.setAttribute('transform', `rotate(${S.valveAngle},70,70)`);
                    targetPctEl.textContent  = Math.round(S.targetPressure) + '%';
                    currentPctEl.textContent = Math.round(S.pistonPressure) + '%';
                    setBrakeKnobPos(S.brakePos);
                    applyDrivingUI();
                });
            } else {
                drivingPanel.classList.remove('visible');
                junctionPanel.classList.remove('visible');
                // Jen skryj panel a resetuj kameru — stav si pamatujeme
                if (cameraMode) setCameraMode(false);
            }
            break;
        case 'resetTrainState':
            // Plný reset — posílá se jen při odvozu do depa nebo opuštění vlaku
            S.engine = S.fwd = S.bwd = false;
            S.speed = S.valveAngle = S.targetPressure = 0;
            S.pistonPressure = S.brakePressure = S.boilerPressure = 0;
            S.boilerTemp = 0; S.boostActive = false;
            S.brakePos = 100;
            S._lastSentSpeed = S._lastSentPistons = S._lastSentBrakes = -1;
            applyBoilerGauge(0);
            applyTempGauge(0, false);
            conflictBadge.classList.remove('active');
            valveGroup.setAttribute('transform', 'rotate(0,70,70)');
            targetPctEl.textContent  = '0%';
            currentPctEl.textContent = '0%';
            setBrakeKnobPos(100);
            applyDrivingUI();
            break;
        case 'update':
            if (d.fuel      != null) S.fuel = d.fuel;
            if (d.condition != null) S.cond = d.condition;
            applyGauges();
            break;
        case 'updateDriving':
            if (d.engineStarted  !== undefined) S.engine = d.engineStarted;
            if (d.forwardActive  !== undefined) S.fwd    = d.forwardActive;
            if (d.backwardActive !== undefined) S.bwd    = d.backwardActive;
            if (d.speed          !== undefined) S.speed  = d.speed;
            if (d.maxSpeed       !== undefined) S.maxSpeed = d.maxSpeed;
            if (d.cruiseControl  !== undefined) S.cruiseControl = d.cruiseControl;
            applyDrivingUI();
            break;
        case 'showJunctions':
            showJunctions(d.junctions || []);
            break;
        case 'updateJunction':
            updateJunctionUI(d.idx, d.state);
            break;
        case 'hideJunctions':
            junctionPanel.classList.remove('visible');
            break;
        case 'resetJunctionsUI':
            junctionData.forEach(j => { j.state = false; });
            renderJunctions();
            break;
        case 'setCameraMode':
            setCameraMode(!!d.value);
            break;
        case 'boilerUpdate':
            S.boilerPressure = d.pressure ?? 0;
            applyBoilerGauge(S.boilerPressure);
            break;
        case 'boilerTempUpdate':
            S.boilerTemp  = d.temp  ?? S.boilerTemp;
            if (d.boostActive !== undefined) S.boostActive = d.boostActive;
            applyTempGauge(Math.min(100, S.boilerTemp), S.boostActive);
            break;
        case 'conflictDamage':
            conflictBadge.classList.toggle('active', !!d.active);
            break;
    }
});

// ───────────────────────────────────────────────────────────
//  DRIVING PANEL — GAUGES
// ───────────────────────────────────────────────────────────
function applyGauges() {
    const fp = S.maxFuel > 0 ? (S.fuel / S.maxFuel) * 100 : 0;
    const cp = S.maxCond > 0 ? (S.cond / S.maxCond) * 100 : 0;
    fuelFill.style.height = Math.max(0, Math.min(100, fp)) + '%';
    fuelPct.textContent   = Math.round(fp) + '%';
    condFill.style.height = Math.max(0, Math.min(100, cp)) + '%';
    condPct.textContent   = Math.round(cp) + '%';
    fuelFill.style.background = fp < 20
        ? 'linear-gradient(180deg,#cc2200,#6a0000)'
        : 'linear-gradient(180deg,var(--amber),#7a3c00)';
    condFill.style.background = cp < 20
        ? 'linear-gradient(180deg,#cc2200,#6a0000)'
        : 'linear-gradient(180deg,#4a9a2a,#1a4a0a)';
}

function applySpeed() {
    const v     = Math.abs(S.speed);
    const ratio = S.maxSpeed > 0 ? Math.min(1, v / 40) : 0; // tachometer fixed 0-40
    tachoNum.textContent = Math.round(v);
    setNeedle(tachoNeedle, ratio);
}

// Pístový budík — nezávislý na brzdách
function applyPistonGauge(pct) {
    const ratio = Math.max(0, Math.min(100, pct)) / 100;
    pressNum.textContent = (ratio * 10).toFixed(1);
    setNeedle(pressNeedle, ratio);
}

// Brzdový budík — nezávislý na pístech
function applyBrakeGauge(pct) {
    const ratio = Math.max(0, Math.min(100, pct)) / 100;
    brakePressNum.textContent = (ratio * 10).toFixed(1);
    setNeedle(brakePressNeedle, ratio);
}

function applyDrivingUI() {
    engineLightEl.className = 'engine-light' + (S.engine ? ' on' : '');
    engineBtn.className     = 'cbtn engine'  + (S.engine ? ' active' : '');
    resetBtn.className      = 'cbtn'         + (S.trackSwitch ? ' active' : '');

    // Vertical direction lever — snap knob to fwd/N/bwd position
    // Track height 90px, knob height 20px → fwd:5px, N:35px, bwd:65px
    dirPosFwd.className = 'dir-v-pos' + (S.fwd              ? ' active-fwd' : '');
    dirPosN.className   = 'dir-v-pos' + (!S.fwd && !S.bwd   ? ' active-n'   : '');
    dirPosBwd.className = 'dir-v-pos' + (S.bwd              ? ' active-bwd' : '');
    dirVKnob.style.top  = S.fwd ? '5px' : S.bwd ? '65px' : '35px';

    applySpeed();
}

// ───────────────────────────────────────────────────────────
//  VALVE DRAG  (vertical drag → rotate the big red wheel)
// ───────────────────────────────────────────────────────────
let valveDragActive    = false;
let valveDragStartY    = 0;
let valveDragStartAngle = 0;

valveContainer.addEventListener('mousedown', e => {
    valveDragActive     = true;
    valveDragStartY     = e.clientY;
    valveDragStartAngle = S.valveAngle;
    e.preventDefault();
});

document.addEventListener('mousemove', e => {
    if (!valveDragActive) return;
    const dy       = valveDragStartY - e.clientY; // up = positive
    const newAngle = Math.max(0, Math.min(270, valveDragStartAngle + dy * 1.4));
    S.valveAngle       = newAngle;
    S.targetPressure   = newAngle / 270 * 100;
    valveGroup.setAttribute('transform', `rotate(${newAngle},70,70)`);
    targetPctEl.textContent = Math.round(S.targetPressure) + '%';
});

document.addEventListener('mouseup', () => { valveDragActive = false; });

// ───────────────────────────────────────────────────────────
//  BRAKE LEVER  (drag down = increase brake)
// ───────────────────────────────────────────────────────────
let brakeDragActive    = false;
let brakeDragStartY    = 0;
let brakeDragStartPos  = 0;

function setBrakeKnobPos(pct) {
    const rect   = brakeTrackWrap.getBoundingClientRect();
    const usable = (rect.height > 0 ? rect.height : 88) - 12 - 18;
    const topPx  = 6 + (pct / 100) * usable;
    brakeKnob.style.top    = topPx + 'px';
    brakeBgFill.style.height = pct + '%';
    brakePctEl.textContent = Math.round(pct) + '%';
}

brakeKnob.addEventListener('mousedown', e => {
    brakeDragActive    = true;
    brakeDragStartY    = e.clientY;
    brakeDragStartPos  = S.brakePos;
    e.preventDefault();
});

document.addEventListener('mousemove', e => {
    if (!brakeDragActive) return;
    const rect   = brakeTrackWrap.getBoundingClientRect();
    const usable = rect.height - 12 - 18;
    const dy     = e.clientY - brakeDragStartY; // down = positive = more brake
    const newPos = Math.max(0, Math.min(100, brakeDragStartPos + (dy / usable) * 100));
    S.brakePos = newPos;
    setBrakeKnobPos(newPos);
});

document.addEventListener('mouseup', () => { brakeDragActive = false; });

// ───────────────────────────────────────────────────────────
//  DIRECTION LEVER (vertical)
// ───────────────────────────────────────────────────────────
dirPosFwd.addEventListener('click', () => {
    if (!S.fwd) post('drivingAction', { action: 'forward' });
});
dirPosN.addEventListener('click', () => {
    // Neutral — cancel any active direction
    if (S.fwd) post('drivingAction', { action: 'forward' });
    if (S.bwd) post('drivingAction', { action: 'backward' });
});
dirPosBwd.addEventListener('click', () => {
    if (!S.bwd) post('drivingAction', { action: 'backward' });
});

// ───────────────────────────────────────────────────────────
//  ANALOG PRESSURE SIMULATION  (150 ms ticks)
//
//  Fyzika:
//  • pistonPressure — ovládá ventil, zpoždění buildup/dropoff
//    Nezávislý budík na písty. NEOVLIVŇUJE brzdový budík.
//  • brakePressure  — ovládá páka brzdy, aplikuje se rychleji
//    Nezávislý budík na brzdy. NEOVLIVŇUJE pístový budík.
//  • Oba čerpají z boilerPressure (zdroj = Lua)
//  • Efektivní rychlost = piston − brake (dva protichůdné tlaky)
//  • Spotřeba obou snižuje boilerPressure v Lua
// ───────────────────────────────────────────────────────────
// ───────────────────────────────────────────────────────────
//  ANALOG PRESSURE SIMULATION  (150 ms ticks)
// ───────────────────────────────────────────────────────────
setInterval(() => {
    // 1. Pístový tlak (pouze vyhlazení polohy červeného ventilu)
    // DŮLEŽITÉ: Již není svázáno s tlakem kotle, aby nevznikla oscilace a lagy!
    if (!S.engine) {
        S.pistonPressure = Math.max(0, S.pistonPressure - 4);
    } else {
        const diff = S.targetPressure - S.pistonPressure;
        if (Math.abs(diff) < 0.5) {
            S.pistonPressure = S.targetPressure;
        } else {
            S.pistonPressure += Math.sign(diff) * (diff > 0 ? 1.5 : 3.0);
        }
    }

    // 2. Brzdový tlak (pouze vyhlazení polohy brzdové páky)
    const diffBrake = S.brakePos - S.brakePressure;
    if (Math.abs(diffBrake) < 0.5) {
        S.brakePressure = S.brakePos;
    } else {
        S.brakePressure += Math.sign(diffBrake) * (diffBrake > 0 ? 4.0 : 2.0);
    }

    // 3. Aktualizace UI budíků - VIZUÁLNĚ je tlak omezen tím, kolik je reálně v kotli
    const boiler = S.boilerPressure;
    const visualPiston = Math.min(S.pistonPressure, boiler);
    const visualBrake  = Math.min(S.brakePressure, boiler);
    
    currentPctEl.textContent = Math.round(S.pistonPressure) + '%';
    applyPistonGauge(visualPiston);
    applyBrakeGauge(visualBrake);

    // 4. Odstraněn výpočet effectiveSpeed a odesílání setSpeed! 
    // Rychlost vlaku si nyní čistě a plynule počítá setrvačná fyzika v LUA.

    // 5. Odeslání mechanických poloh pák do LUA (odesílá se jen při změně pohybu hráče)
    const rp = Math.round(S.pistonPressure);
    const rb = Math.round(S.brakePressure);
    if (rp !== S._lastSentPistons || rb !== S._lastSentBrakes) {
        S._lastSentPistons = rp;
        S._lastSentBrakes  = rb;
        post('pressureUpdate', { pistons: rp, brakes: rb });
    }
}, 150);

// ───────────────────────────────────────────────────────────
//  STATION MENU
// ───────────────────────────────────────────────────────────
function openStationMenu(d) {
    menuTitle.textContent   = (d.title  || '').toUpperCase();
    menuSubtext.textContent =  d.subtext || '';
    menuBackBtn.className   =  d.hasBack ? 'show' : '';
    menuItems.innerHTML = '';
    itemDesc.innerHTML  = '';

    (d.elements || []).forEach((item, idx) => {
        const li = document.createElement('li');

        if (item.type === 'slider') {
            li.innerHTML = `
                <div class="slider-row">
                    <div class="slider-header">
                        <span>${item.label}</span>
                        <span class="sv" id="sv_${idx}">${item.value ?? item.min ?? 0}</span>
                    </div>
                    <input type="range" class="brass-slider"
                        min="${item.min ?? 0}" max="${item.max ?? 100}"
                        value="${item.value ?? 0}" step="${item.hop ?? 1}" id="sl_${idx}">
                </div>`;
            li.querySelector(`#sl_${idx}`).addEventListener('input', function () {
                document.getElementById(`sv_${idx}`).textContent = this.value;
                post('drivingAction', { action: 'setSpeed', value: parseFloat(this.value) });
            });
        } else {
            const dis = item.value === 'noBuy';
            li.innerHTML = `
                <div class="menu-row${dis ? ' disabled' : ''}" data-idx="${idx}">
                    <div class="menu-dot"></div>
                    <div class="menu-row-label">${item.label || ''}</div>
                </div>`;
            if (!dis) {
                const row = li.querySelector('.menu-row');
                row.addEventListener('click',      () => { post('menuSelect', { value: item.value, info: item.info ?? null, idx }); });
                row.addEventListener('mouseenter', () => { itemDesc.innerHTML = item.desc || ''; });
                row.addEventListener('mouseleave', () => { itemDesc.innerHTML = ''; });
            }
        }
        menuItems.appendChild(li);
    });

    stationPanel.classList.add('visible');
}
function closeStationMenu() { stationPanel.classList.remove('visible'); }

menuBackBtn.addEventListener('click', () => post('menuBack', {}));

document.addEventListener('keydown', e => {
    if (e.key !== 'Escape') return;

    if (stationPanel.classList.contains('visible')) {
        if (menuBackBtn.classList.contains('show')) {
            post('menuBack', {});
        } else {
            post('menuClose', {});
            closeStationMenu();
        }
    }
    if (junctionPanel.classList.contains('visible')) {
        post('drivingAction', { action: 'closeJunctions' });
        junctionPanel.classList.remove('visible');
    }
    if (drivingPanel.classList.contains('visible')) {
        post('drivingAction', { action: 'closeHUD' });
        drivingPanel.classList.remove('visible');
    }
});

// ───────────────────────────────────────────────────────────
//  JUNCTION PANEL
// ───────────────────────────────────────────────────────────
function renderJunctions() {
    junctionList.innerHTML = '';
    junctionData.forEach(j => {
        const div = document.createElement('div');
        div.className = 'jitem' + (j.state ? ' switched' : '');
        div.innerHTML = `
            <div class="jitem-dot ${j.state ? 'on' : 'off'}"></div>
            <div class="jitem-name">${j.name}</div>
            <div class="jitem-state">${j.state ? 'PŘEPNUTO' : 'VÝCHOZÍ'}</div>`;
        div.addEventListener('click', () => {
            post('drivingAction', { action: 'switchJunction', value: j.idx });
        });
        junctionList.appendChild(div);
    });
}

function showJunctions(junctions) {
    junctionData = junctions;
    renderJunctions();
    junctionPanel.classList.add('visible');
}

function updateJunctionUI(idx, state) {
    const j = junctionData.find(j => j.idx === idx);
    if (j) { j.state = state; renderJunctions(); }
}

jpClose.addEventListener('click', () => post('drivingAction', { action: 'closeJunctions' }));
jpReset.addEventListener('click', () => post('drivingAction', { action: 'resetJunctions' }));

// ───────────────────────────────────────────────────────────
//  CONTROL BUTTONS
// ───────────────────────────────────────────────────────────
engineBtn.addEventListener('click', () => post('drivingAction', { action: S.engine ? 'stopEngine' : 'startEngine' }));
resetBtn.addEventListener( 'click', () => {
    S.trackSwitch = !S.trackSwitch;
    applyDrivingUI();
    post('drivingAction', { action: 'trackSwitch', value: S.trackSwitch });
});
deleteBtn.addEventListener('click', () => post('drivingAction', { action: 'deleteTrain' }));
