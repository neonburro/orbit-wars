// netlify/functions/rank-sync.js
// Scheduled nightly. Pages the Orbit Wars leaderboard until it finds the team,
// captures rank + rating + neighbors, compares to the prior snapshot for movement,
// and writes the new snapshot to Netlify Blobs. The dashboard reads it via rank.js.

const { getStore } = require("@netlify/blobs");

const COMP = "orbit-wars";
const TEAM = "theburroship";
const PAGE_SIZE = 20;
const MAX_PAGES = 300; // safety cap: 300 * 20 = 6000 rows, covers the field
const NEIGHBORS = 3;

function authHeader() {
  const user = process.env.KAGGLE_USERNAME;
  const key = process.env.KAGGLE_KEY;
  if (!user || !key) return null;
  return "Basic " + Buffer.from(user + ":" + key).toString("base64");
}

async function fetchPage(auth, pageToken) {
  let url = "https://www.kaggle.com/api/v1/competitions/" + COMP + "/leaderboard/view";
  if (pageToken) url += "?pageToken=" + encodeURIComponent(pageToken);
  const res = await fetch(url, { headers: { Authorization: auth } });
  if (!res.ok) throw new Error("Kaggle API " + res.status);
  return res.json();
}

function rowsFrom(payload) {
  return (payload && payload.submissions) || (payload && payload.teams) || [];
}

function nameOf(r) {
  return r.teamName || r.team || r.teamNameNullable || "";
}

const handler = async function () {
  const auth = authHeader();
  if (!auth) {
    return { statusCode: 500, body: "Missing KAGGLE_USERNAME or KAGGLE_KEY" };
  }

  try {
    let pageToken = null;
    let absoluteIndex = 0; // 0-based position across all pages
    let foundIndex = -1;
    let window = []; // rolling buffer of recent rows to grab neighbors above
    let after = []; // rows captured after the team for neighbors below
    let teamRow = null;
    let collectingAfter = 0;

    for (let page = 0; page < MAX_PAGES; page++) {
      const payload = await fetchPage(auth, pageToken);
      const rows = rowsFrom(payload);
      if (!rows.length) break;

      for (let i = 0; i < rows.length; i++) {
        const r = rows[i];
        const entry = { rank: absoluteIndex + 1, name: nameOf(r), score: r.score != null ? String(r.score) : "" };

        if (foundIndex === -1) {
          window.push(entry);
          if (window.length > NEIGHBORS + 1) window.shift();
          if (entry.name && entry.name.toLowerCase() === TEAM.toLowerCase()) {
            foundIndex = absoluteIndex;
            teamRow = entry;
            collectingAfter = NEIGHBORS;
          }
        } else if (collectingAfter > 0) {
          after.push(entry);
          collectingAfter--;
        }
        absoluteIndex++;
      }

      if (foundIndex !== -1 && collectingAfter === 0) break;
      pageToken = payload && (payload.nextPageToken || payload.pageToken) ? (payload.nextPageToken || payload.pageToken) : null;
      if (!pageToken) break;
    }

    const store = getStore("orbit-rank");
    let prev = null;
    try { prev = await store.get("snapshot", { type: "json" }); } catch (e) { prev = null; }

    if (!teamRow) {
      // Not found within cap. Preserve any prior snapshot, just note the attempt.
      const out = prev || {};
      out.last_attempt = new Date().toISOString();
      out.found = false;
      out.total_scanned = absoluteIndex;
      await store.setJSON("snapshot", out);
      return { statusCode: 200, body: "team not found within " + absoluteIndex + " rows" };
    }

    // above neighbors = window minus the team row itself
    const above = window.filter(function (e) { return e.rank < teamRow.rank; });

    let movement = 0;
    let prevRank = null;
    if (prev && typeof prev.rank === "number") {
      prevRank = prev.rank;
      movement = prev.rank - teamRow.rank; // positive = climbed (rank number went down)
    }

    const snapshot = {
      generated_at: new Date().toISOString(),
      found: true,
      team: TEAM,
      rank: teamRow.rank,
      score: teamRow.score,
      total_scanned: absoluteIndex,
      prev_rank: prevRank,
      movement: movement,
      neighbors_above: above,
      neighbors_below: after,
      best_rank: prev && typeof prev.best_rank === "number" ? Math.min(prev.best_rank, teamRow.rank) : teamRow.rank
    };

    await store.setJSON("snapshot", snapshot);
    return { statusCode: 200, body: "rank " + teamRow.rank + " of " + absoluteIndex + " (moved " + movement + ")" };
  } catch (e) {
    return { statusCode: 500, body: String(e.message || e) };
  }
};

module.exports.handler = handler;
