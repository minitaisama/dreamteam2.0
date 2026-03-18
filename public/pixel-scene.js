// Pixel scene renderer (Phase 2)
// - Reads agents state from window.DreamteamLive
// - Updates CSS classes for each character (state-idle|run|sleep|eat)
// - Provides window.DreamteamPixelScene.update(liveData?)

(function () {
  const STATE_MAP = {
    working: 'state-run',
    idle: 'state-idle',
    sleeping: 'state-sleep',
    eating: 'state-eat'
  };

  const CHAR_ORDER = [
    { key: 'minisama', elId: 'char-minisama', defaultDir: 'dir-right' },
    { key: 'coach', elId: 'char-coach', defaultDir: 'dir-left' },
    { key: 'lebron', elId: 'char-lebron', defaultDir: 'dir-left' },
    { key: 'curry', elId: 'char-curry', defaultDir: 'dir-left' }
  ];

  function pickStateClass(agentState) {
    if (!agentState) return 'state-idle';
    return STATE_MAP[agentState] || 'state-idle';
  }

  function setState(el, agentState) {
    if (!el) return;

    // clear previous state
    el.classList.remove('state-idle', 'state-run', 'state-sleep', 'state-eat');
    el.classList.add(pickStateClass(agentState));

    // tiny per-character motion variety
    // working => longer stride
    if (agentState === 'working') {
      el.style.setProperty('--runDist', `${28 + Math.floor(Math.random() * 28)}px`);
    } else {
      el.style.removeProperty('--runDist');
    }

    // Apply sprite class to nested node (so we can flip independently)
    const sprite = el.querySelector('.pixel-sprite');
    if (sprite) {
      sprite.classList.remove('state-idle', 'state-run', 'state-sleep', 'state-eat');
      // (kept for backward compat if any CSS targets .pixel-sprite.state-*)
      sprite.classList.add(pickStateClass(agentState));
    }
  }

  function layoutScene(sceneEl) {
    // left: trainer. right: others
    const trainer = document.getElementById('char-minisama');
    const coach = document.getElementById('char-coach');
    const lebron = document.getElementById('char-lebron');
    const curry = document.getElementById('char-curry');

    const w = sceneEl.clientWidth;
    const pad = 18;
    const charW = 64;
    const maxLeft = Math.max(pad, w - pad - charW);

    const trainerLeft = Math.min(maxLeft, Math.max(pad, 46));
    if (trainer) trainer.style.left = `${trainerLeft}px`;

    // cluster on right; keep inside bounds on narrow viewports
    // spacing in px between characters
    const gap = 76;
    const baseRight = maxLeft;

    let coachLeft = baseRight - gap * 2;
    let lebronLeft = baseRight - gap;
    let curryLeft = baseRight;

    // keep coach to the right of trainer a bit
    const minGroupLeft = trainerLeft + 150;
    if (coachLeft < minGroupLeft) {
      const delta = minGroupLeft - coachLeft;
      coachLeft += delta;
      lebronLeft += delta;
      curryLeft += delta;
    }

    // if we overflow right edge, shift entire group left
    if (curryLeft > baseRight) {
      const overflow = curryLeft - baseRight;
      coachLeft -= overflow;
      lebronLeft -= overflow;
      curryLeft -= overflow;
    }

    // final clamp
    coachLeft = Math.min(maxLeft, Math.max(pad, coachLeft));
    lebronLeft = Math.min(maxLeft, Math.max(pad, lebronLeft));
    curryLeft = Math.min(maxLeft, Math.max(pad, curryLeft));

    if (coach) { coach.style.left = `${coachLeft}px`; coach.style.bottom = '46px'; }
    if (lebron) { lebron.style.left = `${lebronLeft}px`; lebron.style.bottom = '40px'; }
    if (curry) { curry.style.left = `${curryLeft}px`; curry.style.bottom = '44px'; }
  }

  function update(liveData) {
    const sceneEl = document.getElementById('pixelScene');
    if (!sceneEl) return;

    layoutScene(sceneEl);

    const agents = liveData?.agents || window.DreamteamLive?.getAgents?.() || {};

    for (const ch of CHAR_ORDER) {
      const el = document.getElementById(ch.elId);
      if (!el) continue;

      // ensure base + direction classes
      el.classList.add('pixel-character');
      el.classList.toggle('dir-left', ch.defaultDir === 'dir-left');
      el.classList.toggle('dir-right', ch.defaultDir === 'dir-right');

      // Ensure nested sprite node exists
      if (!el.querySelector('.pixel-sprite')) {
        const sprite = document.createElement('div');
        sprite.className = 'pixel-sprite';
        el.appendChild(sprite);
      }

      const a = agents[ch.key];
      const st = (a && a.state) || 'idle';
      setState(el, st);

      // If idle, randomly flip direction sometimes to feel alive
      if (st === 'idle') {
        if (Math.random() < 0.20) el.classList.toggle('dir-left');
      }
    }
  }

  // expose
  window.DreamteamPixelScene = { update };

  // boot
  document.addEventListener('DOMContentLoaded', () => {
    // initial render after live layer has loaded once
    setTimeout(() => update(), 120);
    window.addEventListener('resize', () => update());
  });
})();
