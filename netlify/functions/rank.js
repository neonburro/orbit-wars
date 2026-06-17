// netlify/functions/rank.js
// Serves the rank snapshot written nightly by rank-sync.js (stored in Netlify Blobs).
// Degrades to a "syncing" payload if the snapshot is not there yet, so the dashboard
// never breaks before the first scheduled run.

const { getStore } = require("@netlify/blobs");

exports.handler = async function () {
  try {
    const store = getStore("orbit-rank");
    let snap = null;
    try { snap = await store.get("snapshot", { type: "json" }); } catch (e) { snap = null; }
    if (!snap) {
      return {
        statusCode: 200,
        headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
        body: JSON.stringify({ found: false, syncing: true })
      };
    }
    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
      body: JSON.stringify(snap)
    };
  } catch (e) {
    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ found: false, error: String(e.message || e) })
    };
  }
};
