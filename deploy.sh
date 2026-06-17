#!/bin/bash
set -e

# Orbit Wars dashboard build-out installer
# Run this from the root of your orbit-wars repo.

if [ ! -f "netlify.toml" ] || [ ! -f "index.html" ]; then
  echo "ERROR: run this from the orbit-wars repo root (netlify.toml and index.html must exist)."
  exit 1
fi

STAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE="_archive/$STAMP"
mkdir -p "$ARCHIVE"
echo "Archiving files being replaced to $ARCHIVE"
[ -f "index.html" ] && mkdir -p "$ARCHIVE/$(dirname index.html)" && cp "index.html" "$ARCHIVE/index.html" && echo "  archived index.html" || true
[ -f "netlify/functions/refresh.js" ] && mkdir -p "$ARCHIVE/$(dirname netlify/functions/refresh.js)" && cp "netlify/functions/refresh.js" "$ARCHIVE/netlify/functions/refresh.js" && echo "  archived netlify/functions/refresh.js" || true

echo "Creating directories"
mkdir -p css js netlify/functions

echo "  -> css/styles.css"
cat > "css/styles.css" << 'ORBITWARS_EOF_00'
/* css/styles.css */
:root {
  --surface-base:#0B0B0C; --surface-raised:#141416; --surface-sunken:#070708;
  --line:rgba(255,255,255,0.08); --line-strong:rgba(255,255,255,0.14);
  --text-primary:#F4F3F1; --text-secondary:#A8A7A4; --text-muted:#6E6E6B;
  --heat:#D47B45; --ember-hover:#C8543B; --sky:#8FD4F0; --sky-soft:#B6E3F5; --online:#5E8C61;
  --brown-400:#C39D7F; --success:#5E8C61; --warning:#C8893B;
  --font-sans:'Geist','Inter',-apple-system,sans-serif;
  --font-mono:'Geist Mono','JetBrains Mono',ui-monospace,monospace;
}
* { box-sizing:border-box; margin:0; padding:0; }
html { background:var(--surface-base); overflow-x:hidden; scroll-behavior:smooth; }
body { font-family:var(--font-sans); background:var(--surface-base); color:var(--text-primary); line-height:1.5; min-height:100vh; -webkit-font-smoothing:antialiased; }

.team-strip { position:fixed; top:0; left:0; right:0; z-index:60; display:flex; align-items:center; justify-content:center; padding:12px 24px; background:transparent; }
.team-strip .agents { display:flex; gap:11px; }
.agent { position:relative; width:30px; height:30px; border-radius:50%; }
.agent img { width:100%; height:100%; border-radius:50%; object-fit:cover; border:1.5px solid rgba(255,255,255,0.12); transition:border-color .2s, transform .2s; background:var(--surface-raised); }
.agent:hover img { border-color:var(--sky); transform:translateY(-2px); }
.agent .status-dot { position:absolute; right:-1px; bottom:-1px; width:9px; height:9px; border-radius:50%; background:var(--online); border:2px solid var(--surface-base); box-shadow:0 0 6px rgba(94,140,97,0.7); }
.agent .tip { position:absolute; top:38px; left:50%; transform:translateX(-50%) translateY(4px); opacity:0; pointer-events:none; white-space:nowrap; background:rgba(7,7,8,0.95); border:1px solid var(--line); border-radius:8px; padding:6px 10px; font-family:var(--font-mono); font-size:10px; color:var(--text-primary); transition:opacity .18s, transform .18s; z-index:70; }
.agent .tip b { color:var(--sky); text-transform:capitalize; }
.agent .tip span { color:var(--online); }
.agent:hover .tip { opacity:1; transform:translateX(-50%) translateY(0); }

.refresh-btn { width:34px; height:34px; flex:0 0 auto; color:var(--text-secondary); background:transparent; border:1px solid rgba(255,255,255,0.14); border-radius:50%; cursor:pointer; display:inline-flex; align-items:center; justify-content:center; transition:color .2s, border-color .2s; }
.refresh-btn:hover { color:var(--sky); border-color:var(--sky); }
.refresh-btn .ico { display:inline-block; width:12px; height:12px; border:1.5px solid currentColor; border-top-color:transparent; border-radius:50%; }
.refresh-btn.spinning .ico { animation:spin .7s linear infinite; }
@keyframes spin { to { transform:rotate(360deg); } }

.hero { position:relative; min-height:100vh; width:100%; display:flex; flex-direction:column; align-items:center; justify-content:flex-end; text-align:center; padding:140px 24px 72px; overflow:hidden; background:var(--surface-sunken); }
.hero-img { position:absolute; inset:0; z-index:0; width:100%; height:100%; object-fit:cover; object-position:center; }
.hero-scrim { position:absolute; inset:0; z-index:1; background:linear-gradient(to bottom, rgba(11,11,12,0.40) 0%, rgba(11,11,12,0.06) 36%, rgba(11,11,12,0.92) 100%); }
.hero-inner { position:relative; z-index:2; }
.eyebrow { font-family:var(--font-mono); font-size:12px; letter-spacing:0.26em; text-transform:uppercase; color:var(--sky-soft); margin-bottom:22px; text-shadow:0 2px 20px rgba(0,0,0,0.6); }
.hero h1 { font-weight:700; font-size:clamp(48px,9vw,112px); line-height:0.98; letter-spacing:-0.04em; text-shadow:0 4px 40px rgba(0,0,0,0.7); }
.hero h1 .dot { color:var(--sky); text-shadow:0 0 24px rgba(143,212,240,0.5); }
.hero .lede { margin:28px auto 0; max-width:560px; font-size:clamp(15px,2.1vw,18px); color:var(--text-secondary); text-shadow:0 2px 20px rgba(0,0,0,0.7); }
.scroll-cue { margin-top:40px; font-family:var(--font-mono); font-size:11px; letter-spacing:0.2em; text-transform:uppercase; color:var(--text-muted); }

.wrap { max-width:1080px; margin:0 auto; padding:48px 24px 100px; position:relative; z-index:1; }
.stamp-row { display:flex; align-items:center; justify-content:center; gap:14px; margin-bottom:28px; }
.stamp { font-family:var(--font-mono); font-size:12px; color:var(--text-muted); }

/* Tab navigation */
.tabs { display:flex; gap:6px; justify-content:center; margin-bottom:36px; border-bottom:1px solid var(--line); }
.tab { font-family:var(--font-mono); font-size:12px; letter-spacing:0.12em; text-transform:uppercase; color:var(--text-muted); background:transparent; border:none; padding:14px 18px; cursor:pointer; position:relative; transition:color .2s; white-space:nowrap; }
.tab:hover { color:var(--text-secondary); }
.tab.active { color:var(--text-primary); }
.tab.active::after { content:""; position:absolute; left:0; right:0; bottom:-1px; height:2px; background:var(--heat); }
.panel { display:none; animation:fade .3s ease; }
.panel.active { display:block; }
@keyframes fade { from { opacity:0; transform:translateY(6px); } to { opacity:1; transform:translateY(0); } }

/* Flagship feature card */
.flagship { background:linear-gradient(160deg, var(--surface-raised), var(--surface-sunken)); border:1px solid var(--line-strong); border-radius:20px; padding:32px; margin-bottom:24px; position:relative; overflow:hidden; }
.flagship::before { content:""; position:absolute; top:-40%; right:-10%; width:60%; height:160%; background:radial-gradient(circle, rgba(212,123,69,0.16), transparent 70%); pointer-events:none; }
.flagship .fleet-burro { display:flex; align-items:center; gap:16px; margin-bottom:24px; }
.flagship .fleet-burro img { width:64px; height:64px; border-radius:50%; border:2px solid var(--heat); object-fit:cover; }
.flagship .fleet-burro .who { font-family:var(--font-mono); }
.flagship .fleet-burro .who .nm { font-size:18px; font-weight:600; color:var(--text-primary); text-transform:capitalize; }
.flagship .fleet-burro .who .rl { font-size:11px; color:var(--text-muted); text-transform:uppercase; letter-spacing:0.1em; margin-top:3px; }
.flagship .pulse { display:inline-flex; align-items:center; gap:7px; font-family:var(--font-mono); font-size:11px; color:var(--online); text-transform:uppercase; letter-spacing:0.1em; }
.flagship .pulse .dot { width:8px; height:8px; border-radius:50%; background:var(--online); box-shadow:0 0 8px var(--online); animation:blink 1.8s ease infinite; }
@keyframes blink { 0%,100% { opacity:1; } 50% { opacity:0.35; } }

.grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(190px,1fr)); gap:14px; margin-bottom:24px; }
.stat { background:var(--surface-raised); border:1px solid var(--line); border-radius:16px; padding:22px 24px; position:relative; overflow:hidden; }
.stat::after { content:""; position:absolute; left:0; top:0; height:100%; width:3px; background:var(--heat); opacity:0.7; }
.stat .label { font-family:var(--font-mono); font-size:11px; text-transform:uppercase; letter-spacing:0.12em; color:var(--text-muted); margin-bottom:12px; }
.stat .value { font-weight:700; font-size:42px; line-height:1; letter-spacing:-0.02em; }
.stat .value.heat { color:var(--heat); }
.stat .value.win { color:var(--online); }
.stat .meta { font-family:var(--font-mono); font-size:11px; color:var(--text-muted); margin-top:10px; }

h2 { font-weight:700; font-size:22px; letter-spacing:-0.02em; margin-bottom:18px; display:flex; align-items:center; gap:12px; }
h2::before { content:""; width:8px; height:8px; border-radius:50%; background:var(--heat); }
table { width:100%; border-collapse:collapse; background:var(--surface-raised); border:1px solid var(--line); border-radius:16px; overflow:hidden; }
th,td { text-align:left; padding:14px 18px; font-size:13px; border-bottom:1px solid var(--line); }
th { font-family:var(--font-mono); font-size:11px; text-transform:uppercase; letter-spacing:0.1em; color:var(--text-muted); font-weight:600; background:rgba(255,255,255,0.02); }
td { font-family:var(--font-mono); color:var(--text-secondary); }
tr:last-child td { border-bottom:none; }
tr.me { background:rgba(143,212,240,0.10); }
tr.me td { color:var(--text-primary); font-weight:600; }
tr.clickable { cursor:pointer; transition:background .15s; }
tr.clickable:hover { background:rgba(143,212,240,0.08); }
tr.clickable:hover td { color:var(--text-primary); }
td .watch { color:var(--sky); }

/* Build log (fleet) */
.log { list-style:none; }
.log li { display:flex; align-items:flex-start; gap:14px; padding:16px 0; border-bottom:1px solid var(--line); }
.log li:last-child { border-bottom:none; }
.log .av { width:40px; height:40px; border-radius:50%; flex:0 0 auto; object-fit:cover; border:1.5px solid var(--line-strong); background:var(--surface-raised); }
.log .body { flex:1; min-width:0; }
.log .msg { color:var(--text-primary); font-size:14px; margin-bottom:4px; }
.log .sub { font-family:var(--font-mono); font-size:11px; color:var(--text-muted); display:flex; gap:10px; flex-wrap:wrap; }
.log .sub .score { color:var(--heat); }

/* Progression bars */
.prog { list-style:none; }
.prog li { display:flex; align-items:center; gap:14px; padding:10px 0; }
.prog .plabel { font-family:var(--font-mono); font-size:11px; color:var(--text-muted); width:130px; flex:0 0 auto; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.prog .bar { flex:1; height:8px; background:var(--surface-raised); border-radius:999px; overflow:hidden; }
.prog .bar span { display:block; height:100%; background:linear-gradient(90deg, var(--heat), var(--sky)); border-radius:999px; }
.prog .pscore { font-family:var(--font-mono); font-size:12px; color:var(--text-primary); width:48px; text-align:right; flex:0 0 auto; }

.pill { display:inline-block; padding:3px 11px; border-radius:999px; font-size:11px; font-family:var(--font-mono); }
.pill.complete { background:rgba(94,140,97,0.18); color:var(--success); }
.pill.pending { background:rgba(200,137,59,0.16); color:var(--warning); }
.pill.error { background:rgba(181,70,47,0.20); color:var(--ember-hover); }
.empty { background:var(--surface-raised); border:1px dashed var(--line-strong); border-radius:16px; padding:44px; text-align:center; color:var(--text-muted); font-family:var(--font-mono); font-size:13px; }
footer { margin-top:60px; font-family:var(--font-mono); font-size:11px; color:var(--text-muted); border-top:1px solid var(--line); padding-top:20px; text-align:center; }

/* Replay player */
.replay-feature { background:linear-gradient(160deg, var(--surface-raised), var(--surface-sunken)); border:1px solid var(--line-strong); border-radius:20px; padding:24px; margin-bottom:24px; }
.replay-feature .rf-head { display:flex; align-items:center; justify-content:space-between; gap:12px; margin-bottom:16px; flex-wrap:wrap; }
.replay-feature .rf-title { font-family:var(--font-mono); font-size:12px; text-transform:uppercase; letter-spacing:0.12em; color:var(--text-secondary); display:flex; align-items:center; gap:10px; }
.replay-feature .rf-title .live { width:8px; height:8px; border-radius:50%; background:var(--sky); box-shadow:0 0 8px var(--sky); animation:blink 1.8s ease infinite; }
.modal { position:fixed; inset:0; z-index:200; display:none; align-items:center; justify-content:center; padding:20px; background:rgba(5,5,6,0.86); -webkit-backdrop-filter:blur(6px); backdrop-filter:blur(6px); }
.modal.open { display:flex; }
.modal-card { width:100%; max-width:760px; background:var(--surface-raised); border:1px solid var(--line-strong); border-radius:20px; overflow:hidden; position:relative; }
.modal-head { display:flex; align-items:center; justify-content:space-between; gap:12px; padding:18px 22px; border-bottom:1px solid var(--line); }
.modal-head .mh-title { font-family:var(--font-mono); font-size:13px; color:var(--text-primary); }
.modal-head .mh-sub { font-family:var(--font-mono); font-size:11px; color:var(--text-muted); margin-top:3px; }
.modal-close { width:34px; height:34px; flex:0 0 auto; border-radius:50%; border:1px solid var(--line-strong); background:transparent; color:var(--text-secondary); cursor:pointer; font-size:18px; line-height:1; display:inline-flex; align-items:center; justify-content:center; transition:color .2s, border-color .2s; }
.modal-close:hover { color:var(--ember-hover); border-color:var(--ember-hover); }
.canvas-wrap { position:relative; width:100%; background:var(--surface-sunken); aspect-ratio:1/1; }
.canvas-wrap canvas { display:block; width:100%; height:100%; }
.replay-status { position:absolute; inset:0; display:flex; align-items:center; justify-content:center; flex-direction:column; gap:14px; font-family:var(--font-mono); font-size:12px; color:var(--text-muted); text-align:center; padding:24px; }
.replay-status .spinner { width:26px; height:26px; border:2px solid var(--line-strong); border-top-color:var(--sky); border-radius:50%; animation:spin .8s linear infinite; }
.replay-result { position:absolute; top:14px; left:14px; font-family:var(--font-mono); font-size:11px; text-transform:uppercase; letter-spacing:0.1em; padding:5px 12px; border-radius:999px; background:rgba(7,7,8,0.8); border:1px solid var(--line); }
.replay-result.win { color:var(--online); border-color:rgba(94,140,97,0.4); }
.replay-result.loss { color:var(--ember-hover); border-color:rgba(200,84,59,0.4); }
.replay-turn { position:absolute; top:14px; right:14px; font-family:var(--font-mono); font-size:11px; color:var(--text-secondary); padding:5px 12px; border-radius:999px; background:rgba(7,7,8,0.8); border:1px solid var(--line); }
.controls { display:flex; align-items:center; gap:14px; padding:16px 22px; }
.controls .play { width:42px; height:42px; flex:0 0 auto; border-radius:50%; border:1px solid var(--line-strong); background:transparent; color:var(--text-primary); cursor:pointer; font-size:14px; display:inline-flex; align-items:center; justify-content:center; transition:color .2s, border-color .2s; }
.controls .play:hover { color:var(--sky); border-color:var(--sky); }
.controls .scrub { flex:1; -webkit-appearance:none; appearance:none; height:5px; border-radius:999px; background:var(--surface-sunken); outline:none; cursor:pointer; }
.controls .scrub::-webkit-slider-thumb { -webkit-appearance:none; appearance:none; width:15px; height:15px; border-radius:50%; background:var(--sky); cursor:pointer; box-shadow:0 0 8px rgba(143,212,240,0.5); }
.controls .scrub::-moz-range-thumb { width:15px; height:15px; border:none; border-radius:50%; background:var(--sky); cursor:pointer; }
.controls .speed { font-family:var(--font-mono); font-size:11px; color:var(--text-secondary); background:transparent; border:1px solid var(--line-strong); border-radius:999px; padding:7px 12px; cursor:pointer; transition:color .2s, border-color .2s; }
.controls .speed:hover { color:var(--sky); border-color:var(--sky); }
.legend { display:flex; gap:16px; flex-wrap:wrap; padding:0 22px 18px; font-family:var(--font-mono); font-size:11px; color:var(--text-muted); }
.legend .lg { display:inline-flex; align-items:center; gap:6px; }
.legend .lg .sw { width:10px; height:10px; border-radius:50%; }

@media (max-width:560px) {
  .hero { padding:80px 16px 40px; justify-content:center; min-height:92vh; }
  .hero-inner { transform:translateY(-6vh); }
  .hero h1 { font-size:clamp(44px,16vw,72px); }
  .wrap { padding:28px 0 64px; max-width:100%; }
  .stamp-row { padding:0 16px; }
  .tabs { padding:0 8px; overflow-x:auto; -webkit-overflow-scrolling:touch; }
  .tab { padding:14px 12px; font-size:11px; }
  .panel { padding:0; }
  h2 { padding:0 16px; font-size:19px; }
  .flagship { border-radius:0; border-left:none; border-right:none; padding:28px 18px; margin-bottom:18px; }
  .replay-feature { border-radius:0; border-left:none; border-right:none; padding:20px 16px; }
  .grid { grid-template-columns:1fr 1fr; gap:10px; padding:0 12px; }
  .stat { border-radius:12px; padding:16px 16px; }
  .stat .value { font-size:32px; }
  table { border-radius:0; border-left:none; border-right:none; font-size:12px; }
  th, td { padding:11px 12px; font-size:12px; }
  .log { padding:0 16px; }
  .prog { padding:0 16px; }
  .prog .plabel { width:96px; }
  .empty { border-radius:0; border-left:none; border-right:none; }
  footer { padding:20px 16px 0; }
  .modal { padding:0; align-items:stretch; }
  .modal-card { max-width:100%; border-radius:0; border:none; height:100%; display:flex; flex-direction:column; }
  .canvas-wrap { flex:1; aspect-ratio:auto; }
}
ORBITWARS_EOF_00

echo "  -> js/replay.js"
cat > "js/replay.js" << 'ORBITWARS_EOF_01'
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
ORBITWARS_EOF_01

echo "  -> js/dashboard.js"
cat > "js/dashboard.js" << 'ORBITWARS_EOF_02'
// js/dashboard.js
var AGENTS=[{name:'warbleur',role:'the vanguard'},{name:'volt',role:'the reactor'},{name:'cypher',role:'the builder'},{name:'aster',role:'the wildcard'},{name:'ion',role:'in orbit'},{name:'echo',role:'in orbit'}];
function esc(v){return (v==null?'':String(v)).replace(/[<>&]/g,function(c){return {'<':'&lt;','>':'&gt;','&':'&amp;'}[c];});}
function ago(iso){if(!iso)return '';var d=new Date(iso);var s=Math.floor((Date.now()-d.getTime())/1000);if(s<60)return s+'s ago';if(s<3600)return Math.floor(s/60)+'m ago';if(s<86400)return Math.floor(s/3600)+'h ago';return Math.floor(s/86400)+'d ago';}
function pill(s){s=(s||'').toLowerCase();if(s.indexOf('complete')>-1)return '<span class="pill complete">complete</span>';if(s.indexOf('error')>-1||s.indexOf('invalid')>-1)return '<span class="pill error">error</span>';return '<span class="pill pending">pending</span>';}
function num(v){var n=parseFloat(v);return isNaN(n)?null:n;}
function avatarFor(desc){desc=(desc||'').toLowerCase();var hit=AGENTS.find(function(a){return desc.indexOf(a.name)>-1;});return hit?hit.name:'warbleur';}
function responsiveHero(){var img=document.getElementById('hero-img');if(!img)return;var w=window.innerWidth;if(w<=560)img.src='images/hero-mobile.png';else if(w<=900)img.src='images/hero-tablet.png';else img.src='images/hero-desktop.png';}
function renderAgents(){var el=document.getElementById('agents');if(!el)return;el.innerHTML=AGENTS.map(function(a){return '<div class="agent"><img src="images/'+a.name+'-avatar.png" alt="'+a.name+'" onerror="this.style.opacity=0.25" /><span class="status-dot"></span><span class="tip"><b>'+a.name+'</b> &middot; <span>'+a.role+'</span></span></div>';}).join('');}

function bestScore(subs){var b=null;subs.forEach(function(s){var n=num(s.publicScore);if(n!==null&&(b===null||n>b))b=n;});return b;}

var LAST_DATA=null;

function renderShip(data){
  var subs=data.submissions||[];
  var best=bestScore(subs);
  var latest=subs[0]||{};
  var el=document.getElementById('panel-ship');
  var flagshipDesc=(subs.find(function(s){return num(s.publicScore)===best;})||{}).description||'the burroship';
  var burro=avatarFor(flagshipDesc);
  var html='';
  html+='<div class="flagship">';
  html+='<div class="pulse"><span class="dot"></span> live on the ladder</div>';
  html+='<div class="fleet-burro" style="margin-top:18px"><img src="images/'+burro+'-avatar.png" onerror="this.style.opacity=0.25" alt="'+burro+'" /><div class="who"><div class="nm">'+esc(burro)+'</div><div class="rl">flagship commander</div></div></div>';
  html+='<div style="font-family:var(--font-mono);font-size:13px;color:var(--text-secondary);max-width:520px">'+esc(flagshipDesc)+'</div>';
  html+='</div>';
  html+='<div class="grid">';
  html+='<div class="stat"><div class="label">Rank</div><div class="value heat">'+(data.my_rank?'#'+data.my_rank:'\u2014')+'</div><div class="meta">'+(data.leaderboard_size?'of '+data.leaderboard_size+' teams':'awaiting rank')+'</div></div>';
  html+='<div class="stat"><div class="label">Best Score</div><div class="value win">'+(best!==null?best:'\u2014')+'</div><div class="meta">public score</div></div>';
  html+='<div class="stat"><div class="label">Submissions</div><div class="value">'+subs.length+'</div><div class="meta">deployed</div></div>';
  html+='<div class="stat"><div class="label">Latest</div><div class="value" style="font-size:24px">'+(latest.status||'\u2014').replace('SubmissionStatus.','').toLowerCase()+'</div><div class="meta">'+(latest.date?ago(latest.date):'')+'</div></div>';
  html+='</div>';
  el.innerHTML=html;
}

function renderBattles(data){
  var subs=(data.submissions||[]).filter(function(s){return num(s.publicScore)!==null;}).slice().reverse();
  var el=document.getElementById('panel-battles');
  var html='';

  // Featured replay player
  var eps=data.episodes||[];
  var featured=eps.find(function(e){return e.replayable;})||eps[0];
  html+='<div class="replay-feature">';
  html+='<div class="rf-head"><div class="rf-title"><span class="live"></span> game replay</div></div>';
  html+='<div style="font-family:var(--font-mono);font-size:12px;color:var(--text-muted);line-height:1.6">Watch a real match the burroship played on Kaggle. Planets orbit the sun, fleets fly between them, ship counts update each turn. Pick an episode below to load it.</div>';
  if(featured){
    html+='<div style="margin-top:16px"><button class="speed" id="open-featured" data-ep="'+esc(featured.id)+'" data-me="'+(featured.meIndex!=null?featured.meIndex:0)+'" style="border-color:var(--sky);color:var(--sky)">&#9654; watch latest game</button></div>';
  }
  html+='</div>';

  if(!subs.length){html+='<div class="empty">Battle data syncs once games complete.</div>';el.innerHTML=html;wireBattles();return;}
  var max=Math.max.apply(null,subs.map(function(s){return num(s.publicScore);}));
  var min=Math.min.apply(null,subs.map(function(s){return num(s.publicScore);}));
  var span=Math.max(1,max-min);
  html+='<h2>Score Progression</h2><ul class="prog">';
  subs.forEach(function(s){var n=num(s.publicScore);var pct=20+((n-min)/span)*80;html+='<li><div class="plabel">'+esc((s.description||'').slice(0,22))+'</div><div class="bar"><span style="width:'+pct+'%"></span></div><div class="pscore">'+n+'</div></li>';});
  html+='</ul>';

  html+='<h2 style="margin-top:36px">Recent Episodes</h2>';
  if(!eps.length){html+='<div class="empty">Episode sync pending. Each submission triggers validation games on Kaggle.</div>';}
  else{
    html+='<table><thead><tr><th>Episode</th><th>Status</th><th>When</th><th></th></tr></thead><tbody>';
    eps.forEach(function(e){
      var clk=e.replayable!==false;
      html+='<tr'+(clk?' class="clickable ep-row" data-ep="'+esc(e.id)+'" data-me="'+(e.meIndex!=null?e.meIndex:0)+'"':'')+'>';
      html+='<td>'+esc(e.id)+'</td><td>'+pill(e.state)+'</td><td>'+esc(ago(e.endTime||e.createTime))+'</td>';
      html+='<td>'+(clk?'<span class="watch">watch &#9654;</span>':'')+'</td></tr>';
    });
    html+='</tbody></table>';
  }
  el.innerHTML=html;
  wireBattles();
}

function wireBattles(){
  var feat=document.getElementById('open-featured');
  if(feat)feat.onclick=function(){openReplay(feat.getAttribute('data-ep'),parseInt(feat.getAttribute('data-me'),10)||0);};
  document.querySelectorAll('.ep-row').forEach(function(row){
    row.onclick=function(){openReplay(row.getAttribute('data-ep'),parseInt(row.getAttribute('data-me'),10)||0);};
  });
}

var REPLAY_CACHE={};
async function openReplay(epId,meIndex){
  var modal=document.getElementById('replay-modal');
  var statusEl=document.getElementById('replay-loading');
  var headTitle=document.getElementById('replay-mh-title');
  var headSub=document.getElementById('replay-mh-sub');
  if(!modal)return;
  modal.classList.add('open');
  document.body.style.overflow='hidden';
  if(headTitle)headTitle.textContent='episode '+epId;
  if(headSub)headSub.textContent='loading replay from kaggle';
  if(statusEl){statusEl.style.display='flex';statusEl.innerHTML='<div class="spinner"></div><div>pulling 500 turns of real game data<br>this can take a few seconds</div>';}
  var resultEl=document.getElementById('replay-result');if(resultEl)resultEl.style.display='none';
  try{
    var raw=REPLAY_CACHE[epId];
    if(!raw){
      var res=await fetch('/.netlify/functions/replay?id='+encodeURIComponent(epId),{cache:'no-store'});
      if(!res.ok)throw new Error('replay fetch '+res.status);
      raw=await res.json();
      if(raw.error)throw new Error(raw.error);
      REPLAY_CACHE[epId]=raw;
    }
    if(statusEl)statusEl.style.display='none';
    if(headSub)headSub.textContent=(raw.steps?raw.steps.length:0)+' turns';
    window.OrbitReplay.load(raw,meIndex);
  }catch(e){
    if(statusEl){statusEl.style.display='flex';statusEl.innerHTML='<div>could not load this replay<br><span style="color:var(--text-muted)">'+esc(String(e.message||e))+'</span></div>';}
  }
}
function closeReplay(){
  var modal=document.getElementById('replay-modal');
  if(!modal)return;
  modal.classList.remove('open');
  document.body.style.overflow='';
  if(window.OrbitReplay)window.OrbitReplay.pause();
}

function renderFleet(data){
  var subs=data.submissions||[];
  var el=document.getElementById('panel-fleet');
  if(!subs.length){el.innerHTML='<div class="empty">No submissions in the build log yet.</div>';return;}
  var html='<h2>Build Log</h2><ul class="log">';
  subs.forEach(function(s){var burro=avatarFor(s.description);var n=num(s.publicScore);html+='<li><img class="av" src="images/'+burro+'-avatar.png" onerror="this.style.opacity=0.25" alt="'+burro+'" /><div class="body"><div class="msg">'+esc(s.description||s.fileName||'')+'</div><div class="sub"><span>'+esc((s.date||'').slice(0,16).replace('T',' '))+'</span>'+(n!==null?'<span class="score">'+n+'</span>':'')+pill(s.status)+'</div></div></li>';});
  html+='</ul>';
  el.innerHTML=html;
}

function render(data){
  LAST_DATA=data;
  var stamp=document.getElementById('stamp');if(stamp)stamp.textContent='updated '+ago(data.generated_at);
  renderShip(data);renderBattles(data);renderFleet(data);
  var ft=document.getElementById('footer');if(ft)ft.innerHTML='<a href="https://github.com/neonburro/orbit-wars" target="_blank" rel="noopener" style="color:var(--text-muted)">GitHub</a>  ·  <a href="https://www.kaggle.com/competitions/orbit-wars/leaderboard" target="_blank" rel="noopener" style="color:var(--text-muted)">Live Kaggle Leaderboard</a>  ·  Orbit Wars';
}

function setupTabs(){
  document.querySelectorAll('.tab').forEach(function(t){
    t.addEventListener('click',function(){
      document.querySelectorAll('.tab').forEach(function(x){x.classList.remove('active');});
      document.querySelectorAll('.panel').forEach(function(x){x.classList.remove('active');});
      t.classList.add('active');
      var p=document.getElementById('panel-'+t.getAttribute('data-tab'));
      if(p)p.classList.add('active');
    });
  });
}

async function loadLive(){
  try{var res=await fetch('/.netlify/functions/refresh',{cache:'no-store'});if(res.ok){var d=await res.json();if(!d.error)return d;}}catch(e){}
  var r2=await fetch('data.json?_='+Date.now());return await r2.json();
}
async function load(spin){
  renderAgents();responsiveHero();
  var btn=document.getElementById('refresh-btn');
  if(spin&&btn)btn.classList.add('spinning');
  var data;
  try{data=await loadLive();}
  catch(e){var st=document.getElementById('stamp');if(st)st.textContent='no data loaded';if(btn)btn.classList.remove('spinning');return;}
  render(data);
  if(btn)btn.classList.remove('spinning');
}

function setupReplayModal(){
  if(window.OrbitReplay)window.OrbitReplay.init();
  var close=document.getElementById('replay-close');
  if(close)close.onclick=closeReplay;
  var modal=document.getElementById('replay-modal');
  if(modal)modal.addEventListener('click',function(e){if(e.target===modal)closeReplay();});
  document.addEventListener('keydown',function(e){if(e.key==='Escape')closeReplay();});
}

window.addEventListener('resize',responsiveHero);
document.addEventListener('click',function(e){var b=e.target.closest&&e.target.closest('#refresh-btn');if(b)load(true);});
if(document.readyState==='loading'){document.addEventListener('DOMContentLoaded',function(){setupTabs();setupReplayModal();load(false);});}else{setupTabs();setupReplayModal();load(false);}
ORBITWARS_EOF_02

echo "  -> netlify/functions/refresh.js"
cat > "netlify/functions/refresh.js" << 'ORBITWARS_EOF_03'
// netlify/functions/refresh.js
const COMP = "orbit-wars";
const TEAM = "theburroship";
function authHeader() {
  const user = process.env.KAGGLE_USERNAME;
  const key = process.env.KAGGLE_KEY;
  if (!user || !key) return null;
  return "Basic " + Buffer.from(user + ":" + key).toString("base64");
}
async function kaggleGet(path) {
  const auth = authHeader();
  if (!auth) throw new Error("Missing KAGGLE_USERNAME or KAGGLE_KEY");
  const res = await fetch("https://www.kaggle.com/api/v1" + path, { headers: { Authorization: auth } });
  if (!res.ok) throw new Error("Kaggle API " + res.status);
  return res.json();
}
async function kagglePost(url, body) {
  const auth = authHeader();
  const res = await fetch(url, { method: "POST", headers: { Authorization: auth, "Content-Type": "application/json" }, body: JSON.stringify(body) });
  if (!res.ok) throw new Error("status " + res.status);
  return res.json();
}
function normalizeEpisodes(payload) {
  let list = [];
  if (Array.isArray(payload)) list = payload;
  else if (payload && Array.isArray(payload.episodes)) list = payload.episodes;
  else if (payload && Array.isArray(payload.items)) list = payload.items;
  return list.map(function (e) {
    return {
      id: String(e.id != null ? e.id : (e.episodeId != null ? e.episodeId : "")),
      state: String(e.state || e.status || "completed"),
      createTime: e.createTime || e.createdAt || e.startTime || "",
      endTime: e.endTime || e.completedAt || "",
      replayable: true,
      meIndex: 0
    };
  }).filter(function (e) { return e.id; });
}
async function episodesForSubmission(subId) {
  const attempts = [
    { url: "https://www.kaggle.com/api/i/competitions.EpisodeService/ListEpisodes", body: { SubmissionId: Number(subId) } },
    { url: "https://www.kaggle.com/api/i/competitions.EpisodeService/ListEpisodes", body: { submissionId: Number(subId) } }
  ];
  for (let i = 0; i < attempts.length; i++) {
    try {
      const data = await kagglePost(attempts[i].url, attempts[i].body);
      const eps = normalizeEpisodes(data);
      if (eps.length) return eps;
    } catch (e) { /* try next */ }
  }
  return [];
}
exports.handler = async function () {
  try {
    const subsRaw = await kaggleGet("/competitions/submissions/list/" + COMP + "?page=1");
    const lbRaw = await kaggleGet("/competitions/" + COMP + "/leaderboard/view");
    const submissions = (subsRaw || []).map(function (s) {
      return { ref: String(s.ref || s.id || ""), fileName: s.fileName || "", description: s.description || "", date: s.date || "", publicScore: s.publicScore != null ? String(s.publicScore) : "", status: s.status || "" };
    });
    const rows = (lbRaw && lbRaw.submissions) || (lbRaw && lbRaw.teams) || [];
    let myRank = null, myScore = null;
    const leaderboard_top = rows.map(function (r, i) {
      const name = r.teamName || r.team || r.teamNameNullable || "";
      const score = r.score != null ? String(r.score) : "";
      if (name && name.toLowerCase() === TEAM.toLowerCase()) { myRank = i + 1; myScore = score; }
      return { teamName: name, score: score, submissionDate: r.submissionDate || "" };
    });

    // Pull episodes for the most recent submissions (best-effort, never blocks the payload)
    let episodes = [];
    try {
      const top = (subsRaw || []).slice(0, 4);
      let all = [];
      for (let i = 0; i < top.length; i++) {
        const sid = top[i].ref || top[i].id;
        if (!sid) continue;
        const eps = await episodesForSubmission(sid);
        all = all.concat(eps);
      }
      const seen = {};
      all.forEach(function (e) { if (!seen[e.id]) { seen[e.id] = 1; episodes.push(e); } });
      episodes.sort(function (a, b) { return String(b.endTime || b.createTime).localeCompare(String(a.endTime || a.createTime)); });
      episodes = episodes.slice(0, 25);
    } catch (e) { episodes = []; }

    return { statusCode: 200, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" }, body: JSON.stringify({ generated_at: new Date().toISOString(), competition: COMP, team: TEAM, my_rank: myRank, my_score: myScore, leaderboard_size: leaderboard_top.length, submissions: submissions, leaderboard_top: leaderboard_top, episodes: episodes }) };
  } catch (e) {
    return { statusCode: 500, headers: { "Content-Type": "application/json" }, body: JSON.stringify({ error: String(e.message || e) }) };
  }
};
ORBITWARS_EOF_03

echo "  -> netlify/functions/episodes.js"
cat > "netlify/functions/episodes.js" << 'ORBITWARS_EOF_04'
// netlify/functions/episodes.js
// Lists episodes for the team's recent submissions so the Battles tab can show
// real games (and feed clickable rows into the replay player).
// Like replay, the episodes list is an internal KaggleSDK RPC; this tries the
// known shapes and returns whatever it can, degrading to an empty list cleanly.

const COMP = "orbit-wars";

function authHeader() {
  const user = process.env.KAGGLE_USERNAME;
  const key = process.env.KAGGLE_KEY;
  if (!user || !key) return null;
  return "Basic " + Buffer.from(user + ":" + key).toString("base64");
}

async function kaggleGetJson(path, auth) {
  const res = await fetch("https://www.kaggle.com/api/v1" + path, { headers: { Authorization: auth } });
  if (!res.ok) throw new Error("Kaggle API " + res.status);
  return res.json();
}

async function kagglePostJson(url, body, auth) {
  const res = await fetch(url, { method: "POST", headers: { Authorization: auth, "Content-Type": "application/json" }, body: JSON.stringify(body) });
  if (!res.ok) throw new Error("status " + res.status);
  return res.json();
}

function normalizeEpisodes(payload) {
  let list = [];
  if (Array.isArray(payload)) list = payload;
  else if (payload && Array.isArray(payload.episodes)) list = payload.episodes;
  else if (payload && Array.isArray(payload.items)) list = payload.items;
  return list.map(function (e) {
    return {
      id: String(e.id != null ? e.id : (e.episodeId != null ? e.episodeId : "")),
      state: String(e.state || e.status || "completed"),
      createTime: e.createTime || e.createdAt || e.startTime || "",
      endTime: e.endTime || e.completedAt || "",
      replayable: true,
      meIndex: 0
    };
  }).filter(function (e) { return e.id; });
}

async function episodesForSubmission(subId, auth) {
  const attempts = [
    { url: "https://www.kaggle.com/api/i/competitions.EpisodeService/ListEpisodes", body: { SubmissionId: Number(subId) } },
    { url: "https://www.kaggle.com/api/i/competitions.EpisodeService/ListEpisodes", body: { submissionId: Number(subId) } }
  ];
  for (let i = 0; i < attempts.length; i++) {
    try {
      const data = await kagglePostJson(attempts[i].url, attempts[i].body, auth);
      const eps = normalizeEpisodes(data);
      if (eps.length) return eps;
    } catch (e) { /* try next */ }
  }
  return [];
}

exports.handler = async function () {
  const auth = authHeader();
  if (!auth) {
    return { statusCode: 500, headers: { "Content-Type": "application/json" }, body: JSON.stringify({ error: "Missing KAGGLE_USERNAME or KAGGLE_KEY env vars" }) };
  }
  try {
    const subsRaw = await kaggleGetJson("/competitions/submissions/list/" + COMP + "?page=1", auth);
    const subs = (subsRaw || []).slice(0, 5);
    let all = [];
    for (let i = 0; i < subs.length; i++) {
      const sid = subs[i].ref || subs[i].id;
      if (!sid) continue;
      const eps = await episodesForSubmission(sid, auth);
      all = all.concat(eps);
    }
    // de-dupe by id, newest first
    const seen = {};
    const merged = [];
    all.forEach(function (e) { if (!seen[e.id]) { seen[e.id] = 1; merged.push(e); } });
    merged.sort(function (a, b) {
      return String(b.endTime || b.createTime).localeCompare(String(a.endTime || a.createTime));
    });
    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
      body: JSON.stringify({ generated_at: new Date().toISOString(), episodes: merged.slice(0, 25) })
    };
  } catch (e) {
    return { statusCode: 200, headers: { "Content-Type": "application/json" }, body: JSON.stringify({ episodes: [], note: String(e.message || e) }) };
  }
};
ORBITWARS_EOF_04

echo "  -> netlify/functions/replay.js"
cat > "netlify/functions/replay.js" << 'ORBITWARS_EOF_05'
// netlify/functions/replay.js
// Live-fetches an Orbit Wars episode replay JSON from Kaggle on demand.
// The replay download is an internal KaggleSDK RPC, not a stable public REST GET,
// so this tries the known SDK endpoints in order and returns a clear error if the
// shape has changed. Kept lean so it streams the (large) JSON straight back.

function authHeader() {
  const user = process.env.KAGGLE_USERNAME;
  const key = process.env.KAGGLE_KEY;
  if (!user || !key) return null;
  return "Basic " + Buffer.from(user + ":" + key).toString("base64");
}

async function tryEndpoint(url, method, body, auth) {
  const opts = { method: method, headers: { Authorization: auth } };
  if (body) {
    opts.headers["Content-Type"] = "application/json";
    opts.body = JSON.stringify(body);
  }
  const res = await fetch(url, opts);
  if (!res.ok) return { ok: false, status: res.status };
  const text = await res.text();
  // Some endpoints wrap the replay; try to find the replay JSON.
  let parsed;
  try { parsed = JSON.parse(text); } catch (e) { return { ok: false, status: 0, note: "non-json" }; }
  // Unwrap common shapes: { replay: "<json string>" } or { replay: {...} } or direct
  let replay = parsed.replay != null ? parsed.replay : parsed;
  if (typeof replay === "string") {
    try { replay = JSON.parse(replay); } catch (e) { /* leave as-is */ }
  }
  if (replay && replay.steps) return { ok: true, replay: replay };
  if (parsed && parsed.steps) return { ok: true, replay: parsed };
  return { ok: false, status: res.status, note: "no steps in payload" };
}

exports.handler = async function (event) {
  const auth = authHeader();
  if (!auth) {
    return { statusCode: 500, headers: { "Content-Type": "application/json" }, body: JSON.stringify({ error: "Missing KAGGLE_USERNAME or KAGGLE_KEY env vars" }) };
  }
  const id = event.queryStringParameters && event.queryStringParameters.id;
  if (!id) {
    return { statusCode: 400, headers: { "Content-Type": "application/json" }, body: JSON.stringify({ error: "Missing episode id" }) };
  }

  const attempts = [
    { url: "https://www.kaggle.com/api/i/competitions.EpisodeService/GetEpisodeReplay", method: "POST", body: { EpisodeId: Number(id) } },
    { url: "https://www.kaggle.com/api/i/competitions.EpisodeService/GetEpisodeReplay", method: "POST", body: { episodeId: Number(id) } },
    { url: "https://www.kaggle.com/api/v1/competitions/episodes/" + encodeURIComponent(id) + "/replay", method: "GET", body: null }
  ];

  const tried = [];
  for (let i = 0; i < attempts.length; i++) {
    try {
      const a = attempts[i];
      const r = await tryEndpoint(a.url, a.method, a.body, auth);
      tried.push({ url: a.url, method: a.method, status: r.status, note: r.note });
      if (r.ok) {
        return {
          statusCode: 200,
          headers: { "Content-Type": "application/json", "Cache-Control": "public, max-age=3600" },
          body: JSON.stringify(r.replay)
        };
      }
    } catch (e) {
      tried.push({ error: String(e.message || e) });
    }
  }

  return {
    statusCode: 502,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ error: "Could not fetch replay from Kaggle", episode: id, tried: tried })
  };
};
ORBITWARS_EOF_05

echo "  -> index.html"
cat > "index.html" << 'ORBITWARS_EOF_06'
<!doctype html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>theburroship • orbit wars</title>
<link href="https://cdn.jsdelivr.net/npm/geist@1/dist/font.css" rel="stylesheet" />
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet" />
<meta name="title" content="theburroship • orbit wars" />
<meta name="description" content="Command the fleet. Conquer the void. A few burros loose in the cosmos, built at altitude." />
<meta property="og:type" content="website" />
<meta property="og:url" content="https://theburroship-orbitwars.netlify.app/" />
<meta property="og:title" content="theburroship • orbit wars" />
<meta property="og:description" content="Command the fleet. Conquer the void. A few burros loose in the cosmos, built at altitude." />
<meta property="og:image" content="https://theburroship-orbitwars.netlify.app/images/theburroship-orbitwars-sms-1200x630.png" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:image:alt" content="The Burroship Orbit Wars" />
<meta property="og:site_name" content="The Burroship" />
<meta property="og:locale" content="en_US" />
<meta property="twitter:card" content="summary_large_image" />
<meta property="twitter:url" content="https://theburroship-orbitwars.netlify.app/" />
<meta property="twitter:title" content="theburroship • orbit wars" />
<meta property="twitter:description" content="Command the fleet. Conquer the void. A few burros loose in the cosmos, built at altitude." />
<meta property="twitter:image" content="https://theburroship-orbitwars.netlify.app/images/theburroship-orbitwars-sms-1200x630.png" />
<link rel="icon" type="image/svg+xml" href="/favicon.svg" />
<meta name="theme-color" content="#0B0B0C" />
<link rel="stylesheet" href="/css/styles.css" />
</head>
<body>
  <div class="team-strip"><div class="agents" id="agents"></div></div>
  <header class="hero">
    <img class="hero-img" id="hero-img" src="images/hero-desktop.png" alt="Orbit Wars" />
    <div class="hero-scrim"></div>
    <div class="hero-inner">
      <div class="eyebrow">team burroship · kaggle campaign</div>
      <h1>the burroship<span class="dot">.</span></h1>
      <p class="lede">Command the fleet. Conquer the void. A few burros loose in the cosmos, built at altitude.</p>
      <div class="scroll-cue">scroll for mission control ↓</div>
    </div>
  </header>
  <div class="wrap">
    <div class="stamp-row"><div class="stamp" id="stamp">awaiting data</div><button class="refresh-btn" id="refresh-btn" title="Refresh" aria-label="Refresh"><span class="ico"></span></button></div>
    <div class="tabs">
      <button class="tab active" data-tab="ship">The Burroship</button>
      <button class="tab" data-tab="battles">Battles</button>
      <button class="tab" data-tab="fleet">The Fleet</button>
    </div>
    <div class="panel active" id="panel-ship"></div>
    <div class="panel" id="panel-battles"></div>
    <div class="panel" id="panel-fleet"></div>
    <footer id="footer"></footer>
  </div>

  <div class="modal" id="replay-modal" aria-hidden="true">
    <div class="modal-card">
      <div class="modal-head">
        <div>
          <div class="mh-title" id="replay-mh-title">episode</div>
          <div class="mh-sub" id="replay-mh-sub">loading</div>
        </div>
        <button class="modal-close" id="replay-close" aria-label="Close">&times;</button>
      </div>
      <div class="canvas-wrap">
        <canvas id="replay-canvas"></canvas>
        <div class="replay-result" id="replay-result" style="display:none"></div>
        <div class="replay-turn" id="replay-turn"></div>
        <div class="replay-status" id="replay-loading"><div class="spinner"></div><div>loading</div></div>
      </div>
      <div class="controls">
        <button class="play" id="replay-play" aria-label="Play">&#9654;</button>
        <input type="range" class="scrub" id="replay-scrub" min="0" max="0" value="0" aria-label="Scrub timeline" />
        <button class="speed" id="replay-speed">1x</button>
      </div>
      <div class="legend">
        <span class="lg"><span class="sw" style="background:#8FD4F0"></span> burroship</span>
        <span class="lg"><span class="sw" style="background:#C8543B"></span> enemy</span>
        <span class="lg"><span class="sw" style="background:#6E6E6B"></span> neutral</span>
        <span class="lg"><span class="sw" style="background:#D47B45"></span> the sun</span>
      </div>
    </div>
  </div>

  <script src="/js/replay.js"></script>
  <script src="/js/dashboard.js"></script>
</body>
</html>
ORBITWARS_EOF_06

echo ""
echo "Done. Files written."
echo ""
echo "Next steps:"
echo "  1. yarn build 2>&1 | tail -6   (if you have a build step; static site can skip)"
echo "  2. Preview locally, then:"
echo "     git add -A"
echo "     git commit -m \"Three-tab dashboard with live replay player, css/js split, episodes sync\""
echo "     git push"
echo ""
echo "  In Netlify: trigger a redeploy so the new functions go live."
echo "  The replay/episodes endpoints use your existing KAGGLE_USERNAME and KAGGLE_KEY env vars."
echo ""
echo "  If a replay does not load, the episode endpoint shape may differ on Kaggle;"
echo "  the Battles tab still shows score progression and the episode list regardless."
