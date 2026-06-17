// js/replay.js
// Renders a real Orbit Wars episode replay on a canvas.
// Replay shape: { steps:[ [ {observation:{planets,fleets,...}} , ...agents ], ... ], rewards:[r0,r1], configuration:{...} }
// Planet row: [id, owner, x, y, radius, ships, production]   (x,y on a 0..100 grid)
// Fleet row:  [id, owner, x, y, angle, ships, target]        (x,y on the same grid)

(function () {
  var COL = {
    base: '#070708',
    grid: 'rgba(255,255,255,0.04)',
    sun: '#D47B45',
    sunGlow: 'rgba(212,123,69,0.28)',
    me: '#8FD4F0',
    enemy: '#C8543B',
    neutral: '#6E6E6B',
    text: '#F4F3F1',
    textMuted: '#A8A7A4'
  };
  var GRID = 100;

  var state = {
    raw: null, steps: null, n: 0, turn: 0, playing: false, speed: 1,
    raf: null, lastTs: 0, acc: 0, canvas: null, ctx: null, meIndex: 0, rewards: null
  };

  function ownerColor(owner) {
    if (owner === state.meIndex) return COL.me;
    if (owner < 0 || owner === -1 || owner == null) return COL.neutral;
    return COL.enemy;
  }

  function obsAt(i) {
    var step = state.steps[i];
    if (!step) return null;
    var agent0 = Array.isArray(step) ? step[0] : step;
    var obs = agent0 && agent0.observation ? agent0.observation : null;
    return obs;
  }

  function planetsAt(i) {
    var obs = obsAt(i);
    if (!obs) return [];
    return obs.planets || obs.initial_planets || [];
  }

  function fleetsAt(i) {
    var obs = obsAt(i);
    if (!obs) return [];
    return obs.fleets || [];
  }

  function sizeCanvas() {
    var c = state.canvas;
    var rect = c.getBoundingClientRect();
    var dpr = window.devicePixelRatio || 1;
    var w = Math.max(1, Math.floor(rect.width));
    var h = Math.max(1, Math.floor(rect.height));
    c.width = Math.floor(w * dpr);
    c.height = Math.floor(h * dpr);
    state.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    state.cw = w; state.ch = h;
  }

  function toPx(gx, gy) {
    var pad = 18;
    var size = Math.min(state.cw, state.ch) - pad * 2;
    var ox = (state.cw - size) / 2;
    var oy = (state.ch - size) / 2;
    return [ox + (gx / GRID) * size, oy + (gy / GRID) * size, size];
  }

  function draw() {
    var ctx = state.ctx;
    if (!ctx) return;
    ctx.clearRect(0, 0, state.cw, state.ch);
    ctx.fillStyle = COL.base;
    ctx.fillRect(0, 0, state.cw, state.ch);

    // faint grid
    var ref = toPx(0, 0);
    var size = ref[2];
    ctx.strokeStyle = COL.grid;
    ctx.lineWidth = 1;
    for (var g = 0; g <= 10; g++) {
      var p1 = toPx(g * 10, 0), p2 = toPx(g * 10, 100);
      ctx.beginPath(); ctx.moveTo(p1[0], p1[1]); ctx.lineTo(p2[0], p2[1]); ctx.stroke();
      var p3 = toPx(0, g * 10), p4 = toPx(100, g * 10);
      ctx.beginPath(); ctx.moveTo(p3[0], p3[1]); ctx.lineTo(p4[0], p4[1]); ctx.stroke();
    }

    // sun at center
    var sc = toPx(50, 50);
    var sunR = Math.max(7, size * 0.035);
    var grad = ctx.createRadialGradient(sc[0], sc[1], 0, sc[0], sc[1], sunR * 3.2);
    grad.addColorStop(0, COL.sunGlow);
    grad.addColorStop(1, 'rgba(212,123,69,0)');
    ctx.fillStyle = grad;
    ctx.beginPath(); ctx.arc(sc[0], sc[1], sunR * 3.2, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = COL.sun;
    ctx.beginPath(); ctx.arc(sc[0], sc[1], sunR, 0, Math.PI * 2); ctx.fill();

    var planets = planetsAt(state.turn);
    var fleets = fleetsAt(state.turn);

    // fleets first so planets sit on top
    fleets.forEach(function (f) {
      var owner = f[1], fx = f[2], fy = f[3], angle = f[4], ships = f[5];
      var p = toPx(fx, fy);
      ctx.save();
      ctx.translate(p[0], p[1]);
      if (typeof angle === 'number') ctx.rotate(angle);
      ctx.fillStyle = ownerColor(owner);
      var s = Math.max(3, Math.min(7, 3 + Math.sqrt(ships || 1) * 0.7));
      ctx.beginPath();
      ctx.moveTo(s, 0);
      ctx.lineTo(-s * 0.7, s * 0.7);
      ctx.lineTo(-s * 0.7, -s * 0.7);
      ctx.closePath();
      ctx.globalAlpha = 0.92;
      ctx.fill();
      ctx.restore();
    });

    // planets
    planets.forEach(function (pl) {
      var owner = pl[1], px = pl[2], py = pl[3], radius = pl[4], ships = pl[5];
      var p = toPx(px, py);
      var rr = Math.max(6, size * 0.012 * (1 + (radius || 1) * 0.6) + Math.sqrt(ships || 0) * 0.6);
      var c = ownerColor(owner);
      ctx.beginPath();
      ctx.arc(p[0], p[1], rr, 0, Math.PI * 2);
      ctx.fillStyle = c;
      ctx.globalAlpha = owner === -1 || owner == null ? 0.55 : 0.9;
      ctx.fill();
      ctx.globalAlpha = 1;
      ctx.lineWidth = 1.5;
      ctx.strokeStyle = 'rgba(0,0,0,0.4)';
      ctx.stroke();
      // ship count
      ctx.fillStyle = COL.text;
      ctx.font = '600 ' + Math.max(9, Math.round(rr * 0.85)) + 'px ui-monospace, monospace';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(String(Math.round(ships || 0)), p[0], p[1]);
    });

    // hud
    var turnEl = document.getElementById('replay-turn');
    if (turnEl) turnEl.textContent = 'turn ' + state.turn + ' / ' + (state.n - 1);
    var scrub = document.getElementById('replay-scrub');
    if (scrub && document.activeElement !== scrub) scrub.value = String(state.turn);
  }

  function tick(ts) {
    if (!state.playing) return;
    if (!state.lastTs) state.lastTs = ts;
    var dt = ts - state.lastTs;
    state.lastTs = ts;
    state.acc += dt;
    var frameMs = 90 / state.speed;
    while (state.acc >= frameMs) {
      state.acc -= frameMs;
      state.turn++;
      if (state.turn >= state.n - 1) {
        state.turn = state.n - 1;
        state.playing = false;
        setPlayIcon();
        draw();
        return;
      }
    }
    draw();
    state.raf = requestAnimationFrame(tick);
  }

  function setPlayIcon() {
    var btn = document.getElementById('replay-play');
    if (btn) btn.innerHTML = state.playing ? '&#10074;&#10074;' : '&#9654;';
  }

  function pause() {
    state.playing = false;
    if (state.raf) cancelAnimationFrame(state.raf);
    setPlayIcon();
  }

  function showResult() {
    var el = document.getElementById('replay-result');
    if (!el) return;
    var r = state.rewards;
    if (!r || r.length === 0) { el.style.display = 'none'; return; }
    var mine = r[state.meIndex];
    var best = Math.max.apply(null, r);
    var won = mine != null && mine === best && r.filter(function (x) { return x === best; }).length === 1;
    el.style.display = 'block';
    el.className = 'replay-result ' + (won ? 'win' : 'loss');
    el.textContent = won ? 'burroship won' : 'burroship lost';
  }

  function mountControls() {
    var playBtn = document.getElementById('replay-play');
    var scrub = document.getElementById('replay-scrub');
    var speed = document.getElementById('replay-speed');
    if (playBtn) playBtn.onclick = function () { if (state.playing) pause(); else startPlay(); };
    if (scrub) scrub.oninput = function () { pause(); state.turn = parseInt(scrub.value, 10) || 0; draw(); };
    if (speed) speed.onclick = function () {
      var seq = [1, 2, 4, 0.5];
      var idx = seq.indexOf(state.speed);
      state.speed = seq[(idx + 1) % seq.length];
      speed.textContent = state.speed + 'x';
    };
  }
  function startPlay() {
    if (state.n < 2) return;
    if (state.turn >= state.n - 1) state.turn = 0;
    state.playing = true; state.lastTs = 0; state.acc = 0;
    setPlayIcon();
    state.raf = requestAnimationFrame(tick);
  }

  function loadReplay(raw, meIndex) {
    state.raw = raw;
    state.steps = raw.steps || [];
    state.n = state.steps.length;
    state.turn = 0;
    state.meIndex = typeof meIndex === 'number' ? meIndex : 0;
    state.rewards = raw.rewards || null;
    state.speed = 1;
    var speed = document.getElementById('replay-speed');
    if (speed) speed.textContent = '1x';
    var scrub = document.getElementById('replay-scrub');
    if (scrub) { scrub.min = '0'; scrub.max = String(Math.max(0, state.n - 1)); scrub.value = '0'; }
    if (!state.canvas) {
      state.canvas = document.getElementById('replay-canvas');
      state.ctx = state.canvas.getContext('2d');
    }
    sizeCanvas();
    showResult();
    draw();
    setPlayIcon();
  }

  window.OrbitReplay = {
    init: function () {
      state.canvas = document.getElementById('replay-canvas');
      if (state.canvas) state.ctx = state.canvas.getContext('2d');
      mountControls();
      window.addEventListener('resize', function () {
        if (state.canvas) { sizeCanvas(); draw(); }
      });
    },
    load: loadReplay,
    pause: pause,
    reset: function () { pause(); state.turn = 0; if (state.ctx) draw(); }
  };
})();
