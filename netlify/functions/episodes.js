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
