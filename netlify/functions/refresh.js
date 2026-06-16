const COMP = "orbit-wars";
const TEAM = "theburroship";

function authHeader() {
  const user = process.env.KAGGLE_USERNAME;
  const key = process.env.KAGGLE_KEY;
  if (!user || !key) return null;
  const token = Buffer.from(`${user}:${key}`).toString("base64");
  return `Basic ${token}`;
}

async function kaggleGet(path) {
  const auth = authHeader();
  if (!auth) throw new Error("Missing KAGGLE_USERNAME or KAGGLE_KEY env vars");
  const res = await fetch(`https://www.kaggle.com/api/v1${path}`, {
    headers: { Authorization: auth },
  });
  if (!res.ok) throw new Error(`Kaggle API ${res.status}: ${await res.text()}`);
  return res.json();
}

exports.handler = async function () {
  try {
    const subsRaw = await kaggleGet(`/competitions/submissions/list/${COMP}?page=1`);
    const lbRaw = await kaggleGet(`/competitions/${COMP}/leaderboard/view`);
    const submissions = (subsRaw || []).map((s) => ({
      ref: String(s.ref || s.id || ""),
      fileName: s.fileName || "",
      description: s.description || "",
      date: s.date || "",
      publicScore: s.publicScore != null ? String(s.publicScore) : "",
      status: s.status || "",
    }));
    const rows = (lbRaw && lbRaw.submissions) || (lbRaw && lbRaw.teams) || [];
    let myRank = null;
    let myScore = null;
    const leaderboard_top = rows.map((r, i) => {
      const name = r.teamName || r.team || r.teamNameNullable || "";
      const score = r.score != null ? String(r.score) : "";
      if (name && name.toLowerCase() === TEAM.toLowerCase()) {
        myRank = i + 1;
        myScore = score;
      }
      return { teamName: name, score, submissionDate: r.submissionDate || "" };
    });
    const data = {
      generated_at: new Date().toISOString(),
      competition: COMP,
      team: TEAM,
      my_rank: myRank,
      my_score: myScore,
      leaderboard_size: leaderboard_top.length,
      submissions,
      leaderboard_top,
    };
    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
      body: JSON.stringify(data),
    };
  } catch (e) {
    return {
      statusCode: 500,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ error: String(e.message || e) }),
    };
  }
};
