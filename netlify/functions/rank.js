// netlify/functions/rank.js
// Serves the rank snapshot written by rank-sync.js (stored in Netlify Blobs).
// Reports staleness so the dashboard can decide whether to trigger a background
// refresh (by calling rank-sync directly). Never breaks: degrades to syncing:true.

const { getStore } = require("@netlify/blobs");

const STALE_MS = 60 * 60 * 1000; // 1 hour

exports.handler = async function () {
  try {
    const store = getStore("orbit-rank");
    let snap = null;
    try { snap = await store.get("snapshot", { type: "json" }); } catch (e) { snap = null; }
    if (!snap) {
      return {
        statusCode: 200,
        headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
        body: JSON.stringify({ found: false, syncing: true, stale: true })
      };
    }
    let stale = true;
    if (snap.generated_at) {
      const age = Date.now() - new Date(snap.generated_at).getTime();
      stale = age > STALE_MS;
      snap.age_ms = age;
    }
    snap.stale = stale;
    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
      body: JSON.stringify(snap)
    };
  } catch (e) {
    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ found: false, error: String(e.message || e), stale: true })
    };
  }
};
