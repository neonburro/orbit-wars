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
